import SwiftUI
import AppKit

enum Theme {
    static let accent = adaptive(0x2F78D0, 0x6FA8EA)
    static let canvas = adaptive(0xFEFEFE, 0x1E2024)
    static let sidebar = adaptive(0xF4F5F7, 0x191B1F)
    static let selection = adaptive(0xE1E8F1, 0x303A47)
    static let separator = adaptive(0xECEDEF, 0x343840)
    static let raised = adaptive(0xFFFFFF, 0x292C32)
    static func adaptive(_ light: Int, _ dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

struct SourceIcon: View {
    let source: AudioSource?
    var size: CGFloat = 32
    var body: some View {
        Group {
            if let url = source?.iconURL { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable() }
            else { Image(systemName: source == nil ? "waveform" : "app.fill").resizable().scaledToFit().padding(5).foregroundStyle(Theme.accent) }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct LevelMeter: View {
    let value: Float
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.separator)
                Capsule().fill(value > 0.95 ? Color.orange : Theme.accent).frame(width: geometry.size.width * CGFloat(min(1, max(0, value))))
            }
        }.frame(height: 3).accessibilityLabel("Audio level").accessibilityValue("\(Int(value * 100)) percent")
    }
}

struct SectionLabel: View {
    let title: String
    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).fixedSize(horizontal: true, vertical: false)
            Rectangle().fill(Theme.separator).frame(height: 1)
        }
    }
}
