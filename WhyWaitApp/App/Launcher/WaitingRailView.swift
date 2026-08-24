import AppKit

final class WaitingRailView: NSView {
    var highlightedIndex: Int? {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 156, height: 5)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let count = max(1, MinigameRegistry.allGames.count)
        let gap: CGFloat = 4
        let segmentWidth = max(5, (bounds.width - (CGFloat(count - 1) * gap)) / CGFloat(count))
        for index in 0..<count {
            let rect = CGRect(
                x: CGFloat(index) * (segmentWidth + gap),
                y: (bounds.height - 4) * 0.5,
                width: segmentWidth,
                height: 4
            )
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            let color = index == highlightedIndex
                ? LauncherTheme.accent
                : NSColor.separatorColor.withAlphaComponent(0.46)
            color.setFill()
            path.fill()
        }
    }
}
