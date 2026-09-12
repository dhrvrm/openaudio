import AppKit
import AVFoundation
import CoreAudio

@MainActor
enum Diagnostics {
    static func smoke() throws {
        let devices = Hardware.devices()
        let requested = CommandLine.arguments.indices.filter { CommandLine.arguments[$0] == "--output" && $0 + 1 < CommandLine.arguments.count }.map { CommandLine.arguments[$0 + 1] }
        let outputs = requested.isEmpty ? devices.filter { $0.id == Hardware.defaultDevice() } : requested.compactMap { uid in devices.first { $0.uid == uid } }
        guard !outputs.isEmpty, requested.isEmpty || outputs.count == requested.count else {
            throw AudioFailure(operation: "Finding smoke-test outputs", status: kAudioHardwareBadDeviceError)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openaudio-smoke-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let rate = 48000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000 * 12)!
        buffer.frameLength = buffer.frameCapacity
        for i in 0..<Int(buffer.frameLength) {
            let fade = min(1, Double(i) / 2400, Double(Int(buffer.frameLength) - i) / 2400)
            let sample = Float(sin(Double(i) * 2 * .pi * 440 / rate) * 0.015 * fade)
            buffer.floatChannelData![0][i] = sample; buffer.floatChannelData![1][i] = sample
        }
        var fileSettings = format.settings
        fileSettings[AVLinearPCMIsNonInterleaved] = false
        do { let file = try AVAudioFile(forWriting: url, settings: fileSettings); try file.write(from: buffer) }
        let beforeTaps = Set(Hardware.array(Hardware.system, kAudioHardwarePropertyTapList))
        let player = Process(); player.executableURL = URL(fileURLWithPath: "/usr/bin/afplay"); player.arguments = [url.path]
        try player.run()
        defer { if player.isRunning { player.terminate(); player.waitUntilExit() } }
        var ids: [AudioObjectID] = []
        let deadline = Date().addingTimeInterval(3)
        while ids.isEmpty && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            ids = Hardware.array(Hardware.system, kAudioHardwarePropertyProcessObjectList).filter { Hardware.read($0, kAudioProcessPropertyPID, default: pid_t(0)) == player.processIdentifier }
        }
        guard !ids.isEmpty else { throw AudioFailure(operation: "Finding test audio process", status: kAudioHardwareBadObjectError) }
        if CommandLine.arguments.contains("--controller") {
            try controllerSmoke(playerPID: player.processIdentifier, outputs: outputs, beforeTaps: beforeTaps)
            return
        }
        var settings = RouteSettings(outputs: outputs.map(\.uid)); settings.volume = 0.5
        print("SMOKE process=\(player.processIdentifier) objects=\(ids) destination=\(outputs.map(\.name).joined(separator: " + "))")
        fflush(stdout)
        let scoped = CommandLine.arguments.contains("--scoped")
        let global = CommandLine.arguments.contains("--global") || scoped
        let membership = global ? Hardware.array(Hardware.system, kAudioHardwarePropertyProcessObjectList).filter { !ids.contains($0) } : ids
        let session = try RouteSession(processes: membership, excluding: global, devices: outputs, settings: settings, signature: "smoke", captureDeviceUID: scoped ? Hardware.string(Hardware.defaultDevice(), kAudioDevicePropertyDeviceUID) : nil)
        defer { session.stop(); RouteSession.retryCleanup() }
        var peak: Float = 0
        let finish = Date().addingTimeInterval(4)
        while Date() < finish {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1)); peak = max(peak, session.peak)
        }
        print("SMOKE frames=\(session.frames) peak=\(peak) renderError=\(session.error)")
        guard session.frames > 0, peak > 0.0001, session.error == 0 else {
            throw AudioFailure(operation: "Receiving test signal; grant OpenAudio system audio capture permission and retry", status: session.error == 0 ? -1 : session.error)
        }
        session.stop(); RouteSession.retryCleanup()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        RouteSession.retryCleanup()
        let afterTaps = Set(Hardware.array(Hardware.system, kAudioHardwarePropertyTapList))
        print("SMOKE cleanup before=\(beforeTaps) after=\(afterTaps) pending=\(RouteSession.cleanupBlocked) \(RouteSession.cleanupReport)")
        guard afterTaps.subtracting(beforeTaps).isEmpty, !RouteSession.cleanupBlocked else {
            throw AudioFailure(operation: "Cleaning up test capture", status: -1)
        }
        print("SMOKE PASS: nonzero test signal processed and capture released. Physical audibility requires listener confirmation.")
    }

    private static func controllerSmoke(playerPID: pid_t, outputs: [AudioDevice], beforeTaps: Set<AudioObjectID>) throws {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent("openaudio-controller-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: storage) }
        let controller = AudioController(storageURL: storage, startMonitoring: false)
        defer { controller.shutdown() }
        controller.refresh()
        guard let source = controller.sources.first(where: { $0.pid == playerPID }) else {
            throw AudioFailure(operation: "Discovering controller test source", status: -1)
        }
        func sample() throws -> Float {
            let deadline = Date().addingTimeInterval(1)
            while Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)); controller.refresh() }
            guard let observation = controller.observations[source.id], observation.active, !observation.failure else {
                throw AudioFailure(operation: controller.observations[source.id]?.text ?? "Missing controller observation", status: -1)
            }
            print("CONTROLLER \(observation.text) peak=\(observation.peak)")
            return observation.peak
        }
        controller.edit(source.id) { $0.favorite = true }
        guard !controller.enabled else { throw AudioFailure(operation: "Favorite unexpectedly activated audio", status: -1) }
        controller.edit(source.id) { $0.volume = 0.5; $0.outputs = [outputs[0].uid] }
        guard controller.enabled else { throw AudioFailure(operation: "Listening edit failed to activate control", status: -1) }
        let half = try sample()
        controller.edit(source.id) { $0.volume = 0.2 }
        let quiet = try sample()
        guard half > 0.001, quiet > 0, abs(quiet / half - 0.4) < 0.08 else {
            throw AudioFailure(operation: "Controller volume did not change delivered gain", status: -1)
        }
        controller.edit(source.id) { $0.muted = true }
        guard try sample() < 0.00001 else { throw AudioFailure(operation: "Controller mute did not silence signal", status: -1) }
        controller.edit(source.id) { $0.muted = false }
        for output in outputs {
            controller.edit(source.id) { $0.outputs = [output.uid] }
            guard try sample() > 0.001 else { throw AudioFailure(operation: "Output switch lost signal", status: -1) }
            print("CONTROLLER output=\(output.name) uid=\(output.uid)")
        }
        controller.setProcessing(false)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        RouteSession.retryCleanup()
        let afterTaps = Set(Hardware.array(Hardware.system, kAudioHardwarePropertyTapList))
        guard afterTaps.subtracting(beforeTaps).isEmpty, !RouteSession.cleanupBlocked else {
            throw AudioFailure(operation: "Controller bypass did not release captures", status: -1)
        }
        print("SMOKE PASS: controller edits activate processing; volume gain, mute, output switches, and bypass cleanup verified. Physical audibility requires listener confirmation.")
    }
}
