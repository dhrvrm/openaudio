#ifndef OPEN_AUDIO_DSP_H
#define OPEN_AUDIO_DSP_H
#include <CoreAudio/CoreAudio.h>
#include <AudioToolbox/AudioToolbox.h>
#include <stdbool.h>

typedef struct OADSP OADSP;
OADSP * _Nullable OACreate(double sampleRate, unsigned inputChannelOffset);
void OADestroy(OADSP * _Nonnull dsp);
void OASetGain(OADSP * _Nonnull dsp, float gain, bool muted, float balance);
void OAInitializeGain(OADSP * _Nonnull dsp, float gain, bool muted, float balance);
void OASetEQ(OADSP * _Nonnull dsp, unsigned band, float gainDB, bool enabled);
void OASetOutputMap(OADSP * _Nonnull dsp, unsigned channel, int source);
void OASetOutputGain(OADSP * _Nonnull dsp, unsigned channel, float gain);
float OAPeak(OADSP * _Nonnull dsp);
unsigned long long OAFrames(OADSP * _Nonnull dsp);
OSStatus OAError(OADSP * _Nonnull dsp);
void OAProcess(OADSP * _Nonnull dsp, float * _Nullable left, float * _Nullable right, unsigned frames);
OSStatus OAAddEffect(OADSP * _Nonnull dsp, AudioComponentDescription description);
AudioUnit _Nullable OAEffect(OADSP * _Nonnull dsp, unsigned index);
OSStatus OAIOProc(AudioObjectID device, const AudioTimeStamp * _Nonnull now, const AudioBufferList * _Nonnull input, const AudioTimeStamp * _Nonnull inputTime, AudioBufferList * _Nonnull output, const AudioTimeStamp * _Nonnull outputTime, void * _Nullable context);
#endif
