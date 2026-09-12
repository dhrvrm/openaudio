import SwiftUI
import AppKit

@MainActor
final class VinylWindowState: ObservableObject {
    @Published private(set) var attached = false
    @Published private(set) var fullScreen = false
    @Published private(set) var transitioning = false
    @Published private(set) var failure: String?
    private weak var window: NSWindow?
    private var transitionTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    func attach(_ value: NSWindow?) {
        guard let value else { return }
        if window === value { attached = true; return }
        transitionTask?.cancel()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        window = value
        value.styleMask.insert(.resizable)
        value.collectionBehavior.remove(.fullScreenAuxiliary)
        value.collectionBehavior.insert(.fullScreenPrimary)
        attached = true; fullScreen = value.styleMask.contains(.fullScreen)
        for name in [NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification, NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification, NSWindow.willCloseNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: value, queue: .main) { [weak self, weak value] notification in
                Task { @MainActor in
                    guard let self, let value else { return }
                    if notification.name == NSWindow.willEnterFullScreenNotification || notification.name == NSWindow.willExitFullScreenNotification {
                        self.transitioning = true
                        self.watchTransition(target: notification.name == NSWindow.willEnterFullScreenNotification)
                        return
                    }
                    self.transitionTask?.cancel()
                    self.fullScreen = value.styleMask.contains(.fullScreen)
                    self.transitioning = false
                    if notification.name == NSWindow.willCloseNotification { self.attached = false }
                }
            })
        }
    }
    func toggle() {
        guard let window, attached, !transitioning else { return }
        failure = nil; transitioning = true
        window.makeKeyAndOrderFront(nil)
        let target = !window.styleMask.contains(.fullScreen)
        window.toggleFullScreen(nil)
        watchTransition(target: target)
    }
    private func watchTransition(target: Bool) {
        transitionTask?.cancel()
        transitionTask = Task { [weak self, weak window] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard let self, let window, self.transitioning else { return }
            self.fullScreen = window.styleMask.contains(.fullScreen)
            self.transitioning = false
            if self.fullScreen != target { self.failure = "macOS could not change full screen. Try the window’s green button." }
        }
    }
    func escape() {
        guard !transitioning else { return }
        if fullScreen { toggle() }
        else { window?.close() }
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}

struct VinylWindowBinding: NSViewRepresentable {
    let state: VinylWindowState
    final class Reader: NSView {
        weak var state: VinylWindowState?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let owner = window
            DispatchQueue.main.async { [weak self, weak owner] in self?.state?.attach(owner) }
        }
    }
    func makeNSView(context: Context) -> Reader { let view = Reader(); view.state = state; return view }
    func updateNSView(_ view: Reader, context: Context) {
        view.state = state
        let owner = view.window
        DispatchQueue.main.async { [weak owner] in state.attach(owner) }
    }
}
