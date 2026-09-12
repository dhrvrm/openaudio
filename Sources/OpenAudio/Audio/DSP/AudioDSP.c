#include "AudioDSP.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define OA_MAX_FRAMES 8192
#define OA_MAX_EFFECTS 8
#define OA_MAX_CHANNELS 128

typedef struct { double b0,b1,b2,a1,a2,z1[2],z2[2]; float db; } Filter;
typedef struct { UInt32 count; AudioBuffer buffers[2]; } StereoBuffers;
typedef struct { AudioUnit unit; float *left; float *right; unsigned frames; } Effect;
struct OADSP {
    double rate;
    unsigned offset;
    _Atomic float gain, balance, eq[10], peak;
    _Atomic bool muted, equalized;
    _Atomic unsigned long long frames;
    _Atomic int error;
    float smoothGain;
    Filter filters[10];
    float left[OA_MAX_FRAMES], right[OA_MAX_FRAMES];
    float scratchL[OA_MAX_FRAMES], scratchR[OA_MAX_FRAMES];
    int outputMap[OA_MAX_CHANNELS];
    _Atomic float outputGain[OA_MAX_CHANNELS];
    Effect effects[OA_MAX_EFFECTS];
    unsigned effectCount;
    double sampleTime;
};
static const double frequencies[10] = {32,64,125,250,500,1000,2000,4000,8000,16000};
static float finiteSample(float x) { return isfinite(x) ? x : 0; }
static float clamp(float x, float lo, float hi) { return fminf(hi, fmaxf(lo, finiteSample(x))); }

OADSP *OACreate(double sampleRate, unsigned inputChannelOffset) {
    if (!isfinite(sampleRate) || sampleRate < 8000 || sampleRate > 384000) return NULL;
    OADSP *d = calloc(1, sizeof(OADSP));
    if (!d) return NULL;
    d->rate = sampleRate; d->offset = inputChannelOffset; d->smoothGain = 1;
    atomic_init(&d->gain, 1); atomic_init(&d->balance, 0); atomic_init(&d->peak, 0);
    atomic_init(&d->muted, false); atomic_init(&d->equalized, false);
    atomic_init(&d->frames, 0); atomic_init(&d->error, 0);
    for (unsigned i=0;i<10;i++) { atomic_init(&d->eq[i], 0); d->filters[i].db = NAN; }
    for (unsigned i=0;i<OA_MAX_CHANNELS;i++) { d->outputMap[i] = i < 2 ? (int)i : -1; atomic_init(&d->outputGain[i],1); }
    return d;
}
void OADestroy(OADSP *d) {
    if (!d) return;
    for (unsigned i=0;i<d->effectCount;i++) { AudioUnitUninitialize(d->effects[i].unit); AudioComponentInstanceDispose(d->effects[i].unit); }
    free(d);
}
void OASetGain(OADSP *d,float gain,bool muted,float balance) {
    atomic_store(&d->gain, clamp(gain,0,16)); atomic_store(&d->muted,muted); atomic_store(&d->balance,clamp(balance,-1,1));
}
void OAInitializeGain(OADSP *d,float gain,bool muted,float balance) {
    OASetGain(d,gain,muted,balance); d->smoothGain=muted?0:clamp(gain,0,16);
}
void OASetEQ(OADSP *d,unsigned band,float db,bool enabled) {
    if (band<10) atomic_store(&d->eq[band],clamp(db,-12,12));
    atomic_store(&d->equalized,enabled);
}
void OASetOutputMap(OADSP *d,unsigned channel,int source) { if(channel<OA_MAX_CHANNELS) d->outputMap[channel] = source; }
void OASetOutputGain(OADSP *d,unsigned channel,float gain) { if(channel<OA_MAX_CHANNELS) atomic_store(&d->outputGain[channel],clamp(gain,0,1)); }
float OAPeak(OADSP *d) { return atomic_load(&d->peak); }
unsigned long long OAFrames(OADSP *d) { return atomic_load(&d->frames); }
OSStatus OAError(OADSP *d) { return atomic_load(&d->error); }

