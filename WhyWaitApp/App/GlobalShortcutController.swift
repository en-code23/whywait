import Carbon
import Foundation

private let whyWaitHotKeyHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let controller = Unmanaged<GlobalShortcutController>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { controller.performShortcut() }
    return noErr
}

final class GlobalShortcutController {
    var onShortcut: (() -> Void)?

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private(set) var shortcutDescription = "⌥ Space"

    var isRegistered: Bool { hotKey != nil }

    @discardableResult
    func start() -> Bool {
        guard hotKey == nil else { return true }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            whyWaitHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard installStatus == noErr else { return false }

        if register(modifiers: UInt32(optionKey)) {
            shortcutDescription = "⌥ Space"
            return true
        }
        if register(modifiers: UInt32(optionKey | controlKey)) {
            shortcutDescription = "⌃⌥ Space"
            return true
        }
        stop()
        return false
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKey = nil
        eventHandler = nil
    }

    fileprivate func performShortcut() { onShortcut?() }

#if DEBUG
    func performShortcutForDiagnostics() { performShortcut() }
#endif

    private func register(modifiers: UInt32) -> Bool {
        let identifier = EventHotKeyID(signature: 0x5759_5754, id: 1) // WYWT
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        return status == noErr
    }

    deinit { stop() }
}
