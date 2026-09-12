import SwiftUI
import AppKit

@main struct RenderVinyl {
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let cover = NSImage(size: NSSize(width: 600, height: 600), flipped: false) { rect in
            NSColor(calibratedRed: 0.19, green: 0.28, blue: 0.29, alpha: 1).setFill()
            rect.fill()
            NSColor(calibratedRed: 0.89, green: 0.64, blue: 0.40, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 165, y: 180, width: 330, height: 330)).fill()
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 49, weight: .light), .foregroundColor: NSColor.white]
            NSString(string: "SLOW AFTERNOONS").draw(at: NSPoint(x: 32, y: 68), withAttributes: attributes)
            return true
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, width, height, finish, missing, artOnly) in [
            ("cream", 1100.0, 490.0, VinylFinish.cream, false, false),
            ("compact", 820.0, 330.0, .cream, false, false),
            ("ink-missing", 1100.0, 490.0, .ink, true, false),
            ("artwork-missing", 820.0, 330.0, .cream, true, true),
            ("wide-short", 1320.0, 250.0, .cream, false, false)
        ] {
            let stage = VinylStage(artwork: missing ? nil : cover, title: "Slow afternoons", artist: "Preview artwork", playing: true, artOnly: artOnly, rpm: 6, finish: finish, tint: .cherry, reducedMotion: true, confirmedPlaying: true)
                .frame(width: width, height: height).background(VinylAtmosphere(image: missing ? NSImage(contentsOfFile: CommandLine.arguments[2]) : nil, finish: finish, reducedTransparency: false))
            let renderer = ImageRenderer(content: stage)
            renderer.scale = 2
            guard let cg = renderer.cgImage else { fatalError("Could not render \(name)") }
            let bitmap = NSBitmapImageRep(cgImage: cg)
            try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
        }
    }
}
