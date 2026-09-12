import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        NSColor(srgbRed: 0.18, green: 0.45, blue: 0.79, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 210, yRadius: 210).fill()
        for (y, knob) in [(330.0, 650.0), (512.0, 390.0), (694.0, 560.0)] {
            NSColor.white.withAlphaComponent(0.7).setStroke()
            let line = NSBezierPath(); line.lineWidth = 38; line.lineCapStyle = .round
            line.move(to: NSPoint(x: 248, y: y)); line.line(to: NSPoint(x: 776, y: y)); line.stroke()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: knob - 59, y: y - 59, width: 118, height: 118)).fill()
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
