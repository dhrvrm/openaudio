import SwiftUI

struct BrowserTabsView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var model: AudioController
    @State private var showLocalSetup = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("One browser. Separate sounds.").font(.system(size: 32, weight: .bold))
                Text("Activate OpenAudio Tabs in each browser tab you want to control.").foregroundStyle(.secondary)
                DisclosureGroup(isExpanded: $showLocalSetup) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The Arc and Chrome companion is included with OpenAudio. Prepare a local copy, then approve it in your browser. This also updates an existing local copy; reload the companion in the browser after updating.")
                        Button("Prepare local extension") { model.prepareLocalExtension() }
                        if let folder = model.localExtensionURL {
                            Text("1. Open your browser’s Extensions settings.\n2. Enable Developer mode and choose Load unpacked.\n3. Select this folder. For an update, reload the existing companion afterward.")
                            HStack {
                                Button("Copy folder path") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(folder.path, forType: .string) }
                                Button("Show folder") { NSWorkspace.shared.open(folder) }
                            }
                            Text(folder.path).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                            Text("Files are ready. Connection is confirmed below only after the browser loads the companion.").foregroundStyle(.secondary)
                        }
                        Text("Then click the OpenAudio toolbar button in any playing tab. New playing tabs appear automatically; each tab still needs your first activation.")
                    }.font(.system(size: 13)).padding(.top, 12)
                } label: { Text("Set up or update the local browser companion").font(.headline) }
                .onAppear { if model.browserSessions.isEmpty { showLocalSetup = true } }
                if let error = model.browserSetupError {
                    Text(error).foregroundStyle(.orange)
                    Button("Repair browser connection") { model.repairBrowserIntegration() }
                }
                Text("Safari and other applications can be controlled in Applications. Separate Safari tab audio is not currently supported.").font(.system(size: 12)).foregroundStyle(.secondary)
                if !model.enabled { Text("Enable audio control above before activating a tab in the browser.").foregroundStyle(.orange) }
                ForEach(model.browserSessions) { session in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(session.browser == "company.thebrowser.Browser" ? "ARC TABS" : "CHROME TABS").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                            Spacer()
                            Text(session.fresh ? "Connected" : "Connection lost · waiting for capture release").font(.system(size: 11)).foregroundStyle(session.fresh ? Theme.accent : .orange)
                        }
                        HStack {
                            Button(session.report.needsDeviceAccess ? "Allow output device access…" : "Output device access…") { model.openBrowserSetup(session.id) }
                            Button("Refresh devices") { model.refreshBrowserDevices(session.id) }
                        }.controlSize(.small).disabled(!session.fresh)
                        if session.report.needsDeviceAccess {
                            Text("The browser has not shared its speaker list. Allow output device access to choose your connected speakers or headphones. macOS device names alone cannot authorize a browser audio route.")
                                .font(.system(size: 12)).foregroundStyle(.orange)
                        }
                        if let error = session.report.deviceError, !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(.orange) }
                        if let updated = session.report.devicesUpdatedAt, Date().timeIntervalSince1970 * 1000 - updated > 10000 {
                            Text("Device list is stale or still loading. Refresh devices to check current outputs.").font(.system(size: 12)).foregroundStyle(.orange)
                        }
                        if session.report.companionVersion != "0.5.0" {
                            Text("Update the local companion and reload it in the browser to use the latest device discovery.").font(.system(size: 12)).foregroundStyle(.orange)
                        }
                        if session.report.deviceStatus == "unavailable" {
                            Text("Access is granted, but the browser has not exposed any named outputs. Check the speaker connection and the browser’s microphone access in macOS, then refresh devices.").font(.system(size: 12)).foregroundStyle(.orange)
                        }
                        if model.browserReserved(session.browser) {
                            Text("The browser’s combined app controls and Other audio exclude this browser while tabs are managed. Unmanaged tabs use ordinary browser playback.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        if !session.report.error.isEmpty { Text(session.report.error).foregroundStyle(.orange) }
                        if session.report.tabs.isEmpty { Text("Play something in a tab to see it here.").foregroundStyle(.secondary) }
                        ForEach(session.report.tabs) { tab in
                            tabRow(session, tab)
                            Divider()
                        }
                    }
                }
                Text("Tab controls last for this browser session. Output choices come from the browser; use the companion’s device setup to reveal additional devices.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(32).frame(maxWidth: 820, alignment: .leading)
        }
    }
    @ViewBuilder private func tabRow(_ session: BrowserSnapshot, _ tab: BrowserTab) -> some View {
        let settings = model.browserBridge.settings(session.id, tab)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "rectangle.on.rectangle").foregroundStyle(Theme.accent).padding(.top, 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tab.title).font(.system(size: 14, weight: .medium)).lineLimit(2)
                    Text("\(tab.site) · tab \(String(tab.id))").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(!model.enabled && tab.active ? "Releasing browser audio…" : tab.active && tab.revision < model.browserBridge.revision(session.id) ? "Applying adjustment…" : tab.status)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Vinyl") { model.showVinyl(session, tab: tab); openWindow(id: "vinyl") }.controlSize(.small)
                Button("Open tab") { model.focusTab(session.id, tab: tab.id) }.controlSize(.small).disabled(!session.fresh)
            }
            if tab.active {
                HStack {
                    Button { model.editTab(session.id, tab: tab) { $0.muted.toggle() } } label: {
                        Image(systemName: settings.muted ? "speaker.slash.fill" : "speaker.wave.2")
                    }.buttonStyle(.plain).help(settings.muted ? "Unmute tab" : "Mute tab")
                    Slider(value: Binding(get: { settings.volume }, set: { value in model.editTab(session.id, tab: tab) { $0.volume = value } }), in: 0...1)
                        .accessibilityLabel("\(tab.title) tab volume")
                    Text("\(Int(settings.volume * 100))%").font(.system(size: 11, design: .monospaced)).frame(width: 38)
                }.disabled(!session.fresh || !model.enabled)
                LevelMeter(value: tab.peak)
                HStack {
                    Picker("Output", selection: Binding(get: { settings.output }, set: { value in model.editTab(session.id, tab: tab) { $0.output = value } })) {
                        Text("System default").tag("default")
                        ForEach(session.report.namedOutputs) { output in Text(output.label).tag(output.id) }
                        if settings.output != "default" && !session.report.namedOutputs.contains(where: { $0.id == settings.output }) {
                            Text("Selected output unavailable").tag(settings.output)
                        }
                        if session.report.needsDeviceAccess { Text("Allow output device access to see speakers").disabled(true) }
                    }.labelsHidden().frame(maxWidth: 300).disabled(!session.fresh || !model.enabled)
                    Spacer()
                    Button("Release tab") { model.editTab(session.id, tab: tab) { $0.release = true } }.controlSize(.small).disabled(!session.fresh)
                }
            } else {
                Text("Open this tab, then click the OpenAudio Tabs toolbar button. No popup is needed.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 12)
    }
}
