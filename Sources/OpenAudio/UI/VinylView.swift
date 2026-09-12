import SwiftUI
import AppKit

struct VinylCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandMenu("Listening") {
            Button("Open Vinyl") { openWindow(id: "vinyl"); NSApplication.shared.activate(ignoringOtherApps: true) }
                .keyboardShortcut("v", modifiers: [.command, .option])
        }
    }
}

struct VinylView: View {
    @ObservedObject var model: AudioController
    @ObservedObject var listening: ListeningController
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("vinyl.artOnly") private var artOnly = false
    @State private var showConnections = false
    @StateObject private var presentation = VinylWindowState()
    @AppStorage("vinyl.finish") private var finishName = "Cream"
    @AppStorage("vinyl.tint") private var tintName = "Cherry"
    @AppStorage("vinyl.mood") private var moodName = "Warm"
    private var mood: VinylMood { VinylMood(rawValue: moodName) ?? .warm }
    @AppStorage("vinyl.rpm") private var rpm = 6.0
    @State private var showAppearance = false
    private var finish: VinylFinish { VinylFinish(rawValue: finishName) ?? .cream }
    private var recordTint: VinylTint { VinylTint(rawValue: tintName) ?? .cherry }
    private var cream: Color { finish.foreground }
    private var source: ListeningSource? { listening.selected }
    private var playing: Bool { source?.visualPlaying == true }
    var body: some View {
        VStack(spacing: 0) {
            header
            VinylStage(artwork: listening.artwork, title: source?.track?.title ?? source?.name ?? "Choose a source", artist: source?.track?.artist ?? "", playing: playing, artOnly: artOnly, rpm: rpm, finish: finish, tint: recordTint, reducedMotion: reduceMotion, confirmedPlaying: playing)
                .frame(maxWidth: 1320, maxHeight: .infinity).padding(.horizontal, 20)
            trackDetails
            controls
        }
        .foregroundStyle(cream).tint(finish.dark ? Color(white: 0.92) : Color(white: 0.22)).background {
            VinylAtmosphere(image: listening.artwork == nil ? mood.image : nil, finish: finish, reducedTransparency: reduceTransparency)
            if finish == .album, let image = listening.artwork, !reduceTransparency { Image(nsImage: image).resizable().scaledToFill().blur(radius: 100).opacity(0.10).clipped().accessibilityHidden(true) }
        }.preferredColorScheme(finish.dark ? .dark : .light)
        .frame(minWidth: 820, minHeight: 640)
        .background(VinylWindowBinding(state: presentation))
        .onAppear { listening.appear() }
        .onDisappear { listening.disappear() }
        .onExitCommand { presentation.escape() }
        .sheet(isPresented: $showConnections) {
            VStack(spacing: 0) {
                HStack { Text("Connections & sound").font(.headline); Spacer(); Button("Done") { showConnections = false }.keyboardShortcut(.defaultAction) }.padding(24)
                connections.buttonStyle(VinylButtonStyle()).frame(maxHeight: .infinity)
            }.frame(width: 560, height: 480)
        }
    }
    private var header: some View {
        HStack(spacing: 14) {
            Button { openWindow(id: "main"); NSApplication.shared.activate(ignoringOtherApps: true) } label: { Label("Mixer", systemImage: "arrow.left") }
            Spacer()
            Picker("Listening source", selection: Binding(get: { listening.pin ?? "automatic" }, set: { id in
                if id == "automatic" { listening.automatic() }
                else if let source = listening.sources.first(where: { $0.id == id }) { listening.choose(source) }
            })) {
                Text("Automatic source").tag("automatic")
                ForEach(listening.sources) { source in Text(source.name + (source.tabID == nil ? "" : " · tab")).tag(source.id) }
                if let pin = listening.pin, !listening.sources.contains(where: { $0.id == pin }) { Text("Pinned source unavailable").tag(pin) }
            }.buttonStyle(.borderless).frame(maxWidth: 240).labelsHidden().vinylPointer().accessibilityLabel("Listening source. Choosing a source pins it")
            HStack(spacing: 2) {
                ForEach([false, true], id: \.self) { artwork in
                    Button { artOnly = artwork } label: {
                        Text(artwork ? "Artwork" : "Vinyl").font(.system(size: 12, weight: .medium))
                            .foregroundStyle(artOnly == artwork ? finish.surface : cream)
                            .frame(width: 70, height: 30)
                            .background(artOnly == artwork ? cream : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(VinylButtonStyle()).accessibilityValue(artOnly == artwork ? "Selected" : "")
                }
            }.padding(3).background(cream.opacity(0.06), in: RoundedRectangle(cornerRadius: 9)).fixedSize().accessibilityElement(children: .contain).accessibilityLabel("Listening scene")
            Button { showAppearance.toggle() } label: { Image(systemName: "slider.horizontal.3").frame(width: 30, height: 30) }
                .accessibilityLabel("Customize turntable").help("Customize turntable")
                .popover(isPresented: $showAppearance) { appearance.buttonStyle(VinylButtonStyle()).padding(24).frame(width: 330) }
            Button { presentation.toggle() } label: { Image(systemName: presentation.fullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right").frame(width: 30, height: 30) }
                .disabled(!presentation.attached || presentation.transitioning)
                .help(presentation.fullScreen ? "Exit full screen" : "Enter full screen").accessibilityLabel(presentation.fullScreen ? "Exit full screen" : "Enter full screen").keyboardShortcut("f", modifiers: [.command, .control])
        }.buttonStyle(VinylButtonStyle()).padding(.horizontal, 32).padding(.top, presentation.fullScreen ? 18 : 28).padding(.bottom, 8)
    }
    private var appearance: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Make it yours.").font(.system(size: 23, design: .serif))
            Picker("Surface", selection: $finishName) { ForEach(VinylFinish.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }.pickerStyle(.segmented).buttonStyle(.borderless).vinylPointer()
            VStack(alignment: .leading, spacing: 10) {
                Text("Record color").font(.system(size: 12, weight: .medium))
                HStack(spacing: 18) {
                    ForEach(VinylTint.allCases, id: \.rawValue) { tint in
                        Button { tintName = tint.rawValue } label: {
                            VStack(spacing: 6) {
                                Circle().fill(tint.color).frame(width: 32, height: 32).overlay(Circle().strokeBorder(cream, lineWidth: tintName == tint.rawValue ? 2 : 0).padding(3))
                                Text(tint.rawValue).font(.system(size: 10))
                            }
                        }.buttonStyle(VinylButtonStyle()).accessibilityLabel("\(tint.rawValue) record").accessibilityValue(tintName == tint.rawValue ? "Selected" : "")
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("When the cover is missing").font(.system(size: 12, weight: .medium))
                HStack(spacing: 10) {
                    ForEach(VinylMood.allCases, id: \.rawValue) { item in
                        Button { moodName = item.rawValue } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    finish.surface
                                    if let photo = item.image { Image(nsImage: photo).resizable().scaledToFill() }
                                }.frame(width: 70, height: 48).clipped().clipShape(RoundedRectangle(cornerRadius: 5))
                                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(cream, lineWidth: item == mood ? 2 : 0))
                                Text(item.rawValue).font(.system(size: 10))
                            }
                        }.buttonStyle(VinylButtonStyle()).accessibilityLabel("\(item.rawValue) mood background").accessibilityValue(item == mood ? "Selected" : "")
                    }
                }
                Link("Photo: \(mood.photographer) / Unsplash", destination: mood.page).vinylPointer().font(.system(size: 10))
            }
            Picker("Visual rotation", selection: $rpm) {
                Text("Calm · 6 RPM").tag(6.0)
                Text("Slow · 12 RPM").tag(12.0)
                Text("LP · 33⅓ RPM").tag(100.0 / 3)
                Text("Single · 45 RPM").tag(45.0)
            }.buttonStyle(.borderless).vinylPointer()
            Text(reduceMotion ? "Reduce Motion is on. The record stays still." : "Rotation changes the visual only. Your audio speed stays the same.").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
    private var trackDetails: some View {
        VStack(spacing: 8) {
            Text(source?.track?.title ?? source?.name ?? "Pick a record. Take your time.")
                .font(.system(size: 28, weight: .regular, design: .serif)).multilineTextAlignment(.center).lineLimit(2).textSelection(.enabled)
            if let track = source?.track {
                Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: "  ·  "))
                    .font(.system(size: 14)).foregroundStyle(cream.opacity(0.8)).lineLimit(2).textSelection(.enabled)
            }
            Text(source.map { "\($0.tabID == nil ? $0.name : "Browser tab") · \(listening.pin == nil ? "Automatic source" : "Pinned source")" } ?? "Automatic source · waiting for playback")
                .font(.system(size: 11)).foregroundStyle(cream.opacity(0.7))
            if let source { Text(source.visualPlaybackLabel).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary) }
            if listening.findingCover || listening.sourceArtworkLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(listening.artworkStatus).lineLimit(2)
                }.font(.system(size: 12)).accessibilityElement(children: .combine)
            } else if listening.artworkSuggested {
                Text(listening.artworkStatus).font(.system(size: 12, weight: .medium)).multilineTextAlignment(.center).lineLimit(2)
            }
            if listening.artwork == nil { Text("\(mood.rawValue) mood background · Album cover unavailable").font(.system(size: 10)).foregroundStyle(.secondary) }
            if source?.track == nil {
                HStack(spacing: 10) {
                    Text(source?.available == false ? "This source is unavailable" : "Player details unavailable").foregroundStyle(.secondary)
                    if listening.canFindCover && listening.artwork == nil {
                        Button("Suggest artwork") { listening.findCover() }.disabled(listening.findingCover)
                    }
                    Button("Connect player", action: recoverMetadata)
                }.font(.system(size: 12))
            }
            if let failure = presentation.failure { Text(failure).font(.system(size: 12)).foregroundStyle(.orange) }
            if let track = source?.track, let duration = track.duration, let position = track.position, duration > 0, duration.isFinite, position.isFinite {
                HStack(spacing: 12) {
                    Text(clock(position)).monospacedDigit()
                    ProgressView(value: min(max(0, position), duration), total: duration).accessibilityLabel("Track progress")
                    Text(clock(duration)).monospacedDigit()
                }.font(.system(size: 10)).frame(maxWidth: 320).padding(.top, 8)
            }
        }.frame(maxWidth: 780).padding(.horizontal, 32).padding(.top, 4).padding(.bottom, 16)
    }
    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 28) {
                if source != nil {
                    Button { listening.command("previous") } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("Previous track").disabled(!listening.supports("previous")).help(listening.supports("previous") ? "Previous track" : "Previous track is unavailable for this player")
                    Button { listening.command("playpause") } label: { Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 24)).frame(width: 44, height: 36) }
                        .accessibilityLabel(playing ? "Pause" : "Play").keyboardShortcut(.space, modifiers: []).disabled(!listening.supports("playpause"))
                    Button { listening.command("next") } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Next track").disabled(!listening.supports("next")).help(listening.supports("next") ? "Next track" : "Next track is unavailable for this player")
                }
                if source != nil { Button("Open source", action: openSource).disabled(source?.available != true) }
            }.buttonStyle(VinylButtonStyle()).disabled(listening.pendingAction)
            if !listening.actionStatus.isEmpty { Text(listening.actionStatus).font(.system(size: 11)).foregroundStyle(cream.opacity(0.75)) }
            HStack(spacing: 16) {
                Button(listening.findingCover ? "Finding cover…" : listening.coverQuery?.artist.isEmpty == true ? "Suggest album cover" : "Find album cover") { listening.findCover() }
                    .disabled(listening.findingCover || !listening.canFindCover)
                Menu {
                    Toggle("Fetch artwork automatically", isOn: $listening.automaticArtwork)
                    Divider()
                    Button("Refresh cover lookup") { listening.findCover(refresh: true) }.disabled(listening.findingCover || !listening.canFindCover)
                    Button("Clear saved cover lookups") { listening.clearCovers() }
                } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Cover lookup options").frame(minWidth: 32, minHeight: 36).vinylPointer()
                Spacer()
                Button { showConnections.toggle() } label: { Label("Connections & sound", systemImage: "slider.horizontal.3") }
            }.font(.system(size: 12)).buttonStyle(VinylButtonStyle())
            Text(listening.artworkStatus.isEmpty ? "Artwork uses MusicBrainz, Cover Art Archive and public music pages. Automatic fetching can be changed in cover options." : listening.artworkStatus)
                .font(.system(size: 10)).foregroundStyle(cream.opacity(0.65)).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.horizontal, 32).padding(.bottom, 24)
    }
    private var connections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Connect once. Listen here.").font(.system(size: 17, weight: .medium, design: .serif))
                Text("Native track details require your Automation approval. Browser tabs use metadata access in the companion’s settings.")
                    .font(.system(size: 12)).foregroundStyle(cream.opacity(0.8))
                ForEach(NativeMediaProbe.providers, id: \.id) { provider in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(provider.name)
                            Text(listening.providerStatus[provider.id] ?? "Not connected").font(.system(size: 11)).foregroundStyle(cream.opacity(0.75))
                        }
                        Spacer()
                        Button(listening.enabledProviders.contains(provider.id) ? "Reconnect" : "Connect") { listening.connect(provider.id) }
                        if listening.enabledProviders.contains(provider.id) { Button("Disconnect") { listening.disconnect(provider.id) } }
                    }.font(.system(size: 12))
                }
                if let source {
                    Divider()
                    if source.tabID == nil {
                        AudioRow(model: model, id: source.appID, compact: true)
                    } else if let session = model.browserSessions.first(where: { $0.id == source.session }), let tab = session.report.tabs.first(where: { $0.id == source.tabID }) {
                        Button("Browser metadata & device access…") { model.openBrowserSetup(session.id) }
                        if tab.active {
                            Slider(value: Binding(get: { model.browserBridge.settings(session.id, tab).volume }, set: { value in model.editTab(session.id, tab: tab) { $0.volume = value } }), in: 0...1).accessibilityLabel("Selected tab volume")
                        } else { Text("Tab sound controls require the browser toolbar activation.").font(.system(size: 11)) }
                    }
                }
            }.padding(24)
        }.background(finish.surface)
    }
    private func clock(_ seconds: Double) -> String {
        let value = Int(min(359999, max(0, seconds)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
    private func recoverMetadata() {
        if let session = source?.session { model.openBrowserSetup(session) }
        else { showConnections = true }
    }
    private func openSource() {
        guard let source else { return }
        if let session = source.session, let tab = source.tabID { model.focusTab(session, tab: tab) }
        else if let app = NSRunningApplication.runningApplications(withBundleIdentifier: source.appID).first { app.activate(options: []) }
    }
}
