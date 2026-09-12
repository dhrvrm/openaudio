import AppKit
import SwiftUI

@MainActor
extension Diagnostics {
    static func snapshot(path: String) {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let model = AudioController(startMonitoring: false)
        model.enabled = false
        model.refresh()
        if CommandLine.arguments.contains("--light") { model.preferences.appearance = "light" }
        if CommandLine.arguments.contains("--dark") { model.preferences.appearance = "dark" }
        let hosting = NSHostingView(rootView: Workspace(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: 1160, height: 800)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        if let data = bitmap.representation(using: .png, properties: [:]) { try? data.write(to: URL(fileURLWithPath: path)) }
        window.close()
    }
}
