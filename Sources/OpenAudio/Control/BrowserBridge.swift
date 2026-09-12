import AppKit
import Foundation

struct BrowserOutput: Codable, Equatable, Identifiable {
    var id: String
    var label: String
}
struct TabSettings: Codable, Equatable {
    var volume: Double = 1
    var muted = false
    var output = "default"
    var release = false
}
struct BrowserTab: Codable, Identifiable {
    var id: Int
    var title: String
    var site: String
    var audible: Bool
    var active: Bool
    var status: String
    var settings: TabSettings
    var revision: Int
    var peak: Float
    var media: MediaTrack?
    var document: String?
}
struct BrowserMediaOutcome: Codable {
    var id: String
    var pending: Bool
    var error: String?
}
struct BrowserReport: Codable {
    var mediaOutcome: BrowserMediaOutcome?
    var companion: String
    var openApp: Bool?
    var acknowledgedOperation: String?
    var owns: Bool
    var released: String
    var tabs: [BrowserTab]
    var outputs: [BrowserOutput]
    var companionVersion: String?
    var deviceStatus: String?
    var deviceError: String?
    var devicesUpdatedAt: Double?
    var error: String
    var namedOutputs: [BrowserOutput] {
        outputs.filter { !$0.id.isEmpty && !["default", "communications"].contains($0.id) }.map { BrowserOutput(id: $0.id, label: $0.label.isEmpty || $0.label == "Permitted output" ? "Unnamed output (name unavailable)" : $0.label) }
    }
    var needsDeviceAccess: Bool { deviceStatus == "permission-required" || deviceStatus == "denied" || (deviceStatus == nil && namedOutputs.isEmpty) }
}
struct BrowserSnapshot: Codable, Identifiable {
    var id: String
    var browser: String
    var pid: Int32
    var launched: Double
    var updated: Double
    var report: BrowserReport
    var fresh: Bool { Date().timeIntervalSince1970 - updated < 4 }
}
struct BrowserOperation: Codable, Equatable {
    var id = UUID().uuidString
    var action: String
    var tab: Int?
    var document: String?
}
struct BrowserCommand: Codable, Equatable {
    var session: String
    var authority: String
    var revision: Int
    var expires: Double
    var allow: Bool
    var reserved: Bool
    var tabs: [String: TabSettings]
    var operation: BrowserOperation?
    var observeMedia: Bool?
}

enum BrowserMailbox {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OpenAudio/BrowserBridge")
    }
    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(value)
        guard data.count <= 262144 else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 262144,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    static func nativeHost() {
        let parentPID = getppid()
        guard let parent = NSRunningApplication(processIdentifier: parentPID),
              let browser = parent.bundleIdentifier,
              BrowserIntegration.browsers.contains(where: { $0.id == browser }),
              let launch = parent.launchDate else { exit(1) }
        let origin = CommandLine.arguments.dropFirst().first { $0.hasPrefix("chrome-extension://") }
        guard let identity = try? BrowserIntegration.extensionID(), origin == "chrome-extension://\(identity)/" else { exit(1) }
        var connectionSession: String?
        func readExact(_ count: Int) -> Data? {
            var result = Data()
            while result.count < count {
                guard let bytes = try? FileHandle.standardInput.read(upToCount: count - result.count), !bytes.isEmpty else { return nil }
                result.append(bytes)
            }
            return result
        }
        while let header = readExact(4) {
            let size = header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
            guard size > 0, size <= 262144, let data = readExact(Int(size)),
                  let report = try? JSONDecoder().decode(BrowserReport.self, from: data),
                  UUID(uuidString: report.companion) != nil, report.tabs.count <= 200, report.outputs.count <= 100,
                  Set(report.tabs.map(\.id)).count == report.tabs.count,
                  report.tabs.allSatisfy({ $0.id >= 0 && $0.title.count <= 512 && $0.site.count <= 256 && $0.settings.volume.isFinite && (0...1).contains($0.settings.volume) }) else { exit(1) }
            let session = report.companion
            guard connectionSession == nil || connectionSession == session else { exit(1) }
            connectionSession = session
            let observation = directory.appendingPathComponent("\(session).state.json")
            let commandURL = directory.appendingPathComponent("\(session).command.json")
            if let previous = read(BrowserSnapshot.self, from: observation), previous.pid != parentPID || previous.launched != launch.timeIntervalSince1970 { exit(1) }
            let snapshot = BrowserSnapshot(id: session, browser: browser, pid: parentPID, launched: launch.timeIntervalSince1970, updated: Date().timeIntervalSince1970, report: report)
            do {
                try write(snapshot, to: observation)
                if report.openApp == true {
                    let application = Bundle.main.bundleURL
                    NSWorkspace.shared.open([URL(string: "openaudio://browser")!], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
                }
                let command = read(BrowserCommand.self, from: commandURL)
                let reply = try JSONEncoder().encode(command)
                var length = UInt32(reply.count).littleEndian
                try FileHandle.standardOutput.write(contentsOf: withUnsafeBytes(of: &length) { Data($0) })
                try FileHandle.standardOutput.write(contentsOf: reply)
            } catch { exit(1) }
        }
    }
}

@MainActor
final class BrowserBridge {
    var observeMedia = false
    let authority = UUID().uuidString
    private(set) var snapshots: [BrowserSnapshot] = []
    private var commands: [String: BrowserCommand] = [:]
    private(set) var reservedBrowsers = Set<String>()
    private(set) var failure: String?

