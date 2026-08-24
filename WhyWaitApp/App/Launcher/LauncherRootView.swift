import AppKit

final class LauncherRootView: NSView {
    var onKeyEvent: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyEvent?(event) == true { return }
        super.keyDown(with: event)
    }
}
