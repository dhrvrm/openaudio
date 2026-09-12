import Foundation

struct CoverRecording: Decodable {
    struct Credit: Decodable { var name: String }
    struct Release: Decodable { var id: String; var title: String; var status: String? }
    var title: String
    var credits: [Credit]
    var releases: [Release]?
    enum CodingKeys: String, CodingKey { case title, credits = "artist-credit", releases }
}
struct CoverSearch: Decodable { var recordings: [CoverRecording] }
struct CoverArchive: Decodable {
    struct Image: Decodable { var front: Bool; var approved: Bool?; var image: String; var thumbnails: [String: String]? }
    var images: [Image]
}
struct CoverCacheEntry: Codable {
    var created: Double
    var image: Data?
    var attribution: String
    var suggested: Bool?
    var qualityPolicy: Int?
    func valid(at now: Double) -> Bool { now >= created && now - created < (image == nil ? 600 : 604800) }
}

enum CoverResolution {
    static func resolve(catalog: () async throws -> CoverCacheEntry, rendered: () async throws -> CoverCacheEntry) async throws -> CoverCacheEntry {
        do {
            let result = try await catalog()
            if result.image != nil { return result }
        } catch is CancellationError { throw CancellationError() }
        catch { try Task.checkCancellation() }
        try Task.checkCancellation()
        return try await rendered()
    }
}

enum CoverMatching {
    struct Suggestion {
        var release: String
        var artist: String
        var album: String
    }
    static func suggestions(_ search: CoverSearch, title: String, album: String = "") -> [Suggestion] {
        var found: [Suggestion] = []
        var seen = Set<String>()
        for recording in search.recordings where MediaTrack.normalized(recording.title) == MediaTrack.normalized(title) {
            let artist = recording.credits.map(\.name).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !artist.isEmpty else { continue }
            for release in recording.releases ?? [] where release.status == nil || release.status == "Official" {
                guard album.isEmpty || MediaTrack.normalized(release.title) == MediaTrack.normalized(album) else { continue }
                guard UUID(uuidString: release.id) != nil, !release.title.isEmpty, seen.insert(release.id).inserted else { continue }
                found.append(Suggestion(release: release.id, artist: artist, album: release.title))
                if found.count == 3 { return found }
            }
        }
        return found
    }
    static func releases(_ search: CoverSearch, track: MediaTrack) -> [String] {
        var matches: [CoverRecording.Release] = []
        for recording in search.recordings {
            let artist = recording.credits.map { $0.name }.joined(separator: " ")
            guard MediaTrack.normalized(recording.title) == MediaTrack.normalized(track.title),
                  MediaTrack.normalized(artist) == MediaTrack.normalized(track.artist) else { continue }
            for release in recording.releases ?? [] {
                guard release.status == nil || release.status == "Official", UUID(uuidString: release.id) != nil else { continue }
                if track.album.isEmpty || MediaTrack.normalized(release.title) == MediaTrack.normalized(track.album) { matches.append(release) }
            }
        }
        guard Set(matches.map { MediaTrack.normalized($0.title) }).count == 1 else { return [] }
        let ids = Array(Set(matches.map(\.id))).sorted()
        return ids.count == 1 ? ids : []
    }
}

