import AppKit
import CryptoKit

struct BrowserRegistration: Codable, Equatable {
    var name = "com.dhrvrm.openaudio"
    var description = "OpenAudio browser tab control"
    var path: String
    var type = "stdio"
    var allowed_origins: [String]
}

enum BrowserIntegration {
    static let browsers: [(id: String, directory: String)] = [
        ("company.thebrowser.Browser", "Arc/User Data"),
        ("com.google.Chrome", "Google/Chrome")
    ]
    static func prepareLocalExtension(bundle: Bundle = .main, support: URL? = nil) throws -> URL {
        guard let source = bundle.resourceURL?.appendingPathComponent("BrowserExtension"),
              FileManager.default.fileExists(atPath: source.appendingPathComponent("worker.js").path) else { throw CocoaError(.fileNoSuchFile) }
        let base = (support ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]).appendingPathComponent("OpenAudio")
        let destination = base.appendingPathComponent("BrowserExtension")
        let staging = base.appendingPathComponent(".BrowserExtension-\(UUID().uuidString)")
        let manager = FileManager.default
        let files = try manager.contentsOfDirectory(atPath: source.path).sorted()
        if let existing = try? manager.contentsOfDirectory(atPath: destination.path).sorted(), existing == files,
           files.allSatisfy({ manager.contentsEqual(atPath: source.appendingPathComponent($0).path, andPath: destination.appendingPathComponent($0).path) }) {
            try register(bundle: bundle, support: support)
            return destination
        }
        try manager.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try manager.copyItem(at: source, to: staging)
        defer { try? manager.removeItem(at: staging) }
        if manager.fileExists(atPath: destination.path) {
            _ = try manager.replaceItemAt(destination, withItemAt: staging)
        } else { try manager.moveItem(at: staging, to: destination) }
        try register(bundle: bundle, support: support)
        return destination
    }
    static func extensionID(bundle: Bundle = .main) throws -> String {
        guard let file = bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "BrowserExtension"),
              let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any],
              let key = manifest["key"] as? String, let data = Data(base64Encoded: key) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return SHA256.hash(data: data).prefix(16).flatMap { [Int($0 >> 4), Int($0 & 15)] }.map { String(UnicodeScalar(97 + $0)!) }.joined()
    }
    static func register(bundle: Bundle = .main, support: URL? = nil) throws {
        guard let host = bundle.url(forResource: "browser-host", withExtension: nil),
              FileManager.default.isExecutableFile(atPath: host.path) else { throw CocoaError(.fileNoSuchFile) }
        let identity = try extensionID(bundle: bundle)
        let registration = BrowserRegistration(path: host.path, allowed_origins: ["chrome-extension://\(identity)/"])
        let base = support ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        for browser in browsers {
            let directory = base.appendingPathComponent(browser.directory)
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }
            let file = directory.appendingPathComponent("NativeMessagingHosts/com.dhrvrm.openaudio.json")
            if BrowserMailbox.read(BrowserRegistration.self, from: file) != registration {
                try BrowserMailbox.write(registration, to: file)
            }
        }
    }
}