    func read() {
        snapshots = []
        reservedBrowsers = []
        let files = (try? FileManager.default.contentsOfDirectory(at: BrowserMailbox.directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasSuffix(".state.json") {
            guard let state = BrowserMailbox.read(BrowserSnapshot.self, from: file), UUID(uuidString: state.id) != nil else { continue }
            let commandURL = BrowserMailbox.directory.appendingPathComponent("\(state.id).command.json")
            guard let running = NSRunningApplication(processIdentifier: state.pid), running.bundleIdentifier == state.browser,
                  running.launchDate?.timeIntervalSince1970 == state.launched else {
                try? FileManager.default.removeItem(at: file)
                try? FileManager.default.removeItem(at: commandURL)
                commands.removeValue(forKey: state.id)
                continue
            }
            var command = commands[state.id] ?? BrowserMailbox.read(BrowserCommand.self, from: commandURL)
            if let value = command, value.reserved, state.fresh, !state.report.owns, state.report.released == value.authority {
                command?.reserved = false
            }
            if state.report.owns { command?.reserved = true }
            if state.report.owns || command?.reserved == true { reservedBrowsers.insert(state.browser) }
            if let command { commands[state.id] = command }
            if state.fresh || command?.reserved == true { snapshots.append(state) }
        }
        snapshots.sort { $0.id < $1.id }
    }
    func publish(allow: Bool) {
        for state in snapshots {
            let old = commands[state.id]
            var desired = old?.authority == authority ? old!.tabs : [:]
            for tab in state.report.tabs where desired[String(tab.id)] == nil || (!tab.active && desired[String(tab.id)]?.release == true) {
                desired[String(tab.id)] = tab.settings
            }
            let ids = Set(state.report.tabs.map { String($0.id) })
            desired = desired.filter { ids.contains($0.key) }
            let operation = (old?.authority == authority ? old?.operation : nil).flatMap { state.report.acknowledgedOperation == $0.id ? nil : $0 }
            var value = BrowserCommand(session: state.id, authority: authority, revision: old?.revision ?? 0, expires: Date().timeIntervalSince1970 + 5,
                                       allow: allow && state.fresh && reservedBrowsers.contains(state.browser), reserved: reservedBrowsers.contains(state.browser), tabs: desired, operation: operation, observeMedia: observeMedia)
            var comparable = old
            comparable?.expires = value.expires
            if comparable != value { value.revision += 1 }
            commands[state.id] = value
            do { try BrowserMailbox.write(value, to: BrowserMailbox.directory.appendingPathComponent("\(state.id).command.json")); failure = nil }
            catch { failure = "Browser connection could not be updated: \(error.localizedDescription)" }
        }
    }
    func settings(_ session: String, _ tab: BrowserTab) -> TabSettings { commands[session]?.tabs[String(tab.id)] ?? tab.settings }
    func edit(_ session: String, tab: BrowserTab, _ change: (inout TabSettings) -> Void) {
        guard var command = commands[session] else { return }
        var value = settings(session, tab)
        change(&value)
        value.volume = value.volume.isFinite ? min(1, max(0, value.volume)) : 1
        let outputs = snapshots.first { $0.id == session }?.report.outputs.map(\.id) ?? []
        guard value.output == "default" || outputs.contains(value.output) else { return }
        command.tabs[String(tab.id)] = value
        command.revision += 1
        commands[session] = command
    }
    func focus(_ session: String, tab: Int) {
        guard var command = commands[session] else { return }
        command.operation = BrowserOperation(action: "focus", tab: tab); command.revision += 1; commands[session] = command
    }
    func refreshDevices(_ session: String) {
        guard var command = commands[session] else { return }
        command.operation = BrowserOperation(action: "refresh"); command.revision += 1; commands[session] = command
    }
    func openSetup(_ session: String) {
        guard var command = commands[session] else { return }
        command.operation = BrowserOperation(action: "setup"); command.revision += 1; commands[session] = command
    }
    func mediaCommand(source: ListeningSource, action: String) async -> String? {
        guard let session = source.session, let tabID = source.tabID, !source.lifetime.isEmpty,
              ["playpause", "next", "previous"].contains(action),
              let state = snapshots.first(where: { $0.id == session }), state.fresh,
              let tab = state.report.tabs.first(where: { $0.id == tabID }), tab.document == source.lifetime,
              tab.media?.fresh(at: Date().timeIntervalSince1970) == true, tab.media?.commands?.contains(action) == true,
              var command = commands[session] else { return "The tab changed. Wait for current track details." }
        if let operation = command.operation, state.report.acknowledgedOperation != operation.id { return "Another browser request is still pending." }
        let operation = BrowserOperation(action: action, tab: tabID, document: source.lifetime)
        command.operation = operation; command.revision += 1; commands[session] = command
        defer { if commands[session]?.operation?.id == operation.id { commands[session]?.operation = nil } }
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return "Command canceled. Check the player before trying again." }
            guard let current = snapshots.first(where: { $0.id == session }), current.fresh else { return "Browser disconnected. Check the player before trying again." }
            guard current.report.tabs.first(where: { $0.id == tabID })?.document == source.lifetime else { return "The tab closed or navigated while the command was pending." }
            if let outcome = current.report.mediaOutcome, outcome.id == operation.id, !outcome.pending { return outcome.error }
        }
        return "The player did not respond. Check the tab before trying again."
    }
    func revision(_ session: String) -> Int { commands[session]?.revision ?? 0 }
}
