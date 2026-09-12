import Foundation
import CryptoKit

struct MediaTrack: Codable, Equatable {
    var title: String
    var artist: String = ""
    var album: String = ""
    var artworkURL: String?
    var artworkData: Data?
    var artworkRevision: String?
    var duration: Double?
    var position: Double?
    var playing: Bool?
    var updatedAt: Double
    var provider: String = "Source"
    var commands: [String]?
    var identity: String { [title, artist, album, artworkURL ?? "", artworkRevision ?? ""].joined(separator: "\u{1F}") }
    func fresh(at now: Double) -> Bool { updatedAt.isFinite && now - updatedAt < 8 && now >= updatedAt - 2 }
    var lookupKey: String {
        let text = [artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "title-suggestions-v1" : "covers-v2", title, artist, album].map(Self.normalized).joined(separator: "\u{1F}")
        return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct ListeningSource: Identifiable, Equatable {
    var id: String
    var name: String
    var appID: String
    var session: String?
    var tabID: Int?
    var active: Bool
    var available = true
    var track: MediaTrack?
    var becameActive: Double = 0
    var status = "Track details unavailable"
    var lifetime: String = ""
    var visualPlaying: Bool { available && (track?.playing ?? active) }
    var visualPlaybackLabel: String {
        guard available else { return "Source unavailable" }
        if let playing = track?.playing { return playing ? "Playing" : "Paused" }
        return active ? "Audio detected" : "No audio detected"
    }
    var coverQuery: MediaTrack? {
        guard available else { return nil }
        if let track, !track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return track }
        guard tabID != nil, let title = CoverTitle.clean(name) else { return nil }
        return MediaTrack(title: title, updatedAt: Date().timeIntervalSince1970, provider: "Browser title hint")
    }
    var artworkContext: String { [id, lifetime, coverQuery?.identity ?? ""].joined(separator: "|") }
    static func tabKey(_ session: String, _ tab: Int) -> String { "\(session):tab:\(tab)" }
}

enum CoverTitle {
    static func clean(_ value: String) -> String? {
        var title = String(value.prefix(512)).trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in [" | YouTube Music", " - YouTube Music", " | YouTube", " - YouTube", " | Spotify", " - Spotify", " — Apple Music", " - Apple Music"] {
            if let range = title.range(of: suffix, options: [.backwards, .anchored, .caseInsensitive]) { title.removeSubrange(range); break }
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !["youtube music", "youtube", "spotify", "apple music", "new tab", "untitled tab"].contains(MediaTrack.normalized(title)) else { return nil }
        return title
    }
}

enum ListeningSelection {
    static func resolve(_ sources: [ListeningSource], pin: String?, current: String?) -> String? {
        if let pin { return pin }
        let activeTabs = Set(sources.filter { $0.tabID != nil && $0.active && $0.available }.map(\.appID))
        let eligible = sources.filter { $0.available && ($0.tabID != nil || !activeTabs.contains($0.appID)) }
        if let current, eligible.contains(where: { $0.id == current && $0.active }) { return current }
        if let active = eligible.filter({ $0.active && $0.id != "__system__" }).sorted(by: {
            $0.becameActive == $1.becameActive ? $0.id < $1.id : $0.becameActive > $1.becameActive
        }).first { return active.id }
        return eligible.contains(where: { $0.id == current }) ? current : nil
    }
}

struct NativeMediaResult: Codable {
    var track: MediaTrack?
    var error: String?
}

enum MediaURL {
    static func allowed(_ value: String) -> URL? {
        guard value.count <= 4096, let url = URL(string: value), url.scheme == "https", url.user == nil, url.password == nil,
              let host = url.host?.lowercased(), host.contains("."), !host.hasSuffix(".local"), !host.hasSuffix(".localhost"),
              !host.contains(":"), host.split(separator: ".").contains(where: { Int($0) == nil }), url.port == nil || url.port == 443 else { return nil }
        return url
    }
}

struct AutomaticArtworkPolicy {
    private var attempts: [String: TimeInterval] = [:]
    func eligible(_ key: String, now: TimeInterval) -> Bool {
        guard let last = attempts[key] else { return true }
        return now >= last + 600
    }
    mutating func record(_ key: String, now: TimeInterval) {
        attempts = attempts.filter { now < $0.value + 600 }
        if attempts.count >= 256, let oldest = attempts.min(by: { $0.value < $1.value })?.key { attempts.removeValue(forKey: oldest) }
        attempts[key] = now
    }
}