actor CoverLookup {
    private let directory: URL
    private var nextRequest: Date = .distantPast
    private var generation = 0
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("OpenAudio/Covers")
    }
    func clear() throws { generation += 1; if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) } }
    func cached(_ track: MediaTrack) -> CoverCacheEntry? {
        let file = directory.appendingPathComponent(track.lookupKey + ".json")
        guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 6_000_000,
              let data = try? Data(contentsOf: file), let entry = try? JSONDecoder().decode(CoverCacheEntry.self, from: data),
              entry.valid(at: Date().timeIntervalSince1970), entry.image == nil || ArtworkLoader.image(entry.image!) != nil else {
            try? FileManager.default.removeItem(at: file)
            return nil
        }
        return entry
    }
    func find(_ track: MediaTrack, refresh: Bool = false, progress: @Sendable (String) async -> Void = { _ in }) async throws -> CoverCacheEntry {
        let requestGeneration = generation
        let key = directory.appendingPathComponent(track.lookupKey + ".json")
        let previous = cached(track)
        if !refresh, let previous, previous.qualityPolicy == CoverQuality.policy { return previous }
        let budget = CoverDownloadBudget()
        guard !track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw NSError(domain: "OpenAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "A song title is needed to find artwork."]) }
        await progress("Searching the music catalog…")
        var result: CoverCacheEntry
        do {
        result = try await CoverResolution.resolve(catalog: { try await self.catalog(track, budget: budget) }, rendered: {
            await progress("Catalog unavailable or no cover found · checking public music pages…")
            return try await HeadlessCover.find(track, budget: budget)
        })
        } catch is CancellationError { throw CancellationError() }
        catch {
            try Task.checkCancellation()
            if var previous, previous.image != nil {
                previous.attribution += " · Refresh failed; kept existing cover: " + error.localizedDescription
                return previous
            }
            throw error
        }
        try Task.checkCancellation()
        if var previous, CoverQuality.score(previous.image) > CoverQuality.score(result.image) {
            previous.attribution += " · No higher-quality cover found; kept existing cover"
            return previous
        }
        result.qualityPolicy = CoverQuality.policy
        if requestGeneration == generation {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(result).write(to: key, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: key.path)
            try evict()
        }
        return result
    }
    private func catalog(_ track: MediaTrack, budget: CoverDownloadBudget) async throws -> CoverCacheEntry {
        let slot = max(nextRequest, Date())
        nextRequest = slot.addingTimeInterval(1.1)
        let delay = slot.timeIntervalSinceNow
        if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        func escaped(_ value: String) -> String { String(value.prefix(512)).replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") }
        var searchURL = URLComponents(string: "https://musicbrainz.org/ws/2/recording/")!
        let query = "recording:\"\(escaped(track.title))\"" + (track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " AND artist:\"\(escaped(track.artist))\"")
        searchURL.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "fmt", value: "json"), URLQueryItem(name: "limit", value: "10")]
        let data = try await ArtworkService.shared.fetch(searchURL.url!, limit: 524288)
        let search = try JSONDecoder().decode(CoverSearch.self, from: data)
        if track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var failure: Error?
            for candidate in CoverMatching.suggestions(search, title: track.title, album: track.album) {
                try Task.checkCancellation()
                do {
                    if let image = try await frontCover(candidate.release, budget: budget) {
                        return CoverCacheEntry(created: Date().timeIntervalSince1970, image: image, attribution: "Suggested artwork · \(candidate.artist) — \(candidate.album) · MusicBrainz / Cover Art Archive", suggested: true)
                    }
                } catch is CancellationError { throw CancellationError() }
                catch { failure = error }
            }
            if let failure { throw failure }
            return CoverCacheEntry(created: Date().timeIntervalSince1970, attribution: "No cover found among the suggested releases. Try again later.", suggested: true)
        }
        let releases = CoverMatching.releases(search, track: track)
        var result = CoverCacheEntry(created: Date().timeIntervalSince1970, attribution: "No unambiguous cover match. Try adding the album name.")
        if let release = releases.first {
            if let bytes = try await frontCover(release, budget: budget) {
                result.image = bytes
                result.attribution = "Cover Art Archive · MusicBrainz match · \(track.artist) — \(track.title)"
            } else { result.attribution = "The matched release has no usable front cover." }
        }
        return result
    }
    private func frontCover(_ release: String, budget: CoverDownloadBudget) async throws -> Data? {
        let url = URL(string: "https://coverartarchive.org/release/\(release)/")!
        let data: Data
        do { data = try await ArtworkService.shared.fetch(url, limit: 524288) }
        catch ArtworkFetchError.http(404) { return nil }
        let archive = try JSONDecoder().decode(CoverArchive.self, from: data)
        guard let front = archive.images.first(where: { $0.front && $0.approved != false }) else { return nil }
        return try await CoverQuality.select(CoverQuality.variants(front), fetch: { try await budget.fetch($0) })
    }

    private func evict() throws {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
        let values = files.compactMap { url -> (URL, Int, Date)? in
            guard let value = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else { return nil }
            return (url, value.fileSize ?? 0, value.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var total = values.reduce(0) { $0 + $1.1 }
        for value in values where total > 32 * 1024 * 1024 { try FileManager.default.removeItem(at: value.0); total -= value.1 }
    }
}
