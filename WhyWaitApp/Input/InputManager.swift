import AppKit

/// Captures shared mouse and keyboard input and forwards it to the app coordinator.
final class InputManager {
    var eventHandler: ((InputEvent) -> Void)?
    var quitHandler: (() -> Void)?
    var escapeHandler: (() -> Bool)?

    private var localEventMonitor: Any?
    private var globalMouseMonitor: Any?

    func start() {
        guard localEventMonitor == nil, globalMouseMonitor == nil else {
            return
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                .mouseMoved,
                .leftMouseDown,
                .leftMouseDragged,
                .leftMouseUp,
                .rightMouseDown,
                .keyDown
            ]
        ) { [weak self] event in
            guard let self else {
                return event
            }

            if event.type == .keyDown,
               event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "q" {
                self.quitHandler?()
                return nil
            }

            switch event.type {
            case .mouseMoved:
                self.eventHandler?(.mouseMoved(screenLocation: NSEvent.mouseLocation))
            case .leftMouseDown:
                self.eventHandler?(.leftMouseDown(screenLocation: NSEvent.mouseLocation))
            case .leftMouseDragged:
                self.eventHandler?(.leftMouseDragged(screenLocation: NSEvent.mouseLocation))
            case .leftMouseUp:
                self.eventHandler?(.leftMouseUp(screenLocation: NSEvent.mouseLocation))
            case .rightMouseDown:
                self.eventHandler?(.rightMouseDown(screenLocation: NSEvent.mouseLocation))
            case .keyDown where event.keyCode == 53:
                return self.escapeHandler?() == true ? nil : event
            case .keyDown:
                self.eventHandler?(
                    .keyDown(keyCode: event.keyCode, isRepeat: event.isARepeat)
                )
            default:
                break
            }

            return event
        }

        // A global mouse monitor keeps movement tracking useful when a future
        // overlay opts into click-through behavior.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved]
        ) { [weak self] _ in
            let screenLocation = NSEvent.mouseLocation
            DispatchQueue.main.async {
                self?.eventHandler?(.mouseMoved(screenLocation: screenLocation))
            }
        }
    }

    func stop() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }

        localEventMonitor = nil
        globalMouseMonitor = nil
    }

    deinit {
        stop()
    }
}
