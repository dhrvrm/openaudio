import SwiftUI
import CoreAudio

struct DeviceView: View {
    @ObservedObject var model: AudioController
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Connected devices").font(.system(size: 36, weight: .bold))
                Text("Choose defaults and adjust the controls your hardware supports.").font(.system(size: 14)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 16) {
                    Picker("System output", selection: Binding(get: { model.defaultOutput }, set: { model.setDefault($0, selector: kAudioHardwarePropertyDefaultOutputDevice) })) {
                        ForEach(model.outputs) { Text($0.name).tag($0.id) }
                    }
                    Picker("Sound effects", selection: Binding(get: { model.defaultEffects }, set: { model.setDefault($0, selector: kAudioHardwarePropertyDefaultSystemOutputDevice) })) {
                        ForEach(model.outputs) { Text($0.name).tag($0.id) }
                    }
                    Picker("Microphone", selection: Binding(get: { model.defaultInput }, set: { model.setDefault($0, selector: kAudioHardwarePropertyDefaultInputDevice) })) {
                        ForEach(model.inputs) { Text($0.name).tag($0.id) }
                    }
                }
                SectionLabel(title: "AVAILABLE DEVICES")
                ForEach(model.devices) { device in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: device.icon).font(.system(size: 24)).foregroundStyle(Theme.accent).frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name).font(.system(size: 16, weight: .medium))
                                Text("\(device.outputChannels) output · \(device.inputChannels) input channels").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !device.rates.isEmpty {
                                Picker("Sample rate", selection: Binding(get: { device.sampleRate }, set: { model.setRate(device, rate: $0) })) {
                                    ForEach(Array(Set(device.rates + [device.sampleRate])).sorted(), id: \.self) { rate in Text(String(format: "%.1f kHz", rate / 1000)).tag(rate) }
                                }.frame(width: 170).disabled(!Hardware.writable(device.id, kAudioDevicePropertyNominalSampleRate))
                            }
                        }
                        if device.outputChannels > 0 { level(device, input: false) }
                        if device.inputChannels > 0 { level(device, input: true) }
                    }.padding(.vertical, 4)
                    Divider()
                }
                Button("Open Audio MIDI Setup") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Audio MIDI Setup.app")) }
            }.padding(36)
        }
    }
    private func level(_ device: AudioDevice, input: Bool) -> some View {
        let volume = input ? device.inputVolume : device.outputVolume
        let muted = input ? device.inputMuted : device.outputMuted
        return HStack(spacing: 16) {
            Text(input ? "Input level" : "Output level").font(.system(size: 12)).frame(width: 80, alignment: .leading)
            if let volume {
                Slider(value: Binding(get: { volume }, set: { model.deviceVolume(device, volume: $0, input: input) }), in: 0...1).accessibilityLabel("\(device.name) \(input ? "input" : "output") level")
                Text("\(Int(volume * 100))%").font(.system(size: 11, design: .monospaced)).frame(width: 36)
            } else {
                if input {
                    Text("Level controlled by device").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                } else {
                    Slider(value: Binding(get: { model.preferences.softwareVolumes[device.uid] ?? 1 }, set: { model.setSoftwareVolume(device.uid, $0) }), in: 0...1).accessibilityLabel("\(device.name) software volume")
                    Text("Software").font(.system(size: 10)).foregroundStyle(.secondary).help("Controls audio routed by OpenAudio, including other audio on the default output.")
                }
            }
            if let muted {
                Toggle("Mute", isOn: Binding(get: { muted }, set: { model.deviceMute(device, muted: $0, input: input) })).toggleStyle(.checkbox).font(.system(size: 11))
            } else if !input {
                Toggle("Mute", isOn: Binding(get: { model.preferences.softwareMutes.contains(device.uid) }, set: { model.setSoftwareMute(device.uid, $0) })).toggleStyle(.checkbox).font(.system(size: 11))
            }
        }
    }
}
