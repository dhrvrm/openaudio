import SwiftUI
import CoreAudio
import ServiceManagement

struct Workspace: View {
    @ObservedObject var model: AudioController
    @Environment(\.openWindow) private var openWindow
    @State private var page = "Applications"
    @State private var search = ""
    @State private var activeOnly = false
    @State private var favoritesOnly = false
    @State private var showBackground = false
    @State private var showInspector = true
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                toolbar
                Rectangle().fill(Theme.separator).frame(height: 1)
                if page == "Devices" { DeviceView(model: model) }
                else if page == "Profiles" { ProfilesView(model: model) }
                else if page == "Browser tabs" { BrowserTabsView(model: model) }
                else { applications }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.canvas)
            if page == "Applications", showInspector, let id = model.selectedID {
                Rectangle().fill(Theme.separator).frame(width: 1)
                RouteEditor(model: model, routeID: id).disabled(model.browserReserved(id)).frame(width: 310).background(Theme.sidebar.opacity(0.45))
            }
        }
        .frame(minWidth: 980, minHeight: 620)
        .onChange(of: model.browserRequestedAt) { _, value in if value != nil { page = "Browser tabs" } }
        .onReceive(model.$selectedID) { id in if id != nil { page = "Applications"; showInspector = true } }
        .tint(Theme.accent)
        .preferredColorScheme(model.preferredColorScheme)
        .alert("OpenAudio", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.accent)
                Text("OpenAudio").font(.system(size: 19, weight: .semibold))
            }.padding(.bottom, 32).padding(.top, 24).padding(.leading, 10)
            ForEach([("Applications", "square.stack.3d.up.fill"), ("Browser tabs", "rectangle.on.rectangle"), ("Devices", "hifispeaker.fill"), ("Profiles", "bookmark.fill")], id: \.0) { title, icon in
                Button { page = title } label: {
                    HStack(spacing: 12) {
                        Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 20)
                        Text(title).font(.system(size: 14, weight: page == title ? .medium : .regular)).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                        Spacer()

                    }.padding(.horizontal, 12).frame(height: 38)
                        .background(page == title ? Theme.selection : .clear, in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
            Button { openWindow(id: "vinyl") } label: {
                Label("Vinyl", systemImage: "opticaldisc").font(.system(size: 14)).padding(12)
            }.buttonStyle(.plain)
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Circle().fill(model.enabled ? Theme.accent : Color.secondary).frame(width: 6, height: 6)
                    Text(model.enabled ? "Audio control enabled" : "Native playback").font(.system(size: 12, weight: .medium))
                }
                Text("Your sound, on this Mac.").font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(12)
            Menu {
                Picker("Appearance", selection: Binding(get: { model.preferences.appearance }, set: model.setAppearance)) {
                    Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                }
                Toggle("Launch at login", isOn: Binding(get: { SMAppService.mainApp.status == .enabled }, set: model.setLogin))
                Toggle("Control volume keys", isOn: Binding(get: { model.preferences.volumeKeys }, set: { model.setVolumeKeys($0) }))
                Divider()
                Button("Audio capture permission…") { openAudioPrivacy() }
                Button("Quit OpenAudio") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            } label: { Label("Settings", systemImage: "gearshape").frame(maxWidth: .infinity, alignment: .leading).padding(12) }
                .menuStyle(.borderlessButton)
        }.padding(12).frame(width: 220).background(Theme.sidebar)
    }
    private var toolbar: some View {
        HStack {
            Button { openWindow(id: "vinyl") } label: { Label("Vinyl", systemImage: "opticaldisc") }
            Text(page).font(.system(size: 13, weight: .medium))
            Spacer()
            Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!model.undoAvailable).help("Undo last listening edit").keyboardShortcut("z")
            if page == "Applications" {
                Button { showInspector.toggle() } label: { Image(systemName: "sidebar.right") }.help("Show or hide audio adjustments").keyboardShortcut("i", modifiers: [.command, .option])
            }
            Button(model.enabled ? "Bypass" : "Enable audio control") { model.toggleProcessing() }
                .buttonStyle(.bordered).controlSize(.small)
        }.buttonStyle(.plain).padding(.horizontal, 24).frame(height: 48)
    }
    private var applications: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your sound.").font(.system(size: 38, weight: .bold))
                    Text("Choose where each app plays.").font(.system(size: 14)).foregroundStyle(.secondary)
                }
                if !model.enabled {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "speaker.wave.2").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Audio control is bypassed").font(.system(size: 13, weight: .semibold))
                            Text("Changing volume, mute, output, or an audio adjustment resumes control. You can also enable your saved settings above.").font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
                VStack(spacing: 0) {
                    SectionLabel(title: "SYSTEM")
                    AudioRow(model: model, id: systemRouteID, compact: false)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Find an application", text: $search).textFieldStyle(.plain)
                        if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) }
                    }.padding(10).background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 8))
                    HStack(spacing: 16) {
                        Toggle("Playing", isOn: $activeOnly)
                        Toggle("Favorites", isOn: $favoritesOnly)
                        Spacer()
                        Menu { Toggle("Show background processes", isOn: $showBackground) } label: { Image(systemName: "line.3.horizontal.decrease") }.menuStyle(.borderlessButton).fixedSize()
                    }.toggleStyle(.checkbox).font(.system(size: 12))
                }
                VStack(spacing: 0) {
                    SectionLabel(title: "APPLICATIONS")
                    if filteredIDs.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "music.note").font(.system(size: 26)).foregroundStyle(.secondary)
                            Text(search.isEmpty ? "Play something to get started" : "No matching applications").font(.system(size: 15, weight: .medium))
                            Text("Apps appear when they connect to your Mac’s audio system.").font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(.vertical, 36)
                    }
                    ForEach(filteredIDs, id: \.self) { id in
                        AudioRow(model: model, id: id, compact: false)
                        Rectangle().fill(Theme.separator).frame(height: 1)
                    }
                }
                Text("Closing this window keeps your audio controls in the menu bar.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 8)
            }.padding(32).frame(maxWidth: 800)
        }
    }
    private var filteredIDs: [String] {
        let ids = visibleSourceIDs(sources: model.sources, routes: model.preferences.routes, recent: model.recentSourceIDs, showBackground: showBackground)
        return ids.filter { id in
            (search.isEmpty || model.name(id).localizedCaseInsensitiveContains(search)) &&
            (!activeOnly || model.sources.first { $0.id == id }?.active == true) &&
            (!favoritesOnly || model.settings(id).favorite)
        }.sorted { model.name($0).localizedCaseInsensitiveCompare(model.name($1)) == .orderedAscending }
    }
}

