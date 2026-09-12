import AppKit
import SwiftUI
import AudioToolbox
import CoreAudio
import ServiceManagement

@MainActor
final class AudioController: ObservableObject {
    @Published var devices: [AudioDevice] = []
    @Published var sources: [AudioSource] = []
    @Published var preferences = Preferences()
    @Published var observations: [String: RouteObservation] = [:]
    @Published var enabled = false
    @Published var errorMessage: String?
    @Published var selectedID: String? = systemRouteID
    @Published var defaultOutput: AudioObjectID = 0
    @Published var defaultInput: AudioObjectID = 0
    @Published var defaultEffects: AudioObjectID = 0
    @Published var undoAvailable = false
    @Published var browserSessions: [BrowserSnapshot] = []
    @Published var browserSetupError: String?
    @Published var browserRequestedAt: Date?
    @Published var localExtensionURL: URL?
    let browserBridge = BrowserBridge()
    let listening: ListeningController
    private let browserMonitoring: Bool
    private var lastOutputActivity: [String: Date] = [:]
    var recentSourceIDs: Set<String> { Set(lastOutputActivity.keys) }
    private var previous: Preferences?
    private var sessions: [String: RouteSession] = [:]
    private var globalMembership: [AudioObjectID] = []
    private var failures: [String: String] = [:]
    private var timer: Timer?
    private var browserTimer: Timer?
    private var notifications: [NSObjectProtocol] = []
    private var sleeping = false
    private var saveTask: Task<Void, Never>?
    private let fileURL: URL
    let effects: [EffectChoice]
    var volumeKeyController: VolumeKeyController?

