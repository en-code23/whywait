import AppKit
import SpriteKit

private final class OverlaySpriteView: SKView {
    var onFrameSizeChanged: ((CGSize) -> Void)?

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        onFrameSizeChanged?(newSize)
    }
}

/// Manages the reusable desktop overlay independently of any minigame.
final class OverlayWindowController {
    private var overlayWindow: OverlayWindow?
    private var spriteView: SKView?
    private(set) var isClickThroughEnabled = false

    static func sceneSize(for displaySize: CGSize, objectScale: Double) -> CGSize {
        let scale = WhyWaitGameObjectScale.clamped(objectScale)
        return CGSize(
            width: displaySize.width / scale,
            height: displaySize.height / scale
        )
    }

    func show(scene: SKScene, on screen: NSScreen, objectScale: Double = 1) {
        let window = OverlayWindow(screen: screen)
        let spriteView = makeSpriteView(frame: CGRect(origin: .zero, size: screen.frame.size))

        scene.size = Self.sceneSize(for: spriteView.bounds.size, objectScale: objectScale)
        scene.scaleMode = .aspectFill
        scene.backgroundColor = .clear
        spriteView.onFrameSizeChanged = { [weak scene] newSize in
            scene?.size = Self.sceneSize(for: newSize, objectScale: objectScale)
        }

        spriteView.presentScene(scene)
        window.contentView = spriteView
        window.ignoresMouseEvents = isClickThroughEnabled
        window.setFrame(screen.frame, display: true)

        overlayWindow?.orderOut(nil)
        overlayWindow = window
        self.spriteView = spriteView

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    /// Enables future passive overlays without changing minigame code.
    func setClickThroughEnabled(_ isEnabled: Bool) {
        isClickThroughEnabled = isEnabled
        overlayWindow?.ignoresMouseEvents = isEnabled
    }

    func hide() {
        spriteView?.presentScene(nil)
        overlayWindow?.orderOut(nil)
        spriteView = nil
        overlayWindow = nil
    }

    private func makeSpriteView(frame: CGRect) -> OverlaySpriteView {
        let view = OverlaySpriteView(frame: frame)
        view.autoresizingMask = [.width, .height]
        view.allowsTransparency = true
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }
}
