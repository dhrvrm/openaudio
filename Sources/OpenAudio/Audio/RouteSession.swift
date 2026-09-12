import CoreAudio
import AudioToolbox
import AudioDSP
import Foundation

final class RouteSession {
    private var tap: AudioObjectID = 0
    private var aggregate: AudioObjectID = 0
    private var io: AudioDeviceIOProcID?
    private(set) var dsp: OpaquePointer?
    private var targetDevices: [AudioDevice]
    let signature: String
    private(set) var effectSlots: [UUID: UInt32] = [:]
    private var started = false
    private var lastFrames: UInt64 = 0
    private var lastProgress = Date()
    private static var pendingCleanup: [RouteSession] = []
    static var cleanupReport = ""
    static var cleanupBlocked: Bool { !pendingCleanup.isEmpty }
    static func retryCleanup() {
        let pending = pendingCleanup; pendingCleanup = []
        for session in pending { session.stop() }
    }
    func hasStalled(sourceActive: Bool) -> Bool {
        let current = frames
        if current != lastFrames || !sourceActive { lastFrames = current; lastProgress = Date() }
        return Date().timeIntervalSince(lastProgress) > 5
    }
    let created = Date()

    init(processes: [AudioObjectID], excluding: Bool, devices: [AudioDevice], settings: RouteSettings, signature: String, softwareVolumes: [String: Float] = [:], softwareMutes: Set<String> = [], captureDeviceUID: String? = nil) throws {
        self.signature = signature
        self.targetDevices = devices
        do {
            guard !devices.isEmpty else { throw AudioFailure(operation: "No output selected", status: kAudioHardwareBadDeviceError) }
            let description: CATapDescription
            if let captureDeviceUID {
                description = excluding ? CATapDescription(excludingProcesses: processes, deviceUID: captureDeviceUID, stream: 0) : CATapDescription(processes: processes, deviceUID: captureDeviceUID, stream: 0)
            }
            else { description = excluding ? CATapDescription(stereoGlobalTapButExcludeProcesses: processes) : CATapDescription(stereoMixdownOfProcesses: processes) }
            description.name = "OpenAudio route"
            description.isPrivate = true
            description.muteBehavior = .mutedWhenTapped
            try checked(AudioHardwareCreateProcessTap(description, &tap), "Starting audio capture")
            let uid = "com.dhrvrm.openaudio.\(UUID().uuidString)"
            let composition: [String: Any] = [
                kAudioAggregateDeviceNameKey: "OpenAudio route",
                kAudioAggregateDeviceUIDKey: uid,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceMainSubDeviceKey: devices[0].uid,
                kAudioAggregateDeviceSubDeviceListKey: devices.enumerated().map { index, device in
                    [kAudioSubDeviceUIDKey: device.uid, kAudioSubDeviceDriftCompensationKey: index != 0, kAudioSubDeviceInputChannelsKey: 0] as [String: Any]
                },
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString, kAudioSubTapDriftCompensationKey: true]],
                kAudioAggregateDeviceTapAutoStartKey: false
            ]
            try checked(AudioHardwareCreateAggregateDevice(composition as CFDictionary, &aggregate), "Preparing output devices")
            try Hardware.validateFloatStreams(aggregate, scope: kAudioObjectPropertyScopeInput)
            try Hardware.validateFloatStreams(aggregate, scope: kAudioObjectPropertyScopeOutput)
            let activeIDs = Hardware.array(aggregate, kAudioAggregateDevicePropertyActiveSubDeviceList)
            let orderedDevices = activeIDs.compactMap { id in devices.first { $0.id == id } }
            guard orderedDevices.count == devices.count else { throw AudioFailure(operation: "Identifying grouped output channels", status: kAudioHardwareBadDeviceError) }
            targetDevices = orderedDevices
            let inputCount = Hardware.channels(aggregate, kAudioObjectPropertyScopeInput)
            let outputCount = Hardware.channels(aggregate, kAudioObjectPropertyScopeOutput)
            if CommandLine.arguments.contains("--smoke") { print("SMOKE layout inputs=\(inputCount) outputs=\(outputCount) expectedOutputs=\(devices.reduce(0, { $0 + $1.outputChannels }))") }
            guard inputCount == 2, outputCount == devices.reduce(0, { $0 + $1.outputChannels }), outputCount > 0, outputCount <= 128 else { throw AudioFailure(operation: "Unsupported channel layout", status: kAudioFormatUnsupportedDataFormatError) }
            let rate = Hardware.read(aggregate, kAudioDevicePropertyNominalSampleRate, default: devices[0].sampleRate)
            guard let processor = OACreate(rate, 0) else { throw AudioFailure(operation: "Allocating audio processor", status: OSStatus(memFullErr)) }
            dsp = processor
            for channel in 0..<outputCount { OASetOutputMap(processor, UInt32(channel), -1) }
            var offset = 0
            for device in orderedDevices {
                OASetOutputMap(processor, UInt32(offset), device.outputChannels == 1 ? 2 : 0)
                if device.outputChannels > 1 { OASetOutputMap(processor, UInt32(offset + 1), 1) }
                offset += device.outputChannels
            }
            for effect in settings.effects where !effect.bypass {
                let desc = AudioComponentDescription(componentType: effect.type, componentSubType: effect.subtype, componentManufacturer: effect.manufacturer, componentFlags: 0, componentFlagsMask: 0)
                try checked(OAAddEffect(processor, desc), "Loading \(effect.name)")
                effectSlots[effect.id] = UInt32(effectSlots.count)
            }
            apply(settings)
            OAInitializeGain(processor, settings.volume * pow(10, settings.boost / 20), settings.muted, settings.balance)
            applyOutputLevels(volumes: softwareVolumes, mutes: softwareMutes)
            try checked(AudioDeviceCreateIOProcID(aggregate, OAIOProc, UnsafeMutableRawPointer(processor), &io), "Preparing audio playback")
            try checked(AudioDeviceStart(aggregate, io), "Starting audio playback")
            started = true
        } catch {
            stop()
            throw error
        }
    }
    func apply(_ settings: RouteSettings) {
        guard let dsp else { return }
        OASetGain(dsp, settings.volume * pow(10, settings.boost / 20), settings.muted, settings.balance)
        for i in 0..<10 { OASetEQ(dsp, UInt32(i), settings.eq[i], settings.eqEnabled) }
        for effect in settings.effects {
            guard let slot = effectSlots[effect.id], let unit = OAEffect(dsp, slot) else { continue }
            for (key, value) in effect.parameters {
                if let parameter = UInt32(key) { AudioUnitSetParameter(unit, parameter, kAudioUnitScope_Global, 0, value, 0) }
            }
        }
    }
    func applyOutputLevels(volumes: [String: Float], mutes: Set<String>) {
        guard let dsp else { return }
        var offset = 0
        for device in targetDevices {
            let gain: Float = mutes.contains(device.uid) ? 0 : volumes[device.uid] ?? 1
            for channel in 0..<device.outputChannels { OASetOutputGain(dsp, UInt32(offset + channel), gain) }
            offset += device.outputChannels
        }
    }
    var peak: Float { dsp.map(OAPeak) ?? 0 }
    var frames: UInt64 { dsp.map(OAFrames) ?? 0 }
    var error: OSStatus { dsp.map(OAError) ?? 0 }
    func unit(_ id: UUID) -> AudioUnit? {
        guard let dsp, let slot = effectSlots[id] else { return nil }
        return OAEffect(dsp, slot)
    }
    func stop() {
        if started, AudioDeviceStop(aggregate, io) == noErr { started = false }
        if let callback = io, AudioDeviceDestroyIOProcID(aggregate, callback) == noErr { io = nil; started = false }
        if aggregate != 0, AudioHardwareDestroyAggregateDevice(aggregate) == noErr { aggregate = 0; io = nil; started = false }
        guard io == nil else {
            if !Self.pendingCleanup.contains(where: { $0 === self }) { Self.pendingCleanup.append(self) }
            return
        }
        if tap != 0, AudioHardwareDestroyProcessTap(tap) == noErr { tap = 0 }
        if let dsp { OADestroy(dsp); self.dsp = nil }
        if aggregate != 0 || tap != 0 {
            Self.cleanupReport = "remaining aggregate=\(aggregate) tap=\(tap) callback=\(String(describing: io))"
            if !Self.pendingCleanup.contains(where: { $0 === self }) { Self.pendingCleanup.append(self) }
        }
    }
    deinit {
        if let dsp, io == nil { OADestroy(dsp) }
    }
}

