import Foundation
import CoreAudio

struct EffectChoice: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var type: UInt32
    var subtype: UInt32
    var manufacturer: UInt32
    var bypass = false
    var parameters: [String: Float] = [:]
}

struct RouteSettings: Codable, Equatable {
    var outputs: [String] = []
    var volume: Float = 1
    var muted = false
    var balance: Float = 0
    var eqEnabled = false
    var eq: [Float] = Array(repeating: 0, count: 10)
    var boost: Float = 0
    var effects: [EffectChoice] = []
    var favorite = false

    var needsProcessing: Bool {
        !outputs.isEmpty || volume != 1 || muted || balance != 0 || eqEnabled || boost != 0 || effects.contains { !$0.bypass }
    }
    mutating func validate() {
        volume = volume.isFinite ? min(4, max(0, volume)) : 1
        balance = balance.isFinite ? min(1, max(-1, balance)) : 0
        boost = boost.isFinite ? min(12, max(0, boost)) : 0
        eq = (0..<10).map { i in i < eq.count && eq[i].isFinite ? min(12, max(-12, eq[i])) : 0 }
        var seen = Set<String>()
        outputs = outputs.filter { !$0.isEmpty && seen.insert($0).inserted }
        effects = Array(effects.prefix(8))
        for i in effects.indices { effects[i].parameters = effects[i].parameters.filter { $0.value.isFinite } }
    }
    func resolveOutputs(available: Set<String>, defaultUID: String?) -> [String] {
        let desired = outputs.isEmpty ? defaultUID.map { [$0] } ?? [] : outputs
        return desired.allSatisfy { available.contains($0) } ? desired : []
    }
}

struct ListeningProfile: Codable, Identifiable {
    var id = UUID()
    var name: String
    var routes: [String: RouteSettings]
}

struct Preferences: Codable {
    var routes: [String: RouteSettings] = [:]
    var names: [String: String] = [:]
    var profiles: [ListeningProfile] = []
    var appearance = "system"
    var volumeKeys = false
    var processingEnabled = false
    var softwareVolumes: [String: Float] = [:]
    var softwareMutes: Set<String> = []

    init() {}
    enum CodingKeys: String, CodingKey { case routes, names, profiles, appearance, volumeKeys, processingEnabled, softwareVolumes, softwareMutes }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        routes = try c.decodeIfPresent([String: RouteSettings].self, forKey: .routes) ?? [:]
        names = try c.decodeIfPresent([String: String].self, forKey: .names) ?? [:]
        profiles = try c.decodeIfPresent([ListeningProfile].self, forKey: .profiles) ?? []
        appearance = try c.decodeIfPresent(String.self, forKey: .appearance) ?? "system"
        volumeKeys = try c.decodeIfPresent(Bool.self, forKey: .volumeKeys) ?? false
        processingEnabled = try c.decodeIfPresent(Bool.self, forKey: .processingEnabled) ?? false
        softwareVolumes = try c.decodeIfPresent([String: Float].self, forKey: .softwareVolumes) ?? [:]
        softwareVolumes = softwareVolumes.mapValues { $0.isFinite ? min(1, max(0, $0)) : 1 }
        softwareMutes = try c.decodeIfPresent(Set<String>.self, forKey: .softwareMutes) ?? []
    }
}

struct AudioSource: Identifiable {
    var id: String
    var name: String
    var processes: [AudioObjectID]
    var pid: pid_t
    var active: Bool
    var iconURL: URL?
}

func visibleSourceIDs(sources: [AudioSource], routes: [String: RouteSettings], recent: Set<String>, showBackground: Bool) -> Set<String> {
    let selected = routes.filter { $0.key != systemRouteID && ($0.value.needsProcessing || $0.value.favorite) }.map(\.key)
    let current = sources.filter { showBackground || $0.active || recent.contains($0.id) }.map(\.id)
    return Set(current + selected)
}

struct AudioDevice: Identifiable, Equatable {
    var id: AudioObjectID
    var uid: String
    var name: String
    var inputChannels: Int
    var outputChannels: Int
    var sampleRate: Double
    var rates: [Double]
    var outputVolume: Float?
    var inputVolume: Float?
    var outputMuted: Bool?
    var inputMuted: Bool?
    var transport: UInt32
    var icon: String {
        if transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE { return "headphones" }
        if transport == kAudioDeviceTransportTypeAirPlay { return "airplay.audio" }
        return outputChannels > 0 ? "hifispeaker.fill" : "mic.fill"
    }
}

struct RouteObservation {
    var text = "Native playback"
    var active = false
    var failure = false
    var peak: Float = 0
}

let systemRouteID = "__system__"
let eqFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
