import SwiftUI
import AppKit

enum VinylFinish: String, CaseIterable {
    case cream = "Cream", ink = "Ink", album = "Album"
    var dark: Bool { self != .cream }
    var surface: Color { dark ? Color(red: 0.105, green: 0.11, blue: 0.12) : Color(red: 0.93, green: 0.925, blue: 0.91) }
    var foreground: Color { dark ? Color(white: 0.94) : Color(white: 0.13) }
    var secondary: Color { dark ? Color(white: 0.68) : Color(white: 0.43) }
}

enum VinylTint: String, CaseIterable {
    case cherry = "Cherry", smoke = "Smoke", honey = "Honey", jade = "Jade"
    var color: Color {
        switch self {
        case .cherry: return Color(red: 0.77, green: 0.16, blue: 0.24)
        case .smoke: return Color(red: 0.17, green: 0.20, blue: 0.23)
        case .honey: return Color(red: 0.68, green: 0.43, blue: 0.15)
        case .jade: return Color(red: 0.20, green: 0.47, blue: 0.39)
        }
    }
}

struct VinylStage: View {
    var artwork: NSImage?
    var title: String
    var artist: String
    var playing: Bool
    var artOnly: Bool
    var rpm: Double
    var finish: VinylFinish
    var tint: VinylTint
    var reducedMotion: Bool
    var confirmedPlaying = false
    @State private var motion = RecordMotion()
    @State private var animating = false
    @State private var settling: Task<Void, Never>?
    private var now: Double { ProcessInfo.processInfo.systemUptime }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !animating)) { context in
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let diameter = min(height * 0.91, width * 0.50)
                let recordX = width / 2 + diameter * 0.25
                let sleeveX = recordX - diameter * 0.65
                ZStack {
                    if artOnly {
                        VinylSleeve(artwork: artwork, title: title, artist: artist, finish: finish, flat: true)
                            .frame(width: min(height * 0.90, width * 0.78), height: min(height * 0.90, width * 0.78))
                    } else {
                        ZStack {
                            VinylDisc(artwork: artwork, tint: tint)
                                .rotationEffect(.degrees(motion.value(at: now)))
                                .frame(width: diameter, height: diameter)
                                .compositingGroup()
                                .shadow(color: .black.opacity(finish.dark ? 0.40 : 0.15), radius: 14, x: 1, y: 10)
                                .position(x: recordX, y: height * 0.51)
                            VinylSleeve(artwork: artwork, title: title, artist: artist, finish: finish, flat: false)
                                .frame(width: diameter * 0.86, height: diameter * 0.86)
                                .rotationEffect(.degrees(-5))
                                .position(x: sleeveX, y: height * 0.51)
                            Tonearm(length: diameter * 0.57, playing: confirmedPlaying, reducedMotion: reducedMotion)
                                .frame(width: 36, height: diameter * 0.68)
                                .position(x: recordX + diameter * 0.47, y: height * 0.51 - diameter * 0.34 + diameter * 0.34)
                            Circle().fill(Color(white: 0.85).gradient).frame(width: diameter * 0.012, height: diameter * 0.012)
                                .position(x: recordX, y: height * 0.51)
                        }.accessibilityHidden(true)
                    }
                }.frame(width: width, height: height)
            }
        }
        .onAppear { configure() }
        .onDisappear { settling?.cancel() }
        .onChange(of: playing) { _, _ in configure() }
        .onChange(of: artOnly) { _, _ in configure() }
        .onChange(of: rpm) { _, _ in configure() }
        .onChange(of: reducedMotion) { _, _ in configure() }
    }
    private func configure() {
        settling?.cancel()
        motion.configure(rpm: rpm, playing: playing && !artOnly, reduced: reducedMotion, at: now)
        animating = !artOnly && !reducedMotion && motion.moving(at: now)
        if !playing && animating {
            settling = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(8)) } catch { return }
                animating = false
            }
        }
    }
}

