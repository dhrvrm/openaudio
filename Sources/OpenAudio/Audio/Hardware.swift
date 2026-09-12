import AppKit
import CoreAudio
import AudioToolbox

struct AudioFailure: LocalizedError {
    let operation: String
    let status: OSStatus
    var errorDescription: String? { "\(operation) failed (\(status)). Check audio capture permission and device availability, then retry." }
}

func checked(_ status: OSStatus, _ operation: String) throws {
    if status != noErr { throw AudioFailure(operation: operation, status: status) }
}

enum Hardware {
    static let system = AudioObjectID(kAudioObjectSystemObject)
    static func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, _ element: UInt32 = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }
    static func read<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, default value: T, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, element: UInt32 = kAudioObjectPropertyElementMain) -> T {
        var result = value
        var property = address(selector, scope, element)
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &result) { AudioObjectGetPropertyData(id, &property, 0, nil, &size, $0) }
        return status == noErr ? result : value
    }
    static func array(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> [UInt32] {
        var property = address(selector, scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &property, 0, nil, &size) == noErr, size > 0 else { return [] }
        var result = [UInt32](repeating: 0, count: Int(size) / 4)
        let status = result.withUnsafeMutableBytes { AudioObjectGetPropertyData(id, &property, 0, nil, &size, $0.baseAddress!) }
        return status == noErr ? Array(result.prefix(Int(size) / 4)) : []
    }
    static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String {
        var property = address(selector)
        var value: CFString? = nil
        var size = UInt32(MemoryLayout<CFString?>.size)
        guard withUnsafeMutablePointer(to: &value, { AudioObjectGetPropertyData(id, &property, 0, nil, &size, $0) }) == noErr else { return "" }
        return value as String? ?? ""
    }
    static func writable(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, element: UInt32 = kAudioObjectPropertyElementMain) -> Bool {
        var property = address(selector, scope, element)
        var result: DarwinBoolean = false
        return AudioObjectIsPropertySettable(id, &property, &result) == noErr && result.boolValue
    }
    static func write<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: T, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, element: UInt32 = kAudioObjectPropertyElementMain) throws {
        var value = value
        var property = address(selector, scope, element)
        try checked(withUnsafePointer(to: &value) { AudioObjectSetPropertyData(id, &property, 0, nil, UInt32(MemoryLayout<T>.size), $0) }, "Changing device setting")
    }
    static func channels(_ id: AudioObjectID, _ scope: AudioObjectPropertyScope) -> Int {
        var property = address(kAudioDevicePropertyStreamConfiguration, scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &property, 0, nil, &size) == noErr, size >= MemoryLayout<AudioBufferList>.size else { return 0 }
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(id, &property, 0, nil, &size, pointer) == noErr else { return 0 }
        return UnsafeMutableAudioBufferListPointer(pointer.assumingMemoryBound(to: AudioBufferList.self)).reduce(0) { $0 + Int($1.mNumberChannels) }
    }
    static func volume(_ id: AudioObjectID, _ scope: AudioObjectPropertyScope) -> Float? {
        let elements: [UInt32] = [0, 1, 2]
        let values = elements.filter { writable(id, kAudioDevicePropertyVolumeScalar, scope: scope, element: $0) }.map { read(id, kAudioDevicePropertyVolumeScalar, default: Float(1), scope: scope, element: $0) }
        return values.isEmpty ? nil : values.reduce(0, +) / Float(values.count)
    }
    static func setVolume(_ id: AudioObjectID, _ value: Float, _ scope: AudioObjectPropertyScope) throws {
        if writable(id, kAudioDevicePropertyVolumeScalar, scope: scope) {
            try write(id, kAudioDevicePropertyVolumeScalar, min(1, max(0, value)), scope: scope)
        } else {
            let elements: [UInt32] = [1, 2].filter { writable(id, kAudioDevicePropertyVolumeScalar, scope: scope, element: $0) }
            guard !elements.isEmpty else { throw AudioFailure(operation: "Hardware volume is unavailable", status: kAudioHardwareUnknownPropertyError) }
            for element in elements { try write(id, kAudioDevicePropertyVolumeScalar, min(1, max(0, value)), scope: scope, element: element) }
        }
    }
    static func muted(_ id: AudioObjectID, _ scope: AudioObjectPropertyScope) -> Bool? {
        guard writable(id, kAudioDevicePropertyMute, scope: scope) else { return nil }
        return read(id, kAudioDevicePropertyMute, default: UInt32(0), scope: scope) != 0
    }
    static func rates(_ id: AudioObjectID) -> [Double] {
        var property = address(kAudioDevicePropertyAvailableNominalSampleRates)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &property, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ranges = [AudioValueRange](repeating: AudioValueRange(), count: Int(size) / MemoryLayout<AudioValueRange>.size)
        guard ranges.withUnsafeMutableBytes({ AudioObjectGetPropertyData(id, &property, 0, nil, &size, $0.baseAddress!) }) == noErr else { return [] }
        return [8000,16000,22050,32000,44100,48000,88200,96000,176400,192000].filter { rate in ranges.contains { rate >= $0.mMinimum && rate <= $0.mMaximum } }
    }
    static func devices() -> [AudioDevice] {
        array(system, kAudioHardwarePropertyDevices).compactMap { id in
            let uid = string(id, kAudioDevicePropertyDeviceUID)
            guard !uid.hasPrefix("com.dhrvrm.openaudio."), !uid.isEmpty else { return nil }
            let inputs = channels(id, kAudioObjectPropertyScopeInput), outputs = channels(id, kAudioObjectPropertyScopeOutput)
            guard inputs + outputs > 0 else { return nil }
            return AudioDevice(id: id, uid: uid, name: string(id, kAudioObjectPropertyName), inputChannels: inputs, outputChannels: outputs,
                sampleRate: read(id, kAudioDevicePropertyNominalSampleRate, default: Double(48000)), rates: rates(id),
                outputVolume: volume(id, kAudioObjectPropertyScopeOutput), inputVolume: volume(id, kAudioObjectPropertyScopeInput),
                outputMuted: muted(id, kAudioObjectPropertyScopeOutput), inputMuted: muted(id, kAudioObjectPropertyScopeInput),
                transport: read(id, kAudioDevicePropertyTransportType, default: UInt32(0)))
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    static func defaultDevice(_ selector: UInt32 = kAudioHardwarePropertyDefaultOutputDevice) -> AudioObjectID {
        read(system, selector, default: AudioObjectID(0))
    }
    static func sources() -> [AudioSource] {
        var sources: [String: AudioSource] = [:]
        let running = NSWorkspace.shared.runningApplications
        for process in array(system, kAudioHardwarePropertyProcessObjectList) {
            let pid = read(process, kAudioProcessPropertyPID, default: pid_t(0))
            guard pid != getpid(), pid > 0 else { continue }
            let app = NSRunningApplication(processIdentifier: pid)
            let bundle = string(process, kAudioProcessPropertyBundleID)
            var pathBuffer = [CChar](repeating: 0, count: 4096)
            let executable = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 ? String(cString: pathBuffer) : nil
            let rootURL: URL? = executable.flatMap { path in
                let components = (path as NSString).pathComponents
                guard let index = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
                return URL(fileURLWithPath: NSString.path(withComponents: Array(components.prefix(index + 1))))
            }
            let owner = rootURL.flatMap { url in running.first { $0.bundleURL == url } } ?? app
            let rootBundle = rootURL.flatMap(Bundle.init(url:))
            let sharedHelper = rootURL == nil && executable?.contains("/XPCServices/") == true
            let identity = sharedHelper ? "process:\(pid):\(process)" : rootBundle?.bundleIdentifier ?? owner?.bundleIdentifier ?? (bundle.isEmpty ? "process:\(pid):\(process)" : bundle)
            let active = read(process, kAudioProcessPropertyIsRunningOutput, default: UInt32(0)) != 0
            if var existing = sources[identity] {
                existing.processes.append(process); existing.active = existing.active || active; sources[identity] = existing
            } else {
                sources[identity] = AudioSource(id: identity, name: owner?.localizedName ?? rootURL?.deletingPathExtension().lastPathComponent ?? (bundle.isEmpty ? "Process \(pid)" : bundle), processes: [process], pid: pid, active: active, iconURL: rootURL ?? owner?.bundleURL)
            }
        }
        return sources.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    static func selfProcesses() -> [AudioObjectID] {
        array(system, kAudioHardwarePropertyProcessObjectList).filter { read($0, kAudioProcessPropertyPID, default: pid_t(0)) == getpid() }
    }
    static func validateFloatStreams(_ device: AudioObjectID, scope: AudioObjectPropertyScope) throws {
        for stream in array(device, kAudioDevicePropertyStreams, scope: scope) {
            let format = read(stream, kAudioStreamPropertyVirtualFormat, default: AudioStreamBasicDescription())
            guard format.mFormatID == kAudioFormatLinearPCM, format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                  format.mBitsPerChannel == 32, format.mFormatFlags & kAudioFormatFlagIsBigEndian == 0 else {
                throw AudioFailure(operation: "This device's stream format is unsupported", status: kAudioFormatUnsupportedDataFormatError)
            }
        }
    }
}