static void configure(Filter *f,double hz,double rate,float db) {
    f->db = db;
    if(hz>=rate*0.5) { f->b0=1; f->b1=f->b2=f->a1=f->a2=0; return; }
    double a = pow(10,db/40.0), w = 2*M_PI*fmin(hz,rate*0.45)/rate;
    double alpha = sin(w)/(2*1.4), a0 = 1+alpha/a;
    f->b0=(1+alpha*a)/a0; f->b1=-2*cos(w)/a0; f->b2=(1-alpha*a)/a0;
    f->a1=-2*cos(w)/a0; f->a2=(1-alpha/a)/a0;
}
static float filter(Filter *f,float x,unsigned channel) {
    double y=f->b0*x+f->z1[channel];
    f->z1[channel]=f->b1*x-f->a1*y+f->z2[channel];
    f->z2[channel]=f->b2*x-f->a2*y;
    if (!isfinite(y)) { f->z1[channel]=0; f->z2[channel]=0; return 0; }
    return (float)y;
}
static OSStatus effectInput(void *context,AudioUnitRenderActionFlags *flags,const AudioTimeStamp *time,UInt32 bus,UInt32 frames,AudioBufferList *data) {
    Effect *e=context;
    if(frames>e->frames || data->mNumberBuffers!=2) return kAudioUnitErr_TooManyFramesToProcess;
    for(unsigned i=0;i<2;i++) {
        float *source=i==0?e->left:e->right;
        if(data->mBuffers[i].mData) memcpy(data->mBuffers[i].mData,source,frames*sizeof(float));
        else data->mBuffers[i].mData=source;
        data->mBuffers[i].mDataByteSize=frames*sizeof(float); data->mBuffers[i].mNumberChannels=1;
    }
    return noErr;
}
OSStatus OAAddEffect(OADSP *d,AudioComponentDescription description) {
    if(d->effectCount>=OA_MAX_EFFECTS) return kAudioUnitErr_InvalidPropertyValue;
    AudioComponent component=AudioComponentFindNext(NULL,&description);
    if(!component) return kAudioUnitErr_InvalidProperty;
    Effect *e=&d->effects[d->effectCount];
    OSStatus result=AudioComponentInstanceNew(component,&e->unit);
    if(result) return result;
    AudioStreamBasicDescription format={d->rate,kAudioFormatLinearPCM,kAudioFormatFlagsNativeFloatPacked|kAudioFormatFlagIsNonInterleaved,4,1,4,2,32,0};
    UInt32 frames=OA_MAX_FRAMES;
    AURenderCallbackStruct callback={effectInput,e};
    result=AudioUnitSetProperty(e->unit,kAudioUnitProperty_MaximumFramesPerSlice,kAudioUnitScope_Global,0,&frames,sizeof(frames));
    if(!result) result=AudioUnitSetProperty(e->unit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input,0,&format,sizeof(format));
    if(!result) result=AudioUnitSetProperty(e->unit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output,0,&format,sizeof(format));
    if(!result) result=AudioUnitSetProperty(e->unit,kAudioUnitProperty_SetRenderCallback,kAudioUnitScope_Input,0,&callback,sizeof(callback));
    if(!result) result=AudioUnitInitialize(e->unit);
    if(result) { AudioComponentInstanceDispose(e->unit); e->unit=NULL; return result; }
    d->effectCount++; return noErr;
}
AudioUnit OAEffect(OADSP *d,unsigned index) { return index<d->effectCount?d->effects[index].unit:NULL; }
void OAProcess(OADSP *d,float *left,float *right,unsigned frames) {
    if(!d || !left || !right || frames>OA_MAX_FRAMES) return;
    bool equalized=atomic_load(&d->equalized);
    if(equalized) for(unsigned b=0;b<10;b++) { float db=atomic_load(&d->eq[b]); if(db!=d->filters[b].db) configure(&d->filters[b],frequencies[b],d->rate,db); }
    for(unsigned i=0;i<frames;i++) {
        left[i]=finiteSample(left[i]); right[i]=finiteSample(right[i]);
        if(equalized) for(unsigned b=0;b<10;b++) { left[i]=filter(&d->filters[b],left[i],0); right[i]=filter(&d->filters[b],right[i],1); }
    }
    for(unsigned u=0;u<d->effectCount;u++) {
        Effect *e=&d->effects[u]; e->left=left; e->right=right; e->frames=frames;
        StereoBuffers buffers={2,{{1,frames*4,d->scratchL},{1,frames*4,d->scratchR}}};
        AudioTimeStamp time={0}; time.mSampleTime=d->sampleTime; time.mFlags=kAudioTimeStampSampleTimeValid;
        AudioUnitRenderActionFlags flags=0;
        OSStatus result=AudioUnitRender(e->unit,&flags,&time,0,frames,(AudioBufferList *)&buffers);
        if(result) { atomic_store(&d->error,result); memset(left,0,frames*4); memset(right,0,frames*4); break; }
        memcpy(left,buffers.buffers[0].mData,frames*4); memcpy(right,buffers.buffers[1].mData,frames*4);
    }
    float target=atomic_load(&d->muted)?0:atomic_load(&d->gain), pan=atomic_load(&d->balance), peak=0;
    float lGain=pan>0?1-pan:1, rGain=pan<0?1+pan:1;
    for(unsigned i=0;i<frames;i++) {
        d->smoothGain += (target-d->smoothGain)*0.01f;
        left[i]=clamp(left[i]*d->smoothGain*lGain,-1,1); right[i]=clamp(right[i]*d->smoothGain*rGain,-1,1);
        peak=fmaxf(peak,fmaxf(fabsf(left[i]),fabsf(right[i])));
    }
    atomic_store(&d->peak,peak); atomic_fetch_add(&d->frames,frames); d->sampleTime+=frames;
}
static const AudioBuffer *channelBuffer(const AudioBufferList *list,unsigned channel,unsigned *local) {
    for(unsigned i=0;i<list->mNumberBuffers;i++) {
        if(channel<list->mBuffers[i].mNumberChannels) { *local=channel; return &list->mBuffers[i]; }
        channel-=list->mBuffers[i].mNumberChannels;
    }
    return NULL;
}
OSStatus OAIOProc(AudioObjectID device,const AudioTimeStamp *now,const AudioBufferList *input,const AudioTimeStamp *inputTime,AudioBufferList *output,const AudioTimeStamp *outputTime,void *context) {
    OADSP *d=context;
    for(unsigned b=0;b<output->mNumberBuffers;b++) if(output->mBuffers[b].mData) memset(output->mBuffers[b].mData,0,output->mBuffers[b].mDataByteSize);
    unsigned lc=0,rc=0;
    const AudioBuffer *l=channelBuffer(input,d->offset,&lc), *r=channelBuffer(input,d->offset+1,&rc);
    if(!l || !r || !l->mNumberChannels || !r->mNumberChannels) { atomic_store(&d->error,kAudioUnitErr_FormatNotSupported); return noErr; }
    if(!l->mData || !r->mData) return noErr;
    unsigned frames=l->mDataByteSize/(4*l->mNumberChannels);
    unsigned rframes=r->mDataByteSize/(4*r->mNumberChannels);
    if(frames>OA_MAX_FRAMES || frames!=rframes) { atomic_store(&d->error,kAudioUnitErr_TooManyFramesToProcess); return noErr; }
    for(unsigned i=0;i<frames;i++) { d->left[i]=((float *)l->mData)[i*l->mNumberChannels+lc]; d->right[i]=((float *)r->mData)[i*r->mNumberChannels+rc]; }
    OAProcess(d,d->left,d->right,frames);
    unsigned channel=0;
    for(unsigned b=0;b<output->mNumberBuffers;b++) {
        AudioBuffer *o=&output->mBuffers[b];
        unsigned count=o->mNumberChannels?o->mDataByteSize/(4*o->mNumberChannels):0;
        for(unsigned c=0;c<o->mNumberChannels;c++,channel++) {
            int source=channel<OA_MAX_CHANNELS?d->outputMap[channel]:-1;
            if(source<0) continue;
            if(!o->mData || count<frames) { atomic_store(&d->error,kAudioUnitErr_TooManyFramesToProcess); continue; }
            float *data=source==0?d->left:d->right;
            float outputGain=atomic_load(&d->outputGain[channel]);
            for(unsigned i=0;i<frames;i++) ((float *)o->mData)[i*o->mNumberChannels+c]=(source==2?(d->left[i]+d->right[i])*0.5f:data[i])*outputGain;
        }
    }
    return noErr;
}
