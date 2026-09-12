import SwiftUI
import AppKit

@main
struct OpenAudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model: AudioController
    init() {
        if CommandLine.arguments.count >= 6, CommandLine.arguments[1] == "--media-probe" {
            let result = NativeMediaProbe.execute(appID: CommandLine.arguments[2], operation: CommandLine.arguments[3], authorization: CommandLine.arguments.last == "authorize", expectedLifetime: CommandLine.arguments[4])
            if let data = try? JSONEncoder().encode(result) { FileHandle.standardOutput.write(data) }
            exit(0)
        }
        if CommandLine.arguments.contains("--native-host") { BrowserMailbox.nativeHost(); exit(0) }
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > index + 1 {
            Diagnostics.snapshot(path: CommandLine.arguments[index + 1]); exit(0)
        }
        if CommandLine.arguments.contains("--smoke") {
            do { try Diagnostics.smoke(); exit(0) }
            catch { fputs("SMOKE FAILED: \(error.localizedDescription)\n", stderr); exit(1) }
        }
        if CommandLine.arguments.contains("--diagnose") {
            for device in Hardware.devices() {
                print("DEVICE \(device.name) | uid=\(device.uid) | inputs=\(device.inputChannels) outputs=\(device.outputChannels) rate=\(device.sampleRate)")
            }
            for app in Hardware.sources() { print("APP \(app.name) | bundle=\(app.id) | processes=\(app.processes) | active=\(app.active)") }
            print("DEFAULT_OUTPUT \(Hardware.defaultDevice())")
            print("SELF_PROCESSES \(Hardware.selfProcesses())")
            exit(0)
        }
        _model = StateObject(wrappedValue: AudioController())
    }
    var body: some Scene {
        Window("OpenAudio", id: "main") {
            Workspace(model: model)
                .onAppear { delegate.model = model }
                .onOpenURL { model.automate($0) }
        }
        .defaultSize(width: 1160, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            VinylCommands()
            CommandGroup(after: .appInfo) {
                Button(model.enabled ? "Bypass audio control" : "Enable audio control") { model.toggleProcessing() }.keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }
        Window("OpenAudio · Vinyl", id: "vinyl") {
            VinylView(model: model, listening: model.listening)
        }.defaultSize(width: 1100, height: 780).windowStyle(.hiddenTitleBar)
        MenuBarExtra("OpenAudio", systemImage: model.enabled ? "slider.horizontal.3" : "speaker.wave.2") {
            CompactMixer(model: model)
        }.menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AudioController?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first { $0.title == "OpenAudio" }?.makeKeyAndOrderFront(nil) }
        return true
    }
}

struct CompactMixer: View {
    @ObservedObject var model: AudioController
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("OpenAudio").font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(model.enabled ? "Bypass" : "Enable") { model.toggleProcessing() }.controlSize(.small)
            }
            ScrollView {
                VStack(spacing: 0) {
                    AudioRow(model: model, id: systemRouteID, compact: true)
                    Divider()
                    ForEach(model.sources.filter { $0.active || model.settings($0.id).favorite }) { source in
                        AudioRow(model: model, id: source.id, compact: true)
                        Divider()
                    }
                }
            }.frame(maxHeight: 400)
            HStack {
                Button("Vinyl") { openWindow(id: "vinyl"); NSApplication.shared.activate(ignoringOtherApps: true) }
                Button("Open mixer") { openWindow(id: "main"); NSApplication.shared.activate(ignoringOtherApps: true) }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }.font(.system(size: 12))
        }.padding(18).frame(width: 320).background(Theme.canvas).tint(Theme.accent).preferredColorScheme(model.preferredColorScheme)
    }
}