struct EffectParameter: Identifiable {
    var id: UInt32
    var name: String
    var minimum: Float
    var maximum: Float
    var value: Float
}

func effectParameters(_ unit: AudioUnit) -> [EffectParameter] {
    var size: UInt32 = 0
    guard AudioUnitGetPropertyInfo(unit, kAudioUnitProperty_ParameterList, kAudioUnitScope_Global, 0, &size, nil) == noErr, size > 0 else { return [] }
    var ids = [UInt32](repeating: 0, count: Int(size) / 4)
    guard ids.withUnsafeMutableBytes({ AudioUnitGetProperty(unit, kAudioUnitProperty_ParameterList, kAudioUnitScope_Global, 0, $0.baseAddress!, &size) }) == noErr else { return [] }
    return ids.compactMap { id in
        var info = AudioUnitParameterInfo()
        var infoSize = UInt32(MemoryLayout<AudioUnitParameterInfo>.size)
        guard AudioUnitGetProperty(unit, kAudioUnitProperty_ParameterInfo, kAudioUnitScope_Global, id, &info, &infoSize) == noErr,
              info.flags.contains(.flag_IsWritable), info.minValue.isFinite, info.maxValue.isFinite, info.maxValue > info.minValue else { return nil }
        var value: Float = 0
        AudioUnitGetParameter(unit, id, kAudioUnitScope_Global, 0, &value)
        let name: String
        if let cfName = info.cfNameString {
            name = cfName.takeUnretainedValue() as String
            if info.flags.contains(.flag_CFNameRelease) { cfName.release() }
        } else {
            name = withUnsafePointer(to: &info.name) { $0.withMemoryRebound(to: CChar.self, capacity: 52) { String(cString: $0) } }
        }
        return EffectParameter(id: id, name: name, minimum: info.minValue, maximum: info.maxValue, value: value)
    }
}
