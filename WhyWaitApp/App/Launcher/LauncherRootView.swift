import AppKit

final class LauncherRootView: NSView {
    var onKeyEvent: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    override func keyDown(with event: NSEvent) {
        if onKeyEvent?(event) == true { return }
        super.keyDown(with: event)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        LauncherTheme.resolved(LauncherTheme.canvas, for: self).setFill()
        NSBezierPath(rect: bounds).fill()

        // A nearly invisible timing grid makes the launcher feel like a
        // desktop instrument without becoming a terminal-themed novelty.
        let markColor = LauncherTheme.resolved(LauncherTheme.gridMark, for: self)
        markColor.setFill()
        let spacing: CGFloat = 24
        var y: CGFloat = 18
        while y < bounds.height {
            var x: CGFloat = 18
            while x < bounds.width {
                NSBezierPath(ovalIn: CGRect(x: x, y: y, width: 1.25, height: 1.25)).fill()
                x += spacing
            }
            y += spacing
        }

        // Quiet corner ticks echo the overlay coordinate system.
        let tickColor = LauncherTheme.resolved(LauncherTheme.accent.withAlphaComponent(0.22), for: self)
        tickColor.setStroke()
        let tick = NSBezierPath()
        tick.lineWidth = 1
        tick.move(to: CGPoint(x: 16, y: bounds.height - 34))
        tick.line(to: CGPoint(x: 16, y: bounds.height - 16))
        tick.line(to: CGPoint(x: 34, y: bounds.height - 16))
        tick.move(to: CGPoint(x: bounds.width - 34, y: 16))
        tick.line(to: CGPoint(x: bounds.width - 16, y: 16))
        tick.line(to: CGPoint(x: bounds.width - 16, y: 34))
        tick.stroke()
    }
}
