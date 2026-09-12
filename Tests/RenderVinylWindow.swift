import SwiftUI
import AppKit

@main struct RenderVinylWindow {
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let model = AudioController(storageURL: output.appendingPathComponent("no-preferences.json"), startMonitoring: false)
        let track = MediaTrack(title: "A very long song title — the extended evening session", artist: "A musician with a rather long name", album: "An album for slow afternoons", duration: 245, position: 82, playing: true, updatedAt: Date().timeIntervalSince1970, provider: "Preview player", commands: ["playpause", "next", "previous"])
        for (name, width, height, media) in [("window-compact", 820.0, 640.0, track as MediaTrack?), ("window-missing", 1100.0, 780.0, nil)] {
            model.listening.update([ListeningSource(id: "preview-tab", name: "Preview tab | Music", appID: "preview", session: "preview-session", tabID: 7, active: true, track: media, lifetime: "preview-document")])
            let view = VinylView(model: model, listening: model.listening).frame(width: width, height: height)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: width, height: height)
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("Window render failed") }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))

        }
    }
}
