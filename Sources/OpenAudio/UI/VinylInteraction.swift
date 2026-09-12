import SwiftUI
import AppKit

struct VinylButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        VinylButtonLabel(label: configuration.label, pressed: configuration.isPressed)
    }
}

private struct VinylButtonLabel<Label: View>: View {
    let label: Label
    let pressed: Bool
    @Environment(\.isEnabled) private var enabled
    @State private var hovered = false
    var body: some View {
        label.padding(.horizontal, 6).frame(minWidth: 32, minHeight: 36)
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .background(.primary.opacity(enabled ? (pressed ? 0.12 : hovered ? 0.065 : 0) : 0), in: RoundedRectangle(cornerRadius: 7))
            .opacity(enabled ? 1 : 0.35)
            .onHover { value in
                hovered = value
                (value && enabled ? NSCursor.pointingHand : NSCursor.arrow).set()
            }
            .onChange(of: enabled) { _, value in if hovered && !value { NSCursor.arrow.set() } }
    }
}

struct VinylPointer: ViewModifier {
    @Environment(\.isEnabled) private var enabled
    func body(content: Content) -> some View {
        content.onHover { value in (value && enabled ? NSCursor.pointingHand : NSCursor.arrow).set() }
    }
}

extension View {
    func vinylPointer() -> some View { modifier(VinylPointer()) }
}
