import Foundation
import ImageIO
import AppKit

final class ArtworkRedirects: NSObject, URLSessionTaskDelegate {
    let respectBackoff: Bool
    init(respectBackoff: Bool = false) { self.respectBackoff = respectBackoff }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url.flatMap({ ArtworkLoader.archiveURL($0.absoluteString) ?? MediaURL.allowed($0.absoluteString) }) else { completionHandler(nil); return }
        var next = request; next.url = url
        if respectBackoff {
            Task {
                let blocked = await ArtworkService.shared.isDeferred(url)
                completionHandler(blocked ? nil : next)
            }
        } else { completionHandler(next) }
    }
}

extension Optional where Wrapped == Data {
    func asyncImage() async -> NSImage? {
        guard let data = self else { return nil }
        return await ArtworkLoader.decode(data)
    }
}
enum ArtworkFetchError: LocalizedError {
    case http(Int)
    case unavailable(Int, TimeInterval?, host: String? = nil)
    case deferred(TimeInterval)
    var errorDescription: String? {
        switch self {
        case .http(let code): return "Artwork service returned HTTP \(code)"
        case .unavailable: return "The artwork service is temporarily unavailable. Try again shortly."
        case .deferred: return "The artwork service requested a pause. Another source can be tried while it recovers."
        }
    }
}

enum ArtworkRetry {
    static func retryAfter(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value else { return nil }
        if let seconds = Double(value), seconds.isFinite, seconds >= 0 { return seconds }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value).map { max(0, $0.timeIntervalSince(now)) }
    }
    static func run<T>(operation: () async throws -> T, sleep: (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) async throws -> T {
        do { return try await operation() }
        catch {
            try Task.checkCancellation()
            let delay: TimeInterval
            switch error {
            case ArtworkFetchError.unavailable(_, let wait, _): delay = max(2, wait ?? 2)
            case ArtworkFetchError.deferred(let wait): delay = max(0.05, wait)
            default: throw error
            }
            guard delay <= 5 else { throw error }
            try await sleep(delay)
            try Task.checkCancellation()
            return try await operation()
        }
    }
}

actor ArtworkService {
    static let shared = ArtworkService()
    private var deadlines: [String: Date] = [:]
    func isDeferred(_ url: URL) -> Bool { (deadlines[url.host ?? ""] ?? .distantPast) > Date() }
    func fetch(_ url: URL, limit: Int, budget: CoverDownloadBudget? = nil) async throws -> Data {
        try await ArtworkRetry.run { try await self.request(url, limit: limit, budget: budget) }
    }
    private func request(_ url: URL, limit: Int, budget: CoverDownloadBudget?) async throws -> Data {
        try Task.checkCancellation()
        let host = url.host ?? ""
        if let deadline = deadlines[host], deadline > Date() { throw ArtworkFetchError.deferred(deadline.timeIntervalSinceNow) }
        if let budget { try await budget.claim() }
        do { return try await ArtworkLoader.fetch(url, limit: limit, respectBackoff: true) }
        catch ArtworkFetchError.unavailable(let code, let delay, let responseHost) {
            deadlines = deadlines.filter { $0.value > Date() }
            let deadline = Date().addingTimeInterval(max(2, delay ?? 2))
            for affected in Set([host, responseHost ?? host]) {
                deadlines[affected] = max(deadlines[affected] ?? .distantPast, deadline)
            }
            throw ArtworkFetchError.unavailable(code, delay, host: responseHost)
        }
    }
}
enum ArtworkLoader {
    static func archiveURL(_ string: String) -> URL? {
        guard var parts = URLComponents(string: string), let host = parts.host?.lowercased(),
              host == "coverartarchive.org" || host == "archive.org" || host.hasSuffix(".archive.org") else { return nil }
        if parts.scheme == "http" { parts.scheme = "https" }
        return parts.url.flatMap { MediaURL.allowed($0.absoluteString) }
    }
    static func decode(_ data: Data) async -> NSImage? { await Task.detached(priority: .utility) { image(data) }.value }
    static func fetch(_ url: URL, limit: Int = 4_194_304, respectBackoff: Bool = false) async throws -> Data {
        guard MediaURL.allowed(url.absoluteString) != nil else { throw URLError(.unsupportedURL) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 15
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: ArtworkRedirects(respectBackoff: respectBackoff), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("OpenAudio/0.5.3 (macOS listening companion)", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if [429, 502, 503, 504].contains(http.statusCode) {
            throw ArtworkFetchError.unavailable(http.statusCode, ArtworkRetry.retryAfter(http.value(forHTTPHeaderField: "Retry-After")), host: http.url?.host)
        }
        guard (200...299).contains(http.statusCode) else { throw ArtworkFetchError.http(http.statusCode) }
        guard response.expectedContentLength <= limit else { throw URLError(.dataLengthExceedsMaximum) }
        var data = Data()
        for try await byte in bytes {
            if data.count >= limit { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        try Task.checkCancellation()
        return data
    }
    static func image(_ data: Data) -> NSImage? {
        guard data.count <= 4_194_304, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 8192, height <= 8192, width * height <= 32_000_000,
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1600, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: .zero)
    }
}

actor CoverDownloadBudget {
    private var remaining = 3
    func fetch(_ url: URL) async throws -> Data {
        try await ArtworkService.shared.fetch(url, limit: 2 * 1024 * 1024, budget: self)
    }
    func claim() throws {
        try Task.checkCancellation()
        guard remaining > 0 else { throw URLError(.dataLengthExceedsMaximum) }
        remaining -= 1
    }
}

enum CoverQuality {
    static let policy = 2
    static func dimensions(_ data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 8192, height <= 8192, width * height <= 32_000_000 else { return nil }
        return (width, height)
    }
    static func score(_ data: Data?) -> Int {
        guard let data, let size = dimensions(data) else { return 0 }
        return min(size.width, size.height)
    }
    static func prepareAsync(_ data: Data) async throws -> Data? {
        let result = await Task.detached(priority: .utility) { prepare(data) }.value
        try Task.checkCancellation()
        return result
    }
    static func prepare(_ data: Data) -> Data? {
        guard data.count <= 4_194_304, let size = dimensions(data),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: min(1200, max(size.width, size.height)),
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        for quality in [0.88, 0.78, 0.65, 0.5] {
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            if CGImageDestinationFinalize(destination), output.length <= 1_048_576 { return output as Data }
        }
        return nil
    }
    static func variants(_ front: CoverArchive.Image) -> [URL] {
        var seen = Set<URL>()
        return [front.thumbnails?["1200"], front.image, front.thumbnails?["large"], front.thumbnails?["500"]]
            .compactMap { $0.flatMap(ArtworkLoader.archiveURL) }.filter { seen.insert($0).inserted }.prefix(3).map { $0 }
    }
    static func select(_ urls: [URL], fetch: (URL) async throws -> Data) async throws -> Data? {
        var best: Data?
        var failure: Error?
        for url in urls.prefix(3) {
            try Task.checkCancellation()
            do {
                let bytes = try await fetch(url)
                try Task.checkCancellation()
                guard let prepared = prepare(bytes) else { throw URLError(.cannotDecodeContentData) }
                if score(prepared) > score(best) { best = prepared }
                if score(best) >= 800 { return best }
            } catch is CancellationError { throw CancellationError() }
            catch { try Task.checkCancellation(); failure = error }
        }
        if best == nil, let failure { throw failure }
        return best
    }
}
