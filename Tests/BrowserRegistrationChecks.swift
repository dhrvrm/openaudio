import AppKit

@main
struct BrowserRegistrationChecks {
    static func main() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("OpenAudio registration \(UUID().uuidString)")
        defer { try? manager.removeItem(at: root) }
        let source = URL(fileURLWithPath: CommandLine.arguments[1])
        let first = root.appendingPathComponent("First Location/OpenAudio.app")
        try manager.createDirectory(at: first.deletingLastPathComponent(), withIntermediateDirectories: true)
        try manager.copyItem(at: source, to: first)
        let support = root.appendingPathComponent("Application Support")
        let arc = support.appendingPathComponent("Arc/User Data/NativeMessagingHosts")
        let chrome = support.appendingPathComponent("Google/Chrome/NativeMessagingHosts")
        for folder in [arc, chrome] { try manager.createDirectory(at: folder, withIntermediateDirectories: true) }
        let unrelated = arc.appendingPathComponent("another.host.json")
        try Data("unrelated".utf8).write(to: unrelated)
        let bundle = Bundle(url: first)!
        try BrowserIntegration.register(bundle: bundle, support: support)
        let registrationURL = arc.appendingPathComponent("com.dhrvrm.openaudio.json")
        let registration = BrowserMailbox.read(BrowserRegistration.self, from: registrationURL)!
        precondition(registration.path == first.appendingPathComponent("Contents/Resources/browser-host").path)
        precondition(registration.allowed_origins == ["chrome-extension://imjfgecaihkjjehnccfkhdoafgadmlfk/"])
        precondition(manager.fileExists(atPath: chrome.appendingPathComponent("com.dhrvrm.openaudio.json").path))
        print("PASS: automatic registration uses embedded executable and exact companion origin")
        let date = try registrationURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        try BrowserIntegration.register(bundle: bundle, support: support)
        let nextDate = try registrationURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        precondition(nextDate == date)
        print("PASS: unchanged registration avoids rewriting files")
        let local = try BrowserIntegration.prepareLocalExtension(bundle: bundle, support: support)
        precondition(local.path == support.appendingPathComponent("OpenAudio/BrowserExtension").path)
        for name in ["manifest.json", "worker.js", "engine.js", "report.js", "media.js", "device-catalog.js", "offscreen.html", "offscreen.js", "options.html", "options.js", "popup.css"] {
            precondition(manager.fileExists(atPath: local.appendingPathComponent(name).path))
        }
        let originalManifest = try Data(contentsOf: local.appendingPathComponent("manifest.json"))
        try Data("obsolete".utf8).write(to: local.appendingPathComponent("obsolete.js"))
        try Data("changed".utf8).write(to: local.appendingPathComponent("worker.js"))
        let updated = try BrowserIntegration.prepareLocalExtension(bundle: bundle, support: support)
        precondition(updated.path == local.path)
        precondition(!manager.fileExists(atPath: local.appendingPathComponent("obsolete.js").path))
        let nextManifest = try Data(contentsOf: local.appendingPathComponent("manifest.json"))
        let worker = try Data(contentsOf: local.appendingPathComponent("worker.js"))
        let bundledWorker = try Data(contentsOf: first.appendingPathComponent("Contents/Resources/BrowserExtension/worker.js"))
        precondition(nextManifest == originalManifest && worker == bundledWorker)
        print("PASS: local companion exports all runtime files and updates the same folder without changing identity")
        let moved = root.appendingPathComponent("New Location/OpenAudio.app")
        try manager.createDirectory(at: moved.deletingLastPathComponent(), withIntermediateDirectories: true)
        try manager.copyItem(at: first, to: moved)
        try BrowserIntegration.register(bundle: Bundle(url: moved)!, support: support)
        let repaired = BrowserMailbox.read(BrowserRegistration.self, from: registrationURL)!
        precondition(repaired.path == moved.appendingPathComponent("Contents/Resources/browser-host").path)
        let untouched = try Data(contentsOf: unrelated)
        precondition(untouched == Data("unrelated".utf8))
        print("PASS: moving the app repairs its registration and preserves unrelated hosts")
    }
}
