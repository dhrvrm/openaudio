import AppKit
import Carbon
import CryptoKit

final class MediaProcessGate: @unchecked Sendable {
    let process = Process()
    private let lock = NSLock()
    private var cancelled = false
    func start() throws {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { throw CancellationError() }
        try process.run()
    }
    func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        if process.isRunning { process.terminate() }
    }
}
struct NativeMediaProbe {
    static let providers = [(id: "com.apple.Music", name: "Apple Music"), (id: "com.spotify.client", name: "Spotify")]
    static let operations = ["read", "playpause", "next track", "previous track"]
    static func execute(appID: String, operation: String, authorization: Bool = false, expectedLifetime: String) -> NativeMediaResult {
        guard providers.contains(where: { $0.id == appID }), operations.contains(operation) else { return NativeMediaResult(error: "Unsupported media request") }
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: appID).first, lifetime(running) == expectedLifetime else { return NativeMediaResult(error: "Open the music app first") }
        let target = NSAppleEventDescriptor(processIdentifier: running.processIdentifier)
        let permission = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, authorization)
        guard permission == noErr else { return NativeMediaResult(error: "Automation access required. Use Connect, or allow OpenAudio in System Settings → Privacy & Security → Automation.") }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: appID).first.map(lifetime) == expectedLifetime else { return NativeMediaResult(error: "The music app restarted while access was being requested") }
        if operation != "read" {
            let ids: [String: AEEventID] = ["playpause": 0x506C5073, "next track": 0x4E657874, "previous track": 0x50726576]
            guard let eventID = ids[operation] else { return NativeMediaResult(error: "Unsupported playback action") }
            let event = NSAppleEventDescriptor(eventClass: 0x686F6F6B, eventID: eventID, targetDescriptor: target, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
            do {
                let reply = try event.sendEvent(options: [.waitForReply, .neverInteract], timeout: 3)
                if let error = reply.paramDescriptor(forKeyword: keyErrorNumber), error.int32Value != 0 {
                    return NativeMediaResult(error: "Player rejected the action (\(error.int32Value))")
                }
                return NativeMediaResult()
            } catch { return NativeMediaResult(error: error.localizedDescription) }
        }
        let music = appID == "com.apple.Music"
        let body: String
        if operation == "read" {
            body = """
            if (player state as string) is "stopped" then return {"", "", "", 0, 0, "stopped", ""}
            set t to current track
            set cover to ""
            try
                set cover to \(music ? "raw data of artwork 1 of t" : "artwork url of t")
            end try
            return {name of t, artist of t, album of t, duration of t, player position, (player state as string), cover}
            """
        } else { body = operation }
        let source = "with timeout of 25 seconds\ntell application id \"\(appID)\"\n\(body)\nend tell\nend timeout"
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return NativeMediaResult(error: "Could not prepare the music integration") }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: appID).first.map(lifetime) == expectedLifetime else { return NativeMediaResult(error: "The music source is no longer available") }
        let result = script.executeAndReturnError(&error)
        guard NSRunningApplication.runningApplications(withBundleIdentifier: appID).first.map(lifetime) == expectedLifetime else { return NativeMediaResult(error: "The music source changed during the request") }
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            return NativeMediaResult(error: code == -1743 ? "Automation access denied. Allow OpenAudio in System Settings → Privacy & Security → Automation, then reconnect." : "Music integration: \(error[NSAppleScript.errorMessage] as? String ?? "Request failed")")
        }
        guard operation == "read" else { return NativeMediaResult() }
        guard result.numberOfItems >= 6, let title = result.atIndex(1)?.stringValue, !title.isEmpty else { return NativeMediaResult() }
        var track = MediaTrack(title: String(title.prefix(512)), artist: String((result.atIndex(2)?.stringValue ?? "").prefix(512)), album: String((result.atIndex(3)?.stringValue ?? "").prefix(512)), updatedAt: Date().timeIntervalSince1970, provider: music ? "Apple Music" : "Spotify")
        let duration = result.atIndex(4)?.doubleValue ?? 0
        let position = result.atIndex(5)?.doubleValue ?? 0
        track.duration = duration > 0 && duration.isFinite ? duration / (music ? 1 : 1000) : nil
        track.position = position >= 0 && position.isFinite ? position : nil
        track.playing = result.atIndex(6)?.stringValue == "playing"
        if music, let data = result.atIndex(7)?.data, data.count > 32, data.count <= 4_194_304 { track.artworkData = data; track.artworkRevision = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        if !music, let url = result.atIndex(7)?.stringValue, MediaURL.allowed(url) != nil { track.artworkURL = url }
        return NativeMediaResult(track: track)
    }

    static func lifetime(_ app: NSRunningApplication) -> String { "\(app.processIdentifier):\(app.launchDate?.timeIntervalSince1970 ?? 0)" }
    static func run(appID: String, operation: String = "read", authorization: Bool = false, expectedLifetime: String) async -> NativeMediaResult {
        let gate = MediaProcessGate()
        let process = gate.process
        return await withTaskCancellationHandler {
            await Task.detached(priority: .utility) {
                guard let executable = Bundle.main.executableURL else { return NativeMediaResult(error: "Open the OpenAudio application bundle") }
                let output = Pipe()
                process.executableURL = executable
                process.arguments = ["--media-probe", appID, operation, expectedLifetime, authorization ? "authorize" : "existing"]
                process.standardOutput = output
                process.standardError = FileHandle.nullDevice
                do {
                    try gate.start()
                    let timeout = DispatchWorkItem { gate.cancel() }
                    DispatchQueue.global().asyncAfter(deadline: .now() + (authorization ? 30 : 4), execute: timeout)
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timeout.cancel()
                    guard data.count <= 6_000_000, process.terminationStatus == 0, let result = try? JSONDecoder().decode(NativeMediaResult.self, from: data) else {
                        return NativeMediaResult(error: "Music integration timed out or returned unavailable data. Reconnect to retry.")
                    }
                    return result
                } catch { return NativeMediaResult(error: error.localizedDescription) }
            }.value
        } onCancel: { gate.cancel() }
    }
}