    init(storageURL: URL? = nil, startMonitoring: Bool = true) {
        browserMonitoring = startMonitoring
        listening = ListeningController(observationEnabled: startMonitoring)
        fileURL = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OpenAudio/preferences.json")
        let description = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: 0, componentManufacturer: 0, componentFlags: 0, componentFlagsMask: 0)
        effects = !startMonitoring ? [] : AVAudioUnitComponentManager.shared().components(matching: description).map {
            let d = $0.audioComponentDescription
            return EffectChoice(name: $0.name, type: d.componentType, subtype: d.componentSubType, manufacturer: d.componentManufacturer)
        }.sorted { $0.name < $1.name }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                preferences = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: fileURL))
                preferences.routes = preferences.routes.filter { !$0.key.hasPrefix("process:") }
                for id in preferences.routes.keys { preferences.routes[id]?.validate() }
                for i in preferences.profiles.indices { preferences.profiles[i].routes = preferences.profiles[i].routes.filter { !$0.key.hasPrefix("process:") }; for id in preferences.profiles[i].routes.keys { preferences.profiles[i].routes[id]?.validate() } }
            } catch { errorMessage = "Saved settings could not be read: \(error.localizedDescription)" }
        }
        listening.browserCommand = { [weak self] source, action in
            guard let self else { return "OpenAudio is closing." }
            return await self.browserBridge.mediaCommand(source: source, action: action)
        }
        listening.visibilityChanged = { [weak self] active in self?.browserBridge.observeMedia = active }
        enabled = preferences.processingEnabled
        if startMonitoring {
            repairBrowserIntegration()
            refresh()
            timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
            browserTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshBrowser() }
            }
            let center = NSWorkspace.shared.notificationCenter
            notifications.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.sleeping = true; self?.stopSessions(); self?.browserBridge.publish(allow: false) }
            })
            notifications.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.sleeping = false; self?.failures.removeAll(); self?.refresh() }
            })
            volumeKeyController = VolumeKeyController { [weak self] delta, mute in
                guard let self else { return }
                if let device = self.devices.first(where: { $0.id == self.defaultOutput }) {
                    if mute {
                        if let muted = device.outputMuted { self.deviceMute(device, muted: !muted, input: false) }
                        else { self.setSoftwareMute(device.uid, !self.preferences.softwareMutes.contains(device.uid)) }
                    } else if let volume = device.outputVolume {
                        if self.preferences.softwareMutes.contains(device.uid) { self.setSoftwareMute(device.uid, false) }
                        if device.outputMuted == true { self.deviceMute(device, muted: false, input: false) }
                        self.deviceVolume(device, volume: volume + delta, input: false)
                    } else {
                        self.preferences.softwareMutes.remove(device.uid)
                        self.setSoftwareVolume(device.uid, (self.preferences.softwareVolumes[device.uid] ?? 1) + delta)
                    }
                }
            }
            if preferences.volumeKeys { setVolumeKeys(true, prompt: false) }
        }
    }
    var outputs: [AudioDevice] { devices.filter { $0.outputChannels > 0 } }
    var inputs: [AudioDevice] { devices.filter { $0.inputChannels > 0 } }
    var defaultUID: String? { devices.first { $0.id == defaultOutput }?.uid }
    var preferredColorScheme: ColorScheme? { preferences.appearance == "dark" ? .dark : preferences.appearance == "light" ? .light : nil }
    func settings(_ id: String) -> RouteSettings { preferences.routes[id] ?? RouteSettings() }
    func name(_ id: String) -> String { id == systemRouteID ? "Other audio" : sources.first { $0.id == id }?.name ?? preferences.names[id] ?? id }
    func outputName(_ route: RouteSettings) -> String {
        if route.outputs.isEmpty { return "System default" }
        return route.outputs.map { uid in devices.first { $0.uid == uid }?.name ?? "Unavailable device" }.joined(separator: " + ")
    }
    func edit(_ id: String, _ change: (inout RouteSettings) -> Void) {
        previous = preferences; undoAvailable = true
        let original = settings(id)
        var route = original; change(&route); route.validate()
        var audibleOriginal = original
        audibleOriginal.favorite = route.favorite
        if route != audibleOriginal {
            enabled = true
            preferences.processingEnabled = true
        }
        preferences.routes[id] = route
        preferences.names[id] = name(id)
        failures.removeValue(forKey: id)
        persistSoon(); reconcile()
    }
    func undo() {
        guard let previous else { return }
        preferences.routes = previous.routes; preferences.names = previous.names; self.previous = nil; undoAvailable = false
        failures.removeAll(); persistSoon(); reconcile()
    }
    func reset(_ id: String) { edit(id) { $0 = RouteSettings() } }
    func retry(_ id: String? = nil) {
        if let id { failures.removeValue(forKey: id); sessions.removeValue(forKey: id)?.stop() }
        else { failures.removeAll(); stopSessions() }
        refresh()
    }
    func setProcessing(_ value: Bool) { enabled = value; preferences.processingEnabled = value; failures.removeAll(); persistSoon(); reconcile() }
    func toggleProcessing() { setProcessing(!enabled) }
    private func refreshBrowser() {
        browserBridge.read(); browserSessions = browserBridge.snapshots
        reconcile()
    }
    func refresh() {
        RouteSession.retryCleanup()
        if browserMonitoring { browserBridge.read(); browserSessions = browserBridge.snapshots }
        devices = Hardware.devices(); sources = Hardware.sources()
        updateListeningSources()
        let now = Date()
        for source in sources where source.active { lastOutputActivity[source.id] = now }
        lastOutputActivity = lastOutputActivity.filter { now.timeIntervalSince($0.value) < 120 }
        let present = Set(sources.map(\.id))
        preferences.routes = preferences.routes.filter { !$0.key.hasPrefix("process:") || present.contains($0.key) }
        preferences.names = preferences.names.filter { !$0.key.hasPrefix("process:") || present.contains($0.key) }
        for i in preferences.profiles.indices { preferences.profiles[i].routes = preferences.profiles[i].routes.filter { !$0.key.hasPrefix("process:") || present.contains($0.key) } }
        defaultOutput = Hardware.defaultDevice(); defaultInput = Hardware.defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
        defaultEffects = Hardware.defaultDevice(kAudioHardwarePropertyDefaultSystemOutputDevice)
        reconcile()
    }
    func showVinyl(_ id: String) {
        updateListeningSources()
        let source = listening.sources.first { $0.id == id } ?? ListeningSource(id: id, name: name(id), appID: id, active: sources.first { $0.id == id }?.active ?? false)
        listening.choose(source)
    }
    func showVinyl(_ session: BrowserSnapshot, tab: BrowserTab) {
        updateListeningSources()
        if let source = listening.sources.first(where: { $0.id == ListeningSource.tabKey(session.id, tab.id) }) { listening.choose(source) }
    }
    private func updateListeningSources() {
        var candidates = sources.filter { $0.active || recentSourceIDs.contains($0.id) || settings($0.id).favorite || listening.pin == $0.id }.map {
            ListeningSource(id: $0.id, name: $0.name, appID: $0.id, active: $0.active, lifetime: (NSRunningApplication.runningApplications(withBundleIdentifier: $0.id).first ?? NSRunningApplication(processIdentifier: $0.pid)).map(NativeMediaProbe.lifetime) ?? String(describing: $0.processes))
        }
        for provider in NativeMediaProbe.providers where !candidates.contains(where: { $0.id == provider.id }) {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: provider.id).first {
                candidates.append(ListeningSource(id: provider.id, name: provider.name, appID: provider.id, active: false, lifetime: NativeMediaProbe.lifetime(app)))
            }
        }
        candidates.append(ListeningSource(id: systemRouteID, name: "Other audio", appID: systemRouteID, active: false))
        for session in browserSessions {
            for tab in session.report.tabs {
                candidates.append(ListeningSource(id: ListeningSource.tabKey(session.id, tab.id), name: tab.title, appID: session.browser, session: session.id, tabID: tab.id, active: session.fresh && tab.audible, available: session.fresh, track: session.fresh ? tab.media : nil, status: session.fresh ? "Page has not shared track details · allow metadata access in browser setup" : "Browser connection lost", lifetime: tab.document ?? ""))
            }
        }
        listening.update(candidates)
    }
    private func reconcile() {
        defer { if browserMonitoring { browserBridge.publish(allow: enabled && !sleeping && !RouteSession.cleanupBlocked) } }
        guard enabled, !sleeping, !RouteSession.cleanupBlocked else {
            stopSessions()
            for id in Set(sources.map(\.id) + Array(preferences.routes.keys) + [systemRouteID]) {
                observations[id] = RouteObservation(text: RouteSession.cleanupBlocked ? "Audio cleanup pending · quit if playback does not recover" : sleeping ? "Paused during sleep" : "Bypassed · native playback")
            }
            return
        }
        let sourceMap = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        let reserved = browserBridge.reservedBrowsers
        for id in Array(sessions.keys) where reserved.contains(id) { sessions.removeValue(forKey: id)?.stop() }
        let controlled = sources.filter { !reserved.contains($0.id) && settings($0.id).needsProcessing }
        let selfProcesses = Hardware.selfProcesses()
        let excluded = Array(Set(controlled.flatMap(\.processes) + selfProcesses + sources.filter { reserved.contains($0.id) }.flatMap(\.processes))).sorted()
        let explicitSystem = !reserved.isEmpty
        let systemMembership = explicitSystem ? Array(Set(sources.filter { !$0.id.hasPrefix("process:") && !reserved.contains($0.id) }.flatMap(\.processes)).subtracting(excluded)).sorted() : excluded
        if globalMembership != systemMembership {
            sessions.removeValue(forKey: systemRouteID)?.stop()
            globalMembership = systemMembership
        }
        let softwareMaster = defaultUID.map { (preferences.softwareVolumes[$0] ?? 1) != 1 || preferences.softwareMutes.contains($0) } ?? false
        let desired = Set(controlled.map(\.id) + (settings(systemRouteID).needsProcessing || softwareMaster ? [systemRouteID] : []))
        for id in Array(sessions.keys) where !desired.contains(id) { sessions.removeValue(forKey: id)?.stop() }
        for id in Set(Array(preferences.routes.keys) + sources.map(\.id) + [systemRouteID]) {
            let route = settings(id)
            if reserved.contains(id) {
                observations[id] = RouteObservation(text: "Controlled by browser tabs · native controls paused")
                continue
            }
            guard desired.contains(id) else {
                observations[id] = RouteObservation(text: sourceMap[id] == nil && id != systemRouteID ? "Waiting for app" : "Native playback")
                continue
            }
            if id == systemRouteID && selfProcesses.isEmpty {
                sessions.removeValue(forKey: id)?.stop()
                observations[id] = RouteObservation(text: "Waiting for mixer audio identity · retry", failure: true)
                continue
            }
            let processIDs = id == systemRouteID ? systemMembership : sourceMap[id]?.processes.sorted() ?? []
            if id == systemRouteID && explicitSystem && processIDs.isEmpty {
                sessions.removeValue(forKey: id)?.stop()
                observations[id] = RouteObservation(text: "Waiting for nonbrowser audio · browser tabs excluded")
                continue
            }
            let uids = route.resolveOutputs(available: Set(outputs.map(\.uid)), defaultUID: defaultUID)
            guard !uids.isEmpty else {
                sessions.removeValue(forKey: id)?.stop()
                observations[id] = RouteObservation(text: "Output unavailable · native playback", failure: true)
                continue
            }
            let targets = uids.compactMap { uid in outputs.first { $0.uid == uid } }
            let captureDeviceUID = id == systemRouteID && !route.needsProcessing ? defaultUID : nil
            let effectSignature = route.effects.map { "\($0.id):\($0.type):\($0.subtype):\($0.manufacturer):\($0.bypass)" }.joined(separator: ",")
            let signature = "\(captureDeviceUID ?? "global")|\(explicitSystem)|\(processIDs)|\(targets.map { "\($0.id):\($0.sampleRate):\($0.inputChannels):\($0.outputChannels)" })|\(effectSignature)"
            if sessions[id]?.signature != signature { sessions.removeValue(forKey: id)?.stop() }
            if let session = sessions[id], session.error != 0 {
                let status = session.error
                session.stop(); sessions.removeValue(forKey: id); failures[id] = signature
                observations[id] = RouteObservation(text: "Audio effect failed (\(status)) · retry", failure: true)
            }
            if failures[id] == signature { continue }
            if RouteSession.cleanupBlocked {
                observations[id] = RouteObservation(text: "Waiting for previous audio route to release", failure: true)
                continue
            }
            do {
                if sessions[id] == nil {
                    observations[id] = RouteObservation(text: "Preparing audio…")
                    sessions[id] = try RouteSession(processes: processIDs, excluding: id == systemRouteID && !explicitSystem, devices: targets, settings: route, signature: signature, softwareVolumes: preferences.softwareVolumes, softwareMutes: preferences.softwareMutes, captureDeviceUID: captureDeviceUID)
                }
                if let session = sessions[id] {
                    session.apply(route)
                    session.applyOutputLevels(volumes: preferences.softwareVolumes, mutes: preferences.softwareMutes)
                    let sourceActive = id == systemRouteID ? sources.contains { source in source.active && !controlled.contains(where: { $0.id == source.id }) && (captureDeviceUID == nil || source.processes.contains { Hardware.array($0, kAudioProcessPropertyDevices).contains(defaultOutput) }) } : sourceMap[id]?.active ?? false
                    if session.hasStalled(sourceActive: sourceActive) {
                        session.stop(); sessions.removeValue(forKey: id); failures[id] = signature
                        observations[id] = RouteObservation(text: "No audio received · check capture permission, then retry", failure: true)
                    } else {
                        observations[id] = RouteObservation(text: session.frames > 0 ? (route.muted ? "Muted" : "Routing to \(outputName(route))") : "Waiting for audio", active: session.frames > 0, peak: session.peak)
                    }
                }
            } catch {
                sessions.removeValue(forKey: id)?.stop(); failures[id] = signature
                observations[id] = RouteObservation(text: error.localizedDescription, failure: true)
            }
        }
    }
    private func stopSessions() { for session in sessions.values { session.stop() }; sessions.removeAll() }
    func shutdown() { listening.shutdown(); timer?.invalidate(); timer = nil; browserTimer?.invalidate(); browserTimer = nil; stopSessions(); if browserMonitoring { browserBridge.publish(allow: false) }; saveTask?.cancel(); persist(); volumeKeyController?.stop() }
    func prepareLocalExtension() {
        guard browserBridge.reservedBrowsers.isEmpty else {
            browserSetupError = "Release managed tabs before preparing or updating the local extension."
            return
        }
        do { localExtensionURL = try BrowserIntegration.prepareLocalExtension(); browserSetupError = nil }
        catch { browserSetupError = "Could not prepare the local companion: \(error.localizedDescription)" }
    }
    func repairBrowserIntegration() {
        do { try BrowserIntegration.register(); browserSetupError = nil }
        catch { browserSetupError = "Browser connection setup failed: \(error.localizedDescription)" }
    }
    func refreshBrowserDevices(_ session: String) { browserBridge.refreshDevices(session); reconcile() }
    func openBrowserSetup(_ session: String) { browserBridge.openSetup(session); reconcile() }
    func browserReserved(_ id: String) -> Bool { browserBridge.reservedBrowsers.contains(id) }
    func editTab(_ session: String, tab: BrowserTab, _ change: (inout TabSettings) -> Void) {
        browserBridge.edit(session, tab: tab, change)
        objectWillChange.send()
        reconcile()
    }
    func focusTab(_ session: String, tab: Int) { browserBridge.focus(session, tab: tab); reconcile() }
    private func persistSoon() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }; self?.persist()
        }
    }
    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            var retained = preferences
            retained.routes = retained.routes.filter { !$0.key.hasPrefix("process:") }
            for i in retained.profiles.indices { retained.profiles[i].routes = retained.profiles[i].routes.filter { !$0.key.hasPrefix("process:") } }
            try JSONEncoder().encode(retained).write(to: fileURL, options: .atomic)
        } catch { errorMessage = "Settings could not be saved: \(error.localizedDescription)" }
    }
    func saveProfile(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !preferences.profiles.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { errorMessage = "A profile named \(name) already exists. Choose a different name."; return }
        preferences.profiles.append(ListeningProfile(name: name, routes: preferences.routes)); persistSoon()
    }
    func applyProfile(_ profile: ListeningProfile) {
        previous = preferences; undoAvailable = true; preferences.routes = profile.routes
        failures.removeAll(); persistSoon(); reconcile()
    }
    func deleteProfile(_ id: UUID) { preferences.profiles.removeAll { $0.id == id }; persistSoon() }
    func setAppearance(_ value: String) { preferences.appearance = value; persistSoon() }
    func setVolumeKeys(_ value: Bool, prompt: Bool = true) {
        if value && volumeKeyController?.start(prompt: prompt) != true {
            errorMessage = "Enable OpenAudio in System Settings → Privacy & Security → Accessibility, then enable volume keys again."
            preferences.volumeKeys = false
        } else { preferences.volumeKeys = value; if !value { volumeKeyController?.stop() } }
        persistSoon()
    }
    func setLogin(_ value: Bool) {
        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
        catch { errorMessage = error.localizedDescription }
        objectWillChange.send()
    }
    func setSoftwareVolume(_ uid: String, _ value: Float) {
        preferences.softwareVolumes[uid] = value.isFinite ? min(1, max(0, value)) : 1
        setProcessing(true)
    }
    func setSoftwareMute(_ uid: String, _ muted: Bool) {
        if muted { preferences.softwareMutes.insert(uid) } else { preferences.softwareMutes.remove(uid) }
        setProcessing(true)
    }
    func deviceVolume(_ device: AudioDevice, volume: Float, input: Bool) {
        do { try Hardware.setVolume(device.id, volume, input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput); refresh() }
        catch { errorMessage = error.localizedDescription }
    }
    func deviceMute(_ device: AudioDevice, muted: Bool, input: Bool) {
        do { try Hardware.write(device.id, kAudioDevicePropertyMute, UInt32(muted ? 1 : 0), scope: input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput); refresh() }
        catch { errorMessage = error.localizedDescription }
    }
    func setDefault(_ id: AudioObjectID, selector: UInt32) {
        do { try Hardware.write(Hardware.system, selector, id); refresh() } catch { errorMessage = error.localizedDescription }
    }
    func setRate(_ device: AudioDevice, rate: Double) {
        stopSessions()
        do { try Hardware.write(device.id, kAudioDevicePropertyNominalSampleRate, rate); refresh() } catch { errorMessage = error.localizedDescription; refresh() }
    }
    func parameters(_ routeID: String, effectID: UUID) -> [EffectParameter] {
        sessions[routeID]?.unit(effectID).map(effectParameters) ?? []
    }
    func automate(_ url: URL) {
        guard url.scheme == "openaudio", let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let query = Dictionary((parts.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, last in last })
        if url.host == "profile", let name = query["name"], let profile = preferences.profiles.first(where: { $0.name == name }) { applyProfile(profile); return }
        if url.host == "browser" { browserRequestedAt = Date(); return }
        if url.host == "bypass" { setProcessing(false); return }
        if url.host == "enable" { setProcessing(true); return }
        guard url.host == "route", let app = query["app"], app == systemRouteID || sources.contains(where: { $0.id == app }) || preferences.routes[app] != nil else {
            errorMessage = "Automation needs a known app bundle ID or profile name."; return
        }
        edit(app) { route in
            if let volume = query["volume"].flatMap(Float.init) { route.volume = volume }
            if let muted = query["mute"] { route.muted = muted == "true" || muted == "1" }
            if let output = query["output"] { route.outputs = output == "default" ? [] : [output] }
        }
    }
}

import AVFoundation
