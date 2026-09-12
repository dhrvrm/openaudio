import SwiftUI

struct RouteEditor: View {
    @ObservedObject var model: AudioController
    let routeID: String
    @State private var eqPreset = "Custom"
    var route: RouteSettings { model.settings(routeID) }
    private func binding<T>(_ key: WritableKeyPath<RouteSettings, T>) -> Binding<T> {
        Binding(get: { route[keyPath: key] }, set: { value in model.edit(routeID) { $0[keyPath: key] = value } })
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.name(routeID)).font(.system(size: 20, weight: .semibold))
                        Text("Audio adjustments").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { model.edit(routeID) { $0.favorite.toggle() } } label: {
                        Image(systemName: route.favorite ? "star.fill" : "star").foregroundStyle(route.favorite ? Color.orange : Color.secondary)
                    }.buttonStyle(.plain).help("Favorite application")
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "OUTPUT")
                    Toggle("Follow system default", isOn: Binding(get: { route.outputs.isEmpty }, set: { value in
                        model.edit(routeID) { $0.outputs = value ? [] : model.defaultUID.map { [$0] } ?? [] }
                    }))
                    ForEach(model.outputs) { device in
                        Toggle(isOn: Binding(get: { route.outputs.contains(device.uid) }, set: { selected in
                            model.edit(routeID) { r in
                                if selected { r.outputs.append(device.uid) } else { r.outputs.removeAll { $0 == device.uid } }
                            }
                        })) { Label(device.name, systemImage: device.icon).lineLimit(2) }
                    }
                    ForEach(route.outputs.filter { uid in !model.outputs.contains { $0.uid == uid } }, id: \.self) { uid in
                        HStack {
                            Label("Unavailable output", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                            Spacer()
                            Button("Remove") { model.edit(routeID) { $0.outputs.removeAll { $0 == uid } } }
                        }.help(uid)
                    }
                    Text("Select multiple devices to play on them together. Network and Bluetooth timing depends on the devices.").font(.system(size: 11)).foregroundStyle(.secondary)
                }.toggleStyle(.checkbox).font(.system(size: 12))
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "BALANCE & GAIN")
                    HStack {
                        Text("L"); Slider(value: binding(\.balance), in: -1...1).accessibilityLabel("Stereo balance"); Text("R")
                        Button { model.edit(routeID) { $0.balance = 0 } } label: { Image(systemName: "arrow.counterclockwise") }.buttonStyle(.plain).help("Center balance")
                    }.font(.system(size: 11))
                    HStack { Text("Boost"); Spacer(); Text(String(format: "+%.0f dB", route.boost)).monospacedDigit().foregroundStyle(.secondary) }.font(.system(size: 12))
                    Slider(value: binding(\.boost), in: 0...12, step: 1).accessibilityLabel("Volume boost")
                    Text("Output is capped at full scale. Reduce boost if loud passages sound distorted.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionLabel(title: "10-BAND EQUALIZER")
                        Toggle("Equalizer", isOn: binding(\.eqEnabled)).labelsHidden().toggleStyle(.switch).controlSize(.mini).accessibilityLabel("Enable equalizer")
                    }
                    Menu("Presets") {
                        Button("Flat") { preset(Array(repeating: 0, count: 10)) }
                        Button("Speech clarity") { preset([-5,-3,-1,0,1,2,3,2,0,-2]) }
                        Button("Bass lift") { preset([5,4,3,1,0,0,0,0,0,0]) }
                        Button("Gentle treble") { preset([0,0,0,0,0,-1,-2,-3,-4,-5]) }
                    }.menuStyle(.borderlessButton)
                    ForEach(0..<10, id: \.self) { index in
                        HStack(spacing: 8) {
                            Text(eqFrequencies[index] < 1000 ? "\(Int(eqFrequencies[index]))" : "\(Int(eqFrequencies[index] / 1000))k")
                                .font(.system(size: 10, design: .monospaced)).frame(width: 28, alignment: .trailing)
                            Slider(value: Binding(get: { route.eq[index] }, set: { value in model.edit(routeID) { $0.eq[index] = value } }), in: -12...12, step: 0.5)
                                .accessibilityLabel("\(Int(eqFrequencies[index])) hertz gain")
                            Text(String(format: "%+.0f", route.eq[index])).font(.system(size: 10, design: .monospaced)).frame(width: 23)
                        }
                    }.disabled(!route.eqEnabled)
                    Text("Headphone correction: set the bands for your headphones, then save a listening profile.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "AUDIO UNIT EFFECTS")
                    ForEach(Array(route.effects.enumerated()), id: \.element.id) { index, effect in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(effect.name).font(.system(size: 12, weight: .medium))
                                Spacer()
                                Button { model.edit(routeID) { $0.effects[index].bypass.toggle() } } label: {
                                    Image(systemName: effect.bypass ? "power.circle" : "power.circle.fill")
                                }.help(effect.bypass ? "Enable effect" : "Bypass effect")
                                if index > 0 { Button { model.edit(routeID) { $0.effects.swapAt(index, index - 1) } } label: { Image(systemName: "arrow.up") }.help("Move effect earlier") }
                                Button { model.edit(routeID) { $0.effects.removeAll { $0.id == effect.id } } } label: { Image(systemName: "xmark") }.help("Remove effect")
                            }.buttonStyle(.plain)
                            let parameters = model.parameters(routeID, effectID: effect.id)
                            if parameters.isEmpty {
                                Text(effect.bypass ? "Bypassed" : "Enable audio control to load effect parameters.").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            ForEach(parameters) { parameter in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack { Text(parameter.name); Spacer(); Text(String(format: "%.2f", effect.parameters[String(parameter.id)] ?? parameter.value)).monospacedDigit() }.font(.system(size: 10))
                                    Slider(value: Binding(get: { effect.parameters[String(parameter.id)] ?? parameter.value }, set: { value in
                                        model.edit(routeID) { r in if let i = r.effects.firstIndex(where: { $0.id == effect.id }) { r.effects[i].parameters[String(parameter.id)] = value } }
                                    }), in: parameter.minimum...parameter.maximum).accessibilityLabel(parameter.name)
                                }
                            }
                        }.padding(.vertical, 8)
                        Divider()
                    }
                    Menu {
                        ForEach(model.effects) { effect in
                            Button(effect.name) { model.edit(routeID) { r in var new = effect; new.id = UUID(); r.effects.append(new) } }
                        }
                    } label: { Label("Add effect", systemImage: "plus") }.disabled(route.effects.count >= 8)
                    Text("Stereo Audio Unit effects, processed from top to bottom.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                HStack {
                    Button("Reset adjustments") { model.reset(routeID) }
                    Spacer()
                    Button("Retry") { model.retry(routeID) }
                }.font(.system(size: 11))
            }.padding(24)
        }.id(routeID)
    }
    private func preset(_ values: [Float]) { model.edit(routeID) { $0.eq = values; $0.eqEnabled = true } }
}
