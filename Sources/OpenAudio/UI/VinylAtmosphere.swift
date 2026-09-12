import SwiftUI
import AppKit

enum VinylMood: String, CaseIterable {
    case warm = "Warm", night = "After dark", nature = "Nature"
    var resource: String { self == .night ? "Night" : rawValue }
    var photographer: String {
        switch self {
        case .warm: return "Braden Jarvis"
        case .night: return "Nathan Anderson"
        case .nature: return "Thom Milkovic"
        }
    }
    var page: URL {
        let id: String
        switch self {
        case .warm: id = "ih5Kq0XowwY"
        case .night: id = "OQKQzw4o8cU"
        case .nature: id = "xPmdw_RliUA"
        }
        return URL(string: "https://unsplash.com/photos/\(id)")!
    }
    @MainActor var image: NSImage? { VinylPhotos.images[self] }
}

@MainActor
private enum VinylPhotos {
    static let images: [VinylMood: NSImage] = Dictionary(uniqueKeysWithValues: VinylMood.allCases.compactMap { mood in
        guard let url = Bundle.main.url(forResource: mood.resource, withExtension: "jpg", subdirectory: "Moods"), let image = NSImage(contentsOf: url), image.isValid else { return nil }
        return (mood, image)
    })
}

struct VinylAtmosphere: View {
    let image: NSImage?
    let finish: VinylFinish
    let reducedTransparency: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                finish.surface
                if let image, !reducedTransparency {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped().saturation(0.65)
                    finish.surface.opacity(finish.dark ? 0.45 : 0.64)
                    LinearGradient(stops: [.init(color: finish.surface.opacity(0.92), location: 0), .init(color: .clear, location: 0.28), .init(color: .clear, location: 0.65), .init(color: finish.surface.opacity(0.98), location: 0.87)], startPoint: .top, endPoint: .bottom)
                }
            }
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}
