import Foundation

struct CoverPageSnapshot: Decodable {
    struct Item: Decodable {
        var title: String
        var artist: String
        var album: String
        var images: [String]
    }
    var items: [Item]
    var links: [String]
}

enum HeadlessCoverPolicy {
    static func page(_ value: String) -> URL? {
        guard let url = MediaURL.allowed(value), let host = url.host else { return nil }
        let components = url.pathComponents
        if host == "open.spotify.com", components.count == 3, components[1] == "track", components[2].count == 22,
           components[2].allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) { return url }
        if host == "music.apple.com", components.count >= 4, components.contains("song") || components.contains("album") { return url }
        return nil
    }
    static func navigation(_ url: URL) -> Bool {
        page(url.absoluteString) != nil || (MediaURL.allowed(url.absoluteString) != nil && url.host == "www.google.com" && url.path == "/search")
    }
    static func image(_ snapshot: CoverPageSnapshot, track: MediaTrack) -> URL? {
        guard !MediaTrack.normalized(track.artist).isEmpty else { return nil }
        let matches = snapshot.items.filter {
            MediaTrack.normalized($0.title) == MediaTrack.normalized(track.title) && MediaTrack.normalized($0.artist) == MediaTrack.normalized(track.artist) &&
            (track.album.isEmpty || MediaTrack.normalized($0.album) == MediaTrack.normalized(track.album))
        }
        guard !matches.isEmpty, Set(matches.map { MediaTrack.normalized($0.album) }).count == 1 else { return nil }
        let images = Set(matches.compactMap { $0.images.compactMap(MediaURL.allowed).first })
        return images.count == 1 ? images.first : nil
    }
    static func suggestion(_ snapshot: CoverPageSnapshot, track: MediaTrack) -> CoverPageSnapshot.Item? {
        guard track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return snapshot.items.first {
            MediaTrack.normalized($0.title) == MediaTrack.normalized(track.title) &&
            !MediaTrack.normalized($0.artist).isEmpty && !MediaTrack.normalized($0.album).isEmpty &&
            (track.album.isEmpty || MediaTrack.normalized($0.album) == MediaTrack.normalized(track.album)) &&
            $0.images.contains { MediaURL.allowed($0) != nil }
        }
    }
    static func search(_ track: MediaTrack) -> URL {
        var value = URLComponents(string: "https://www.google.com/search")!
        let artist = track.artist.isEmpty ? "" : "\"\(track.artist.prefix(256))\""
        value.queryItems = [URLQueryItem(name: "q", value: "\"\(track.title.prefix(256))\" \(artist) \(track.album.prefix(256)) (site:music.apple.com OR site:open.spotify.com/track)")]
        return value.url!
    }
}