struct VinylSleeve: View {
    let artwork: NSImage?
    let title: String
    let artist: String
    let finish: VinylFinish
    let flat: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle().fill(Color(red: 0.98, green: 0.97, blue: 0.94))
                if let artwork {
                    Image(nsImage: artwork).resizable().scaledToFit().padding(4)
                } else {
                    VStack(alignment: .leading, spacing: max(4, geometry.size.width * 0.024)) {
                        Text("OPENAUDIO").font(.system(size: max(9, geometry.size.width * 0.024), weight: .semibold)).tracking(2)
                        Spacer()
                        Image(systemName: "square.stack").font(.system(size: geometry.size.width * 0.13, weight: .ultraLight)).foregroundStyle(Color(white: 0.55))
                        Text("Stay\nawhile.").font(.system(size: geometry.size.width * 0.105, weight: .regular, design: .serif)).lineSpacing(-2).fixedSize(horizontal: false, vertical: true)
                        Text("Cover not available yet").font(.system(size: max(11, geometry.size.width * 0.033))).foregroundStyle(Color(white: 0.4))
                        Spacer()
                        Rectangle().fill(Color(white: 0.75)).frame(height: 0.5)
                        Text(artist.isEmpty ? title : artist).font(.system(size: max(10, geometry.size.width * 0.029), weight: .medium)).lineLimit(2)
                    }.foregroundStyle(Color(white: 0.18)).padding(geometry.size.width * 0.09)
                }
                Rectangle().strokeBorder(.white.opacity(0.7), lineWidth: 1)
                HStack(spacing: 0) {
                    Rectangle().fill(.black.opacity(0.045)).frame(width: 3)
                    Spacer()
                    Rectangle().fill(.white.opacity(0.5)).frame(width: 1)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(finish.dark ? 0.3 : 0.15), radius: flat ? 14 : 9, x: flat ? 0 : 7, y: flat ? 12 : 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(artwork == nil ? "Album cover unavailable" : "Album cover for \(title)")
    }
}

private struct VinylDisc: View {
    let artwork: NSImage?
    let tint: VinylTint
    var body: some View {
        GeometryReader { geometry in
            let diameter = geometry.size.width
            ZStack {
                Circle().fill(tint.color.gradient)
                Circle().fill(RadialGradient(colors: [.white.opacity(0.06), .clear, .black.opacity(0.10)], center: .center, startRadius: diameter * 0.17, endRadius: diameter * 0.50))
                Canvas { context, size in
                    for index in 0..<115 {
                        let radius = size.width * (0.195 + Double(index) * 0.00258)
                        let rect = CGRect(x: size.width / 2 - radius, y: size.height / 2 - radius, width: radius * 2, height: radius * 2)
                        context.stroke(Path(ellipseIn: rect), with: .color(index % 9 == 0 ? .black.opacity(0.13) : .white.opacity(0.095)), lineWidth: index % 9 == 0 ? 0.7 : 0.4)
                    }
                    for index in 0..<170 {
                        let angle = Double(index * 97 % 360) * .pi / 180
                        let radius = size.width * (0.2 + Double(index * 37 % 270) / 1000)
                        let point = CGPoint(x: size.width / 2 + cos(angle) * radius, y: size.height / 2 + sin(angle) * radius)
                        context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 0.8, height: 0.8)), with: .color(.white.opacity(0.07)))
                    }
                }
                Circle().fill(AngularGradient(colors: [.clear, .white.opacity(0.15), .clear, .black.opacity(0.03), .clear, .white.opacity(0.07), .clear], center: .center))
                ZStack {
                    Circle().fill(Color(red: 0.97, green: 0.95, blue: 0.89))
                    if let artwork { Image(nsImage: artwork).resizable().scaledToFill().opacity(0.93) }
                    else {
                        VStack(spacing: 5) {
                            Text("oa").font(.system(size: diameter * 0.12, weight: .medium, design: .serif)).tracking(-4)
                            Text("OPENAUDIO").font(.system(size: diameter * 0.018, weight: .semibold)).tracking(2)
                        }.foregroundStyle(tint.color)
                    }
                }.frame(width: diameter * 0.32, height: diameter * 0.32).clipShape(Circle())
                Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.8)
                Circle().strokeBorder(.black.opacity(0.12), lineWidth: 2).padding(2)
                Circle().fill(Color(white: 0.12)).frame(width: diameter * 0.025, height: diameter * 0.025)
            }
        }
    }
}

private struct Tonearm: View {
    let length: CGFloat
    let playing: Bool
    let reducedMotion: Bool
    var body: some View {
        ZStack(alignment: .top) {
            Circle().fill(Color(white: 0.71).gradient).frame(width: 38, height: 38)
                .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1)).shadow(color: .black.opacity(0.10), radius: 3, y: 2)
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.94).gradient).frame(width: 23, height: 29)
                Rectangle().fill(LinearGradient(colors: [Color(white: 0.60), .white, Color(white: 0.68)], startPoint: .leading, endPoint: .trailing)).frame(width: 6, height: max(20, length - 35))
                RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.94).gradient).frame(width: 17, height: 30)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color(white: 0.30)).frame(width: 5, height: 4).offset(y: 3) }
            }.offset(y: -10).rotationEffect(.degrees(playing ? 31 : -10), anchor: .init(x: 0.5, y: 0.07))
                .shadow(color: .black.opacity(0.19), radius: 2, x: 3, y: 5)
                .animation(reducedMotion ? nil : .spring(response: 1.0, dampingFraction: 0.94), value: playing)
        }
    }
}
