import AppKit
import Combine

@MainActor
final class ListeningController: ObservableObject {
    @Published var automaticArtwork = UserDefaults.standard.object(forKey: "vinyl.automaticArtwork") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(automaticArtwork, forKey: "vinyl.automaticArtwork")
            autoTask?.cancel(); autoTask = nil
            if !automaticArtwork && automaticRequest {
                coverTask?.cancel(); coverRequest = UUID(); findingCover = false; automaticRequest = false
                artworkStatus = artwork == nil ? "Automatic artwork is off · use Find cover" : artworkStatus
            }
            if automaticArtwork { scheduleArtwork() }
        }
    }
    @Published private(set) var sources: [ListeningSource] = []
    @Published private(set) var selectedID: String?
    @Published private(set) var pin: String?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var sourceArtworkLoading = false
    @Published private(set) var hasSourceArtwork = false
    @Published private(set) var artworkSuggested = false
    @Published private(set) var artworkStatus = ""
    @Published private(set) var providerStatus: [String: String] = [:]
    @Published private(set) var enabledProviders = Set<String>()
    @Published private(set) var pendingAction = false
    @Published private(set) var actionStatus = ""
    @Published private(set) var findingCover = false
    var browserCommand: ((ListeningSource, String) async -> String?)?
    var visibilityChanged: ((Bool) -> Void)?
    private var candidates: [ListeningSource] = []
    private var trackLifetimes: [String: String] = [:]
    private var tracks: [String: MediaTrack] = [:]
    private var blocked = Set<String>()
    private var nativeJobs: [String: Task<Void, Never>] = [:]
    private var revisions: [String: Int] = [:]
    private var autoTask: Task<Void, Never>?
    private var autoPolicy = AutomaticArtworkPolicy()
    private var automaticRequest = false
    private var artworkLoading = false
    private var artTask: Task<Void, Never>?
    private var coverTask: Task<Void, Never>?
    private var actionTask: Task<Void, Never>?
    private var artworkKey = ""
    private var coverRequest = UUID()
    private var visible = 0
    private var timer: Timer?
    private let lookup = CoverLookup()
    private var pinnedFallback: ListeningSource?
    private let observationEnabled: Bool
    init(observationEnabled: Bool = true) {
        self.observationEnabled = observationEnabled
        enabledProviders = Set(UserDefaults.standard.stringArray(forKey: "vinyl.providers") ?? []) }
    var selected: ListeningSource? {
        if let source = sources.first(where: { $0.id == selectedID }), !(source.id.hasPrefix("process:") && source.id == pin && source.lifetime != pinnedFallback?.lifetime) { return source }
        guard pin == selectedID, var fallback = pinnedFallback else { return nil }
        fallback.available = false; fallback.active = false; fallback.track = nil
        fallback.status = "Source unavailable · waiting for this source"
        return fallback
    }
    var coverQuery: MediaTrack? { selected?.coverQuery }
    var canFindCover: Bool { coverQuery != nil && !hasSourceArtwork && !sourceArtworkLoading }
    var canControl: Bool { selected.map { $0.tabID == nil && $0.available && enabledProviders.contains($0.appID) && $0.track != nil && !blocked.contains($0.appID) } ?? false }
    func supports(_ operation: String) -> Bool {
        guard ["playpause", "next", "previous"].contains(operation), let source = selected, source.available else { return false }
        if source.tabID != nil { return !source.lifetime.isEmpty && source.track?.fresh(at: Date().timeIntervalSince1970) == true && source.track?.commands?.contains(operation) == true }
        return canControl
    }
    func update(_ input: [ListeningSource]) {
        let old = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        let now = Date().timeIntervalSince1970
        candidates = input.map { value in
            var value = value
            if let prior = old[value.id], prior.lifetime == value.lifetime {
                value.becameActive = value.active && !prior.active ? now : prior.becameActive
            }
            return value
        }
        rebuild()
    }
    func choose(_ source: ListeningSource) {
        pin = source.id; pinnedFallback = source; selectedID = source.id; actionStatus = ""
        rebuild()
    }
    func automatic() { pin = nil; pinnedFallback = nil; rebuild() }
    func appear() {
        guard observationEnabled else { return }
        visible += 1
        guard visible == 1 else { return }
        visibilityChanged?(true)
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in Task { @MainActor in self?.poll() } }
        poll(); rebuild()
    }
    func shutdown() { visible = 1; disappear() }
    func disappear() {
        visible = max(0, visible - 1)
        guard visible == 0 else { return }
        visibilityChanged?(false)
        timer?.invalidate(); timer = nil
        for (id, job) in nativeJobs { revisions[id, default: 0] += 1; job.cancel() }
        actionTask?.cancel(); pendingAction = false
        nativeJobs.removeAll(); autoTask?.cancel(); autoTask = nil; artworkLoading = false; artTask?.cancel(); coverTask?.cancel(); findingCover = false; sourceArtworkLoading = false; coverRequest = UUID(); artworkKey = ""
    }
    func connect(_ id: String) {
        guard NativeMediaProbe.providers.contains(where: { $0.id == id }) else { return }
        enabledProviders.insert(id); blocked.remove(id)
        UserDefaults.standard.set(Array(enabledProviders), forKey: "vinyl.providers")
        readNative(id, authorization: true)
    }
    func disconnect(_ id: String) {
        enabledProviders.remove(id); tracks.removeValue(forKey: id); providerStatus[id] = "Not connected"
        if selected?.appID == id { actionTask?.cancel(); pendingAction = false }
        revisions[id, default: 0] += 1; nativeJobs.removeValue(forKey: id)?.cancel()
        UserDefaults.standard.set(Array(enabledProviders), forKey: "vinyl.providers")
        rebuild()
    }
    private func poll() {
        guard visible > 0 else { return }
        for id in enabledProviders where !blocked.contains(id) { readNative(id) }
        rebuild()
    }
    private func readNative(_ id: String, authorization: Bool = false) {
        guard visible > 0, enabledProviders.contains(id), nativeJobs[id] == nil else { return }
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: id).first else {
            tracks.removeValue(forKey: id); providerStatus[id] = "Open the music app to connect"; rebuild(); return
        }
        let lifetime = NativeMediaProbe.lifetime(running)
        let revision = revisions[id, default: 0]
        providerStatus[id] = authorization ? "Waiting for Automation access…" : providerStatus[id] ?? "Reading track…"
        nativeJobs[id] = Task { [weak self] in
            let result = await NativeMediaProbe.run(appID: id, authorization: authorization, expectedLifetime: lifetime)
            guard let self, !Task.isCancelled, self.enabledProviders.contains(id), self.revisions[id, default: 0] == revision else { return }
            self.nativeJobs[id] = nil
            guard NSRunningApplication.runningApplications(withBundleIdentifier: id).first.map(NativeMediaProbe.lifetime) == lifetime else { self.tracks[id] = nil; self.rebuild(); return }
            self.trackLifetimes[id] = lifetime
            self.tracks[id] = result.track
            self.providerStatus[id] = result.error ?? (result.track == nil ? "No current track" : "Connected")
            if result.error != nil { self.blocked.insert(id) }
            self.rebuild()
        }
    }
    private func rebuild() {
        let now = Date().timeIntervalSince1970
        sources = candidates.map { source in
            var source = source
            if source.tabID == nil, enabledProviders.contains(source.appID) {
                source.track = trackLifetimes[source.appID] == source.lifetime ? tracks[source.appID] : nil
                source.status = providerStatus[source.appID] ?? "Connecting…"
            }
            if let track = source.track, !track.fresh(at: now) { source.track = nil; source.status = "Track information is stale · waiting for an update" }
            if let playing = source.track?.playing { source.active = playing }
            return source
        }
        selectedID = ListeningSelection.resolve(sources, pin: pin, current: selectedID)
        loadArtwork()
        scheduleArtwork()
    }
    private func loadArtwork() {
        guard visible > 0 else { return }
        let key = selected?.artworkContext ?? ""
        guard key != artworkKey else { return }
        artworkKey = key; autoTask?.cancel(); autoTask = nil; artworkLoading = false; artTask?.cancel(); coverTask?.cancel(); findingCover = false; coverRequest = UUID()
        artwork = nil; artworkStatus = ""; artworkSuggested = false; hasSourceArtwork = false; sourceArtworkLoading = false
        guard let track = coverQuery else { return }
        artworkLoading = true
        artworkStatus = "Loading cover…"
        sourceArtworkLoading = track.artworkData != nil || track.artworkURL != nil
        artTask = Task { [weak self] in
            guard let self else { return }
            var image: NSImage?
            var status = "No cover supplied by this source"
            var suggested = false
            if let data = track.artworkData { image = await ArtworkLoader.decode(data) }
            if image == nil, let url = track.artworkURL.flatMap(MediaURL.allowed) {
                do { image = await ArtworkLoader.decode(try await ArtworkLoader.fetch(url)) }
                catch { status = "Source cover unavailable · try Find cover" }
            }
            let fromSource = image != nil
            if image != nil { status = "Artwork from \(track.provider)" }
            if image == nil, let cached = await self.lookup.cached(track) {
                image = await cached.image.asyncImage()
                status = cached.attribution
                suggested = cached.suggested == true
            }
            guard !Task.isCancelled, self.artworkKey == key else { return }
            self.artwork = image; self.artworkStatus = status; self.artworkSuggested = suggested && image != nil
            self.hasSourceArtwork = fromSource; self.sourceArtworkLoading = false; self.artworkLoading = false
            self.scheduleArtwork()
        }
    }
    private func scheduleArtwork() {
        guard observationEnabled, visible > 0, automaticArtwork, autoTask == nil,
              !artworkLoading, !findingCover, artwork == nil, canFindCover, let track = coverQuery,
              autoPolicy.eligible(track.lookupKey, now: Date().timeIntervalSince1970) else { return }
        let key = artworkKey
        autoTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(800)) } catch { return }
            guard let self, !Task.isCancelled, self.visible > 0, self.automaticArtwork,
                  self.artworkKey == key, self.artwork == nil, !self.artworkLoading else { return }
            self.autoTask = nil
            self.findCover(automatic: true)
        }
    }
    func findCover(refresh: Bool = false, automatic: Bool = false) {
        guard !findingCover, canFindCover, let track = coverQuery else { return }
        autoTask?.cancel(); autoTask = nil
        automaticRequest = automatic
        autoPolicy.record(track.lookupKey, now: Date().timeIntervalSince1970)
        artworkLoading = false
        let key = artworkKey
        let request = UUID(); coverRequest = request
        artTask?.cancel(); findingCover = true; artworkStatus = "Looking up this track…"
        coverTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.lookup.find(track, refresh: refresh) { [weak self] status in
                    await self?.coverProgress(status, key: key, request: request)
                }
                guard !Task.isCancelled, self.artworkKey == key, self.coverRequest == request else { return }
                let image = await result.image.asyncImage()
                guard !Task.isCancelled, self.artworkKey == key, self.coverRequest == request else { return }
                self.artwork = image
                self.artworkSuggested = result.suggested == true && image != nil
                self.artworkStatus = result.attribution
            } catch {
                guard !Task.isCancelled, self.artworkKey == key, self.coverRequest == request else { return }
                self.artworkStatus = "Cover lookup failed: \(error.localizedDescription)"
            }
            self.findingCover = false
        }
    }
    private func coverProgress(_ status: String, key: String, request: UUID) {
        if !Task.isCancelled && findingCover && coverRequest == request && artworkKey == key { artworkStatus = status }
    }
    func clearCovers() {
        autoTask?.cancel(); autoTask = nil
        if let track = coverQuery { autoPolicy.record(track.lookupKey, now: Date().timeIntervalSince1970) }
        coverTask?.cancel(); findingCover = false; coverRequest = UUID()
        Task {
            do { try await lookup.clear(); artworkKey = ""; rebuild() }
            catch { artworkStatus = "Could not clear saved covers: \(error.localizedDescription)" }
        }
    }
    func command(_ operation: String) {
        guard supports(operation), !pendingAction, let source = selected else { return }
        if source.tabID != nil {
            guard let browserCommand else { return }
            pendingAction = true; actionStatus = "Sending to the player…"
            actionTask = Task { [weak self] in
                let error = await browserCommand(source, operation)
                guard let self, !Task.isCancelled else { return }
                self.pendingAction = false
                if self.selectedID == source.id, self.selected?.lifetime == source.lifetime { self.actionStatus = error ?? "Sent to the player" }
            }
            return
        }
        let id = source.appID
        let lifetime = source.lifetime
        guard NSRunningApplication.runningApplications(withBundleIdentifier: id).first.map(NativeMediaProbe.lifetime) == lifetime else { actionStatus = "The source changed. Wait for current track details."; return }
        pendingAction = true; actionStatus = "Sending to \(source.name)…"
        actionTask = Task { [weak self] in
            guard NSRunningApplication.runningApplications(withBundleIdentifier: id).first.map(NativeMediaProbe.lifetime) == lifetime else { self?.pendingAction = false; return }
            let result = await NativeMediaProbe.run(appID: id, operation: operation == "next" ? "next track" : operation == "previous" ? "previous track" : operation, expectedLifetime: lifetime)
            guard let self, !Task.isCancelled else { return }
            self.pendingAction = false
            if self.selectedID == source.id { self.actionStatus = result.error ?? "Sent to the player" }
            self.readNative(id)
        }
    }
}
