import AppKit

/// WhyWait's signature: each minigame is an artifact on one asynchronous
/// waitline. The solid node is the current selection; the ring remembers the
/// last thing played without turning the rail into another navigation control.
final class WaitingRailView: NSView {
    var highlightedIndex: Int? {
        didSet { needsDisplay = true }
    }
    var selectedIndex: Int? {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 224, height: 18)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let count = max(1, MinigameRegistry.allGames.count)
        let left: CGFloat = 6
        let right: CGFloat = bounds.width - 6
        let centerY = bounds.midY
        let step = count > 1 ? (right - left) / CGFloat(count - 1) : 0

        let track = NSBezierPath()
        track.move(to: CGPoint(x: left, y: centerY))
        track.line(to: CGPoint(x: right, y: centerY))
        track.lineWidth = 1
        LauncherTheme.resolved(LauncherTheme.border, for: self).setStroke()
        track.stroke()

        // A short cyan live segment implies work continuing elsewhere.
        if let selectedIndex {
            let safeIndex = min(max(0, selectedIndex), count - 1)
            let selectedX = left + CGFloat(safeIndex) * step
            let live = NSBezierPath()
            live.move(to: CGPoint(x: max(left, selectedX - 15), y: centerY))
            live.line(to: CGPoint(x: min(right, selectedX + 15), y: centerY))
            live.lineWidth = 2
            LauncherTheme.resolved(LauncherTheme.accent, for: self).setStroke()
            live.stroke()
        }

        for index in 0..<count {
            let x = left + CGFloat(index) * step
            let gameID = MinigameRegistry.allGames[index].id
            let gameColor = LauncherTheme.resolved(LauncherTheme.gameAccent(for: gameID), for: self)
            if index == selectedIndex {
                LauncherTheme.resolved(LauncherTheme.accent.withAlphaComponent(0.16), for: self).setFill()
                NSBezierPath(ovalIn: CGRect(x: x - 7, y: centerY - 7, width: 14, height: 14)).fill()
                gameColor.setFill()
                NSBezierPath(ovalIn: CGRect(x: x - 3.5, y: centerY - 3.5, width: 7, height: 7)).fill()
            } else if index == highlightedIndex {
                let ring = NSBezierPath(ovalIn: CGRect(x: x - 3.5, y: centerY - 3.5, width: 7, height: 7))
                ring.lineWidth = 1.5
                gameColor.setStroke()
                ring.stroke()
                LauncherTheme.resolved(LauncherTheme.canvas, for: self).setFill()
                NSBezierPath(ovalIn: CGRect(x: x - 1.5, y: centerY - 1.5, width: 3, height: 3)).fill()
            } else {
                LauncherTheme.resolved(LauncherTheme.tertiaryText, for: self).setFill()
                NSBezierPath(ovalIn: CGRect(x: x - 2, y: centerY - 2, width: 4, height: 4)).fill()
            }
        }
    }
}
