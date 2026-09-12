import Foundation
import ImageIO
import CoreGraphics

@main
struct ListeningChecks {
    static func main() async throws {
        var count = 0
        func check(_ value: Bool, _ message: String) { precondition(value, message); count += 1; print("PASS: \(message)") }
        var a = ListeningSource(id: "a", name: "A", appID: "a", active: true, becameActive: 1)
        var b = ListeningSource(id: "b", name: "B", appID: "b", active: true, becameActive: 2)
        check(ListeningSelection.resolve([a, b], pin: nil, current: nil) == "b", "automatic selects most recently active source")
        check(ListeningSelection.resolve([a, b], pin: nil, current: "a") == "a", "automatic keeps a playing source")
        check(ListeningSelection.resolve([b], pin: "a", current: "a") == "a", "missing pin cannot transfer to another source")
        a.active = false; b.active = false
        check(ListeningSelection.resolve([a, b], pin: nil, current: "a") == "a", "pause retains current idle source")
        check(ListeningSelection.resolve([a, b], pin: nil, current: nil) == nil, "no active source leaves automatic scene empty")
        a.active = true; b.active = true; a.becameActive = 2
        check(ListeningSelection.resolve([b, a], pin: nil, current: nil) == "a", "simultaneous activity has stable ordering")
        var tab = ListeningSource(id: "tab", name: "Tab", appID: "a", tabID: 7, active: true)
        check(ListeningSelection.resolve([a, tab], pin: nil, current: "a") == "tab", "tab supersedes duplicate aggregate in automatic mode")
        tab.available = false
        check(ListeningSelection.resolve([a, tab], pin: nil, current: nil) == "a", "lost browser connection is not active focus")
        var track = MediaTrack(title: "Song", artist: "Artist", album: "Album", updatedAt: 100)
        check(track.fresh(at: 107) && !track.fresh(at: 109) && !track.fresh(at: 90), "freshness rejects stale and future metadata")
        let originalIdentity = track.identity
        track.artworkRevision = "new-image"
        check(track.identity != originalIdentity, "new embedded artwork invalidates the presentation generation")
        let key = track.lookupKey
        track.title = "  SONG  "
        check(track.lookupKey == key, "cache keys normalize title and artist")
        track.album = "Another album"
        check(track.lookupKey != key, "different albums cannot share a cover cache key")
        check(CoverCacheEntry(created: 100, image: Data([1]), attribution: "source").valid(at: 604899), "positive cover cache lasts seven days")
        check(!CoverCacheEntry(created: 100, image: Data([1]), attribution: "source").valid(at: 604900), "positive cover expires at TTL")
        check(!CoverCacheEntry(created: 100, attribution: "miss").valid(at: 700), "negative cache expires in ten minutes")
        check(!CoverCacheEntry(created: 100, attribution: "miss").valid(at: 99), "clock reversal invalidates cache")
        let releaseA = CoverRecording.Release(id: "00000000-0000-0000-0000-000000000001", title: "Album", status: "Official")
        let releaseB = CoverRecording.Release(id: "00000000-0000-0000-0000-000000000002", title: "Other", status: "Official")
        let search = CoverSearch(recordings: [CoverRecording(title: "Song", credits: [.init(name: "Artist")], releases: [releaseA, releaseB])])
        track = MediaTrack(title: "Song", artist: "Artist", album: "Album", updatedAt: 100)
        check(CoverMatching.releases(search, track: track) == [releaseA.id], "cover match corroborates exact album")
        let edition = CoverRecording.Release(id: releaseB.id, title: "Album", status: "Official")
        let editions = CoverSearch(recordings: [CoverRecording(title: "Song", credits: [.init(name: "Artist")], releases: [releaseA, edition])])
        check(CoverMatching.releases(editions, track: track).isEmpty, "multiple editions are not chosen arbitrarily")
        track.album = ""
        check(CoverMatching.releases(search, track: track).isEmpty, "ambiguous releases do not guess a cover")
        track.artist = "Someone else"
        check(CoverMatching.releases(search, track: track).isEmpty, "title-only matches cannot select another artist")
        for url in ["file:///tmp/a", "http://example.com/a", "https://127.0.0.1/a", "https://localhost/a", "https://user:pass@example.com/a", "https://example.com:9999/a"] {
            check(MediaURL.allowed(url) == nil, "unsafe artwork reference rejected: \(url)")
        }
        check(MediaURL.allowed("https://coverartarchive.org/release/test/front-1200") != nil, "public HTTPS artwork is allowed")
        check(ArtworkLoader.image(Data("not an image".utf8)) == nil, "malformed image does not reach presentation")
        check(ArtworkLoader.archiveURL("http://coverartarchive.org/release/test/cover-1200.jpg")?.scheme == "https", "archive references upgrade to HTTPS")
        check(ArtworkLoader.archiveURL("http://example.com/cover.jpg") == nil, "unrelated HTTP hosts cannot use archive upgrade")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CoverCacheChecks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = CoverLookup(directory: folder)
        let file = folder.appendingPathComponent(track.lookupKey + ".json")
        let bad = CoverCacheEntry(created: Date().timeIntervalSince1970, image: Data("corrupt image".utf8), attribution: "bad")
        try JSONEncoder().encode(bad).write(to: file)
        let corruptHit = await cache.cached(track)
        check(corruptHit == nil && !FileManager.default.fileExists(atPath: file.path), "corrupt image cache is discarded without network")
        let miss = CoverCacheEntry(created: Date().timeIntervalSince1970, attribution: "No match")
        try JSONEncoder().encode(miss).write(to: file)
        let cachedMiss = await cache.cached(track)
        check(cachedMiss?.attribution == "No match", "valid negative lookup is reused without network")
        try await cache.clear()
        check(!FileManager.default.fileExists(atPath: folder.path), "clear removes the cover cache")
        var motion = RecordMotion()
        motion.configure(rpm: 6, playing: true, reduced: false, at: 0)
        check(abs(motion.value(at: 20) - motion.value(at: 10) - 360) < 0.01, "steady calm speed completes one turn in ten seconds")
        let phase = motion.value(at: 12).truncatingRemainder(dividingBy: 360)
        let speed = motion.velocity(at: 12)
        motion.configure(rpm: 45, playing: true, reduced: false, at: 12)
        check(abs(motion.value(at: 12) - phase) < 0.001 && abs(motion.velocity(at: 12) - speed) < 0.001, "speed change preserves phase and velocity")
        motion.configure(rpm: 45, playing: false, reduced: false, at: 14)
        check(motion.velocity(at: 15) > 0 && motion.velocity(at: 25) < 0.02, "pause decelerates to rest without reversing")
        motion.configure(rpm: 6, playing: true, reduced: true, at: 26)
        check(motion.value(at: 26) == motion.value(at: 100) && !motion.moving(at: 100), "Reduce Motion freezes the existing phase")
        motion.configure(rpm: .nan, playing: true, reduced: false, at: 101)
        check(motion.target == 36 && motion.value(at: 102).isFinite, "invalid speed safely falls back to calm")
        track = MediaTrack(title: "Song", artist: "Artist", album: "Album", updatedAt: 100)
        let snapshot = CoverPageSnapshot(items: [.init(title: "Song", artist: "Artist", album: "Album", images: ["https://example.com/cover.jpg"])], links: [])
        check(HeadlessCoverPolicy.image(snapshot, track: track) != nil, "rendered cover requires corroborated track identity")
        var mismatch = track; mismatch.artist = "Other artist"
        check(HeadlessCoverPolicy.image(snapshot, track: mismatch) == nil, "rendered title-only match is rejected")
        for url in ["https://evil.example/track/a", "https://open.spotify.com/login", "https://music.apple.com/account", "file:///tmp/page"] {
            check(HeadlessCoverPolicy.page(url) == nil, "headless navigation rejects unrelated or private page")
        }
        let hit = CoverCacheEntry(created: 1, image: Data([1]), attribution: "catalog")
        var renderedCalls = 0
        let resolved = try await CoverResolution.resolve(catalog: { hit }, rendered: { renderedCalls += 1; return miss })
        check(resolved.attribution == "catalog" && renderedCalls == 0, "catalog hit never starts the headless fallback")
        _ = try await CoverResolution.resolve(catalog: { miss }, rendered: { renderedCalls += 1; return hit })
        check(renderedCalls == 1, "catalog miss continues to rendered lookup")
        _ = try await CoverResolution.resolve(catalog: { throw URLError(.timedOut) }, rendered: { renderedCalls += 1; return hit })
        check(renderedCalls == 2, "catalog service error continues to rendered lookup")
        do {
            _ = try await CoverResolution.resolve(catalog: { throw CancellationError() }, rendered: { renderedCalls += 1; return hit })
            preconditionFailure("Cancellation was swallowed")
        } catch is CancellationError { check(renderedCalls == 2, "canceled catalog never starts another provider") }
        check(CoverTitle.clean("Hit the Road Jack | YouTube Music") == "Hit the Road Jack", "known browser suffix becomes a title-only artwork hint")
        check(CoverTitle.clean("Song - Live | YouTube Music") == "Song - Live", "title cleanup preserves meaningful song text")
        check(CoverTitle.clean("YouTube Music") == nil && CoverTitle.clean("New tab") == nil, "generic browser pages cannot trigger title suggestions")
        var hinted = ListeningSource(id: "hint", name: "Hit the Road Jack | YouTube Music", appID: "browser", tabID: 9, active: true, lifetime: "doc")
        check(hinted.coverQuery?.title == "Hit the Road Jack" && hinted.coverQuery?.artist == "" && hinted.track == nil, "search hint never becomes observed track metadata")
        let oldContext = hinted.artworkContext
        hinted.name = "Another song | YouTube Music"
        check(hinted.artworkContext != oldContext, "same-tab song title change invalidates suggested artwork")
        check(hinted.visualPlaying && hinted.visualPlaybackLabel == "Audio detected", "observed audio engages needle without claiming track metadata")
        hinted.track = MediaTrack(title: "Song", playing: false, updatedAt: Date().timeIntervalSince1970)
        check(!hinted.visualPlaying && hinted.visualPlaybackLabel == "Paused", "observed pause outranks an audible flag")
        hinted.available = false
        check(!hinted.visualPlaying && hinted.coverQuery == nil, "unavailable source cannot engage needle or start a suggestion")
        let suggestionSearch = CoverSearch(recordings: [
            CoverRecording(title: "Other song", credits: [.init(name: "Other")], releases: [releaseA]),
            CoverRecording(title: "Song", credits: [.init(name: "Candidate artist")], releases: [releaseA, releaseB, releaseA])
        ])
        let suggestions = CoverMatching.suggestions(suggestionSearch, title: "Song")
        check(suggestions.count == 2 && suggestions[0].artist == "Candidate artist" && suggestions[0].album == "Album", "title suggestions retain ranked candidate provenance and deduplicate releases")
        let manyReleases = (1...10).map { CoverRecording.Release(id: String(format: "00000000-0000-0000-0000-%012d", $0), title: "Album", status: "Official") }
        check(CoverMatching.suggestions(CoverSearch(recordings: [CoverRecording(title: "Song", credits: [.init(name: "Artist")], releases: manyReleases)]), title: "Song").count == 3, "suggested release attempts are capped at three")
        let suggestedQuery = MediaTrack(title: "Song", updatedAt: 100)
        let verifiedQuery = MediaTrack(title: "Song", artist: "Artist", updatedAt: 100)
        check(suggestedQuery.lookupKey != verifiedQuery.lookupKey, "suggested and verified artwork have separate cache identities")
        let suggestionEntry = CoverCacheEntry(created: 100, attribution: "Suggested artwork · Artist — Album", suggested: true)
        check(try JSONDecoder().decode(CoverCacheEntry.self, from: JSONEncoder().encode(suggestionEntry)).suggested == true, "cache round trip preserves suggested provenance")
        func bitmap(_ width: Int, _ height: Int) -> Data {
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            context.setFillColor(CGColor(red: 0.5, green: 0.2, blue: 0.1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let data = NSMutableData()
            let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, context.makeImage()!, nil)
            precondition(CGImageDestinationFinalize(destination))
            return data as Data
        }
        let small = bitmap(300, 292)
        let large = bitmap(2000, 2000)
        let prepared = CoverQuality.prepare(large)!
        check(CoverQuality.score(prepared) == 1200 && prepared.count <= 1_048_576, "large covers become bounded 1200px cached images")
        check(CoverQuality.score(CoverQuality.prepare(small)) == 292, "small covers are never upscaled")
        let variantURLs = ["https://archive.org/1200.jpg", "https://archive.org/original.jpg", "https://archive.org/500.jpg"].map { URL(string: $0)! }
        var qualityCalls = 0
        let upgraded = try await CoverQuality.select(variantURLs) { _ in
            qualityCalls += 1
            return qualityCalls == 1 ? small : large
        }
        check(CoverQuality.score(upgraded) == 1200 && qualityCalls == 2, "measured pixels override misleading thumbnail names and stop at sufficient quality")
        qualityCalls = 0
        let fallback = try await CoverQuality.select(variantURLs) { _ in
            qualityCalls += 1
            if qualityCalls > 1 { throw URLError(.dataLengthExceedsMaximum) }
            return small
        }
        check(CoverQuality.score(fallback) == 292 && qualityCalls == 3, "oversized alternatives retain the best smaller cover")
        let front = CoverArchive.Image(front: true, image: variantURLs[1].absoluteString, thumbnails: ["1200": variantURLs[0].absoluteString, "large": variantURLs[0].absoluteString, "500": variantURLs[2].absoluteString])
        check(CoverQuality.variants(front) == variantURLs, "published variants preserve priority and remove duplicates")
        do {
            _ = try await CoverQuality.select(variantURLs) { _ in throw CancellationError() }
            preconditionFailure("Quality lookup swallowed cancellation")
        } catch is CancellationError { check(true, "quality fallback preserves cancellation") }
        check(CoverQuality.prepare(Data("bad".utf8)) == nil, "invalid cover bytes cannot enter prepared cache")
        var attempts = 0
        var waits: [TimeInterval] = []
        let recovered = try await ArtworkRetry.run(operation: {
            attempts += 1
            if attempts == 1 { throw ArtworkFetchError.unavailable(503, nil) }
            return "cover"
        }, sleep: { waits.append($0) })
        check(recovered == "cover" && attempts == 2 && waits == [2], "503 retries once after a delay and recovers")
        attempts = 0
        do {
            _ = try await ArtworkRetry.run(operation: { () -> String in
                attempts += 1
                throw ArtworkFetchError.unavailable(503, nil)
            }, sleep: { _ in })
            preconditionFailure("Persistent outage was swallowed")
        } catch { check(attempts == 2, "persistent outages cannot loop retries") }
        attempts = 0; waits = []
        do {
            _ = try await ArtworkRetry.run(operation: { () -> String in
                attempts += 1
                throw ArtworkFetchError.unavailable(429, 60)
            }, sleep: { waits.append($0) })
            preconditionFailure("Long Retry-After was ignored")
        } catch { check(attempts == 1 && waits.isEmpty, "long Retry-After defers without early retry") }
        check(ArtworkRetry.retryAfter("17") == 17, "Retry-After seconds are parsed")
        check(ArtworkRetry.retryAfter("Thu, 01 Jan 1970 00:01:00 GMT", now: Date(timeIntervalSince1970: 0)) == 60, "Retry-After HTTP dates are parsed")
        check(ArtworkRetry.retryAfter("garbage") == nil, "invalid Retry-After falls back to bounded delay")
        attempts = 0
        do {
            _ = try await ArtworkRetry.run(operation: { () -> String in
                attempts += 1
                throw ArtworkFetchError.unavailable(503, nil)
            }, sleep: { _ in throw CancellationError() })
            preconditionFailure("Canceled retry continued")
        } catch is CancellationError { check(attempts == 1, "canceling retry wait stops the second request") }
        let budget = CoverDownloadBudget()
        try await budget.claim(); try await budget.claim(); try await budget.claim()
        do { try await budget.claim(); preconditionFailure("Image budget exceeded") }
        catch { check(true, "shared image budget counts retry and fallback attempts") }
        var auto = AutomaticArtworkPolicy()
        check(auto.eligible("song", now: 100), "new track is eligible for automatic lookup")
        auto.record("song", now: 100)
        check(!auto.eligible("song", now: 699) && auto.eligible("song", now: 700), "same-track automatic attempts have a ten-minute cooldown")
        check(auto.eligible("other song", now: 101), "a different song can fetch during the previous song cooldown")
        let publicCandidate = CoverPageSnapshot(items: [.init(title: "Song", artist: "Candidate Artist", album: "Candidate Album", images: ["https://example.com/cover.jpg"])], links: [])
        let hintedTrack = MediaTrack(title: "Song", updatedAt: 100)
        check(HeadlessCoverPolicy.suggestion(publicCandidate, track: hintedTrack)?.artist == "Candidate Artist", "title-only public-page fallback preserves candidate attribution")
        check(HeadlessCoverPolicy.suggestion(publicCandidate, track: MediaTrack(title: "Wrong", updatedAt: 100)) == nil, "public-page suggestions require an exact title")
        check(HeadlessCoverPolicy.suggestion(publicCandidate, track: MediaTrack(title: "Song", artist: "Different", updatedAt: 100)) == nil, "suggestions cannot override an observed artist")
        let incompletePage = CoverPageSnapshot(items: [.init(title: "Song", artist: "", album: "", images: ["https://example.com/cover.jpg"])], links: [])
        check(HeadlessCoverPolicy.suggestion(incompletePage, track: hintedTrack) == nil && HeadlessCoverPolicy.image(incompletePage, track: hintedTrack) == nil, "missing artist and album cannot be presented as identified artwork")
        let wrongAlbum = CoverRecording.Release(id: "00000000-0000-0000-0000-000000000001", title: "Wrong album", status: "Official")
        let rightAlbum = CoverRecording.Release(id: "00000000-0000-0000-0000-000000000002", title: "Known album", status: "Official")
        let albumSearch = CoverSearch(recordings: [.init(title: "Song", credits: [.init(name: "Artist")], releases: [wrongAlbum, rightAlbum])])
        check(CoverMatching.suggestions(albumSearch, title: "Song", album: "Known album").map(\.release) == [rightAlbum.id], "known album constrains structured title-only suggestions")
        print("\(count) listening checks passed")
    }
}
