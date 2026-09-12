import Foundation
import AudioDSP

@main
struct TestRunner {
    static var count = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        count += 1
        guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
        print("PASS: \(message)")
    }
    static func close(_ lhs: Float, _ rhs: Float) -> Bool { abs(lhs - rhs) < 0.0001 }
    static func render(gain: Float = 1, muted: Bool = false, balance: Float = 0, sample: Float = 0.2) -> (Float, Float) {
        let dsp = OACreate(48000, 0)!
        defer { OADestroy(dsp) }
        OASetGain(dsp, gain, muted, balance)
        var left = [Float](repeating: sample, count: 4096), right = left
        left.withUnsafeMutableBufferPointer { l in right.withUnsafeMutableBufferPointer { r in OAProcess(dsp, l.baseAddress, r.baseAddress, 4096) } }
        return (left.last!, right.last!)
    }
    static func main() throws {
        let dormant = AudioSource(id: "dormant", name: "Dormant", processes: [1], pid: 1, active: false, iconURL: URL(fileURLWithPath: "/Applications/Dormant.app"))
        let playing = AudioSource(id: "playing", name: "Playing", processes: [2], pid: 2, active: true, iconURL: nil)
        check(visibleSourceIDs(sources: [dormant, playing], routes: ["dormant": RouteSettings()], recent: [], showBackground: false) == ["playing"], "registered silent app and neutral saved settings stay hidden")
        check(visibleSourceIDs(sources: [dormant], routes: [:], recent: ["dormant"], showBackground: false) == ["dormant"], "recent output activity remains visible")
        check(visibleSourceIDs(sources: [dormant], routes: [:], recent: [], showBackground: true) == ["dormant"], "background filter reveals registered sources explicitly")
        var saved = RouteSettings(); saved.favorite = true
        check(visibleSourceIDs(sources: [], routes: ["saved": saved], recent: [], showBackground: false) == ["saved"], "deliberately saved source remains visible when absent")

        let oldPreferences = try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8))
        check(oldPreferences.softwareVolumes.isEmpty && !oldPreferences.processingEnabled, "older preferences receive safe defaults")
        let missing = RouteSettings(outputs: ["missing"])
        check(missing.resolveOutputs(available: ["speakers"], defaultUID: "speakers").isEmpty, "missing explicit destination suspends")
        check(missing.outputs == ["missing"], "missing preference retained")
        check(RouteSettings().resolveOutputs(available: ["speakers"], defaultUID: "speakers") == ["speakers"], "default route follows system")
        check(RouteSettings(outputs: ["speakers", "missing"]).resolveOutputs(available: ["speakers"], defaultUID: "speakers").isEmpty, "partially missing group suspends")
        var route = RouteSettings()
        route.volume = .infinity; route.balance = -8; route.eq = [.nan, 80]; route.outputs = ["a", "a", ""]
        route.validate()
        check(route.volume == 1 && route.balance == -1, "unsafe gain and balance normalized")
        check(route.eq.count == 10 && route.eq.allSatisfy { $0.isFinite && abs($0) <= 12 }, "EQ values bounded and padded")
        check(route.outputs == ["a"], "destination identities deduplicated")
        let decoded = try JSONDecoder().decode(RouteSettings.self, from: JSONEncoder().encode(route))
        check(decoded == route, "route persistence round trip")
        check(!RouteSettings().needsProcessing, "neutral route does not intercept")
        check(RouteSettings(outputs: ["usb"]).needsProcessing, "explicit destination intercepts")
        check(close(render().0, 0.2) && close(render().1, 0.2), "unity stereo preserves signal")
        check(close(render(gain: 0.25).0, 0.05), "gain attenuates signal")
        check(close(render(muted: true).0, 0), "mute reaches silence")
        check(close(render(balance: 1).0, 0) && close(render(balance: 1).1, 0.2), "right balance preserves only right")
        check(close(render(balance: -1).1, 0), "left balance silences right")
        check(render(sample: .nan).0 == 0, "nonfinite input produces silence")
        check(abs(render(gain: 4, sample: 0.8).0) <= 1, "overdrive bounded at full scale")
        func power(_ eq: Bool) -> Double {
            let dsp = OACreate(48000, 0)!; defer { OADestroy(dsp) }
            OASetEQ(dsp, 5, 12, eq)
            var l = (0..<4096).map { Float(sin(Double($0) * 2 * .pi * 1000 / 48000) * 0.05) }, r = l
            l.withUnsafeMutableBufferPointer { left in r.withUnsafeMutableBufferPointer { right in OAProcess(dsp, left.baseAddress, right.baseAddress, 4096) } }
            return l.suffix(2048).reduce(0) { $0 + Double($1 * $1) }
        }
        check(power(true) > power(false) * 5, "1 kHz EQ amplifies target frequency")
        check(OACreate(0, 0) == nil && OACreate(.nan, 0) == nil, "invalid sample rate rejected")
        let mutedDSP = OACreate(48000, 0)!
        OAInitializeGain(mutedDSP, 1, true, 0)
        var firstL: Float = 1, firstR: Float = 1
        OAProcess(mutedDSP, &firstL, &firstR, 1)
        check(firstL == 0 && firstR == 0, "saved mute is silent from first sample")
        OADestroy(mutedDSP)
        let effectDSP = OACreate(48000, 0)!
        let effect = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_LowPassFilter, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        check(OAAddEffect(effectDSP, effect) == 0, "Apple Audio Unit effect initializes")
        var effectL = [Float](repeating: 0.2, count: 4096), effectR = effectL
        effectL.withUnsafeMutableBufferPointer { l in effectR.withUnsafeMutableBufferPointer { r in OAProcess(effectDSP,l.baseAddress,r.baseAddress,4096) } }
        check(OAError(effectDSP) == 0 && effectL.allSatisfy { $0.isFinite } && abs(effectL.last!) > 0.01, "Audio Unit receives and renders stereo signal")
        OADestroy(effectDSP)
        try callbackChecks()
        print("\(count) checks passed")
    }
    static func callbackChecks() throws {
        let dsp = OACreate(48000, 2)!
        defer { OADestroy(dsp) }
        var inputSamples: [Float] = [0.9, 0.9, 0.1, 0.2, 0.8, 0.8, 0.3, 0.4]
        var outputSamples: [Float] = [9,9,9,9]
        inputSamples.withUnsafeMutableBytes { inputBytes in
            outputSamples.withUnsafeMutableBytes { outputBytes in
                var input = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(inputBytes.count), mData: inputBytes.baseAddress))
                var output = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(outputBytes.count), mData: outputBytes.baseAddress))
                var time = AudioTimeStamp()
                withUnsafePointer(to: &time) { timestamp in
                    _ = OAIOProc(0, timestamp, &input, timestamp, &output, timestamp, UnsafeMutableRawPointer(dsp))
                }
            }
        }
        check(close(outputSamples[0],0.1) && close(outputSamples[1],0.2) && close(outputSamples[2],0.3), "callback extracts intended channels")
        check(OAFrames(dsp) == 2, "callback records delivered frames")
        OASetOutputMap(dsp, 0, 2)
        var mono: [Float] = [9,9]
        inputSamples.withUnsafeMutableBytes { inputBytes in
            mono.withUnsafeMutableBytes { outputBytes in
                var input = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(inputBytes.count), mData: inputBytes.baseAddress))
                var output = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(outputBytes.count), mData: outputBytes.baseAddress))
                var time = AudioTimeStamp()
                withUnsafePointer(to: &time) { timestamp in _ = OAIOProc(0, timestamp, &input, timestamp, &output, timestamp, UnsafeMutableRawPointer(dsp)) }
            }
        }
        check(close(mono[0],0.15) && close(mono[1],0.35), "mono output contains both stereo channels")
        OASetOutputGain(dsp, 0, 0)
        inputSamples.withUnsafeMutableBytes { inputBytes in
            mono.withUnsafeMutableBytes { outputBytes in
                var input = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(inputBytes.count), mData: inputBytes.baseAddress))
                var output = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(outputBytes.count), mData: outputBytes.baseAddress))
                var time = AudioTimeStamp()
                withUnsafePointer(to: &time) { timestamp in _ = OAIOProc(0, timestamp, &input, timestamp, &output, timestamp, UnsafeMutableRawPointer(dsp)) }
            }
        }
        check(mono.allSatisfy { $0 == 0 }, "software output mute silences destination")
    }

}
