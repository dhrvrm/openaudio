import AppKit
import ApplicationServices

@MainActor
final class VolumeKeyController {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let action: (Float, Bool) -> Void
    init(action: @escaping (Float, Bool) -> Void) { self.action = action }
    func start(prompt: Bool) -> Bool {
        if tap != nil { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return false }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(1 << 14), callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<VolumeKeyController>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }
            let key = (ns.data1 & 0xFFFF0000) >> 16
            guard key == 0 || key == 1 || key == 7 else { return Unmanaged.passUnretained(event) }
            let down = ((ns.data1 & 0xFF00) >> 8) == 0xA
            if down { Task { @MainActor in controller.action(key == 0 ? 1 / 16 : -1 / 16, key == 7) } }
            return nil
        }, userInfo: context) else { return false }
        tap = port; source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }
    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil; tap = nil
    }
}