struct AudioRow: View {
    @ObservedObject var model: AudioController
    let id: String
    let compact: Bool
    @Environment(\.openWindow) private var openWindow
    private var route: RouteSettings { model.settings(id) }
    private var observation: RouteObservation { model.observations[id] ?? RouteObservation() }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                SourceIcon(source: model.sources.first { $0.id == id }, size: compact ? 26 : 32)
                Button {
                    model.selectedID = id
                    if compact { openWindow(id: "main"); NSApplication.shared.activate(ignoringOtherApps: true) }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.name(id)).font(.system(size: compact ? 12 : 14, weight: .medium)).lineLimit(1)
                        if !compact { Text(observation.text).font(.system(size: 10.5)).foregroundStyle(observation.failure ? Color.orange : Color.secondary).lineLimit(2) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).help("Adjust \(model.name(id))")
                Button { model.showVinyl(id); openWindow(id: "vinyl") } label: { Image(systemName: "opticaldisc") }.buttonStyle(.plain).help("Open \(model.name(id)) in Vinyl").accessibilityLabel("Open \(model.name(id)) in Vinyl")
                Button { model.edit(id) { $0.muted.toggle() } } label: {
                    Image(systemName: route.muted ? "speaker.slash.fill" : "speaker.wave.2").foregroundStyle(route.muted ? Theme.accent : Color.secondary)
                }.buttonStyle(.plain).disabled(model.browserReserved(id)).help(route.muted ? "Unmute \(model.name(id))" : "Mute \(model.name(id))")
            }
            HStack(spacing: 10) {
                Slider(value: Binding(get: { route.volume }, set: { value in model.edit(id) { $0.volume = value } }), in: 0...1)
                    .accessibilityLabel("\(model.name(id)) volume").disabled(model.browserReserved(id))
                Text("\(Int(route.volume * 100))%").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 38, alignment: .trailing)
            }
            HStack {
                Menu {
                    Button("System default") { model.edit(id) { $0.outputs = [] } }
                    ForEach(model.outputs) { device in Button(device.name) { model.edit(id) { $0.outputs = [device.uid] } } }
                } label: {
                    Label(model.outputName(route), systemImage: "arrow.turn.down.right").font(.system(size: 11)).lineLimit(1)
                }.menuStyle(.borderlessButton).fixedSize(horizontal: false, vertical: true).disabled(model.browserReserved(id))
                Spacer(minLength: 0)
                if observation.failure { Button("Retry") { model.retry(id) }.font(.system(size: 11)) }
            }
            LevelMeter(value: observation.active ? observation.peak : 0)
        }.padding(.vertical, compact ? 10 : 16).padding(.horizontal, compact ? 0 : 10)
            .background(!compact && model.selectedID == id ? Theme.accent.opacity(0.035) : .clear, in: RoundedRectangle(cornerRadius: 8))
    }
}

func openAudioPrivacy() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") { NSWorkspace.shared.open(url) }
}

struct ProfilesView: View {
    @ObservedObject var model: AudioController
    @State private var name = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Listening profiles").font(.system(size: 34, weight: .bold))
                Text("Save the current app routes and adjustments. Switch between work, music, and everything else.").foregroundStyle(.secondary)
                HStack {
                    TextField("Profile name", text: $name).textFieldStyle(.roundedBorder)
                    Button("Save current") { model.saveProfile(name); name = "" }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if model.preferences.profiles.isEmpty { ContentUnavailableView("No saved profiles", systemImage: "bookmark", description: Text("Set up your mix, then give it a name above.")) }
                ForEach(model.preferences.profiles) { profile in
                    HStack {
                        Image(systemName: "bookmark.fill").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name).fontWeight(.medium)
                            Text("\(profile.routes.count) saved app settings").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Apply") { model.applyProfile(profile) }
                        Button(role: .destructive) { model.deleteProfile(profile.id) } label: { Image(systemName: "trash") }.help("Delete \(profile.name)")
                    }.padding(.vertical, 10)
                    Divider()
                }
            }.padding(36)
        }
    }
}
