import AppKit

enum LauncherTheme {
    // WhyWait uses a four-point rhythm: 4 / 8 / 12 / 16 / 24.
    static let windowSize = CGSize(width: 880, height: 580)
    static let outerPadding: CGFloat = 24
    static let contentGap: CGFloat = 16
    static let queueWidth: CGFloat = 536
    static let inspectorWidth: CGFloat = 280
    static let cardHeight: CGFloat = 46
    static let cardRadius: CGFloat = 8
    static let iconRadius: CGFloat = 7
    static let inspectorRadius: CGFloat = 14

    // The waitline is the one product accent. Game colors identify artifacts,
    // but never compete with the primary action or focus state.
    static let accent = adaptive(
        "WhyWait.Waitline",
        light: NSColor(calibratedRed: 0.00, green: 0.52, blue: 0.62, alpha: 1),
        dark: NSColor(calibratedRed: 0.29, green: 0.86, blue: 0.91, alpha: 1)
    )
    static let accentInk = adaptive(
        "WhyWait.WaitlineInk",
        light: .white,
        dark: NSColor(calibratedRed: 0.02, green: 0.10, blue: 0.12, alpha: 1)
    )

    static let canvas = adaptive(
        "WhyWait.Canvas",
        light: NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.96, alpha: 1),
        dark: NSColor(calibratedRed: 0.045, green: 0.058, blue: 0.071, alpha: 1)
    )
    static let surface = adaptive(
        "WhyWait.Surface",
        light: NSColor(calibratedRed: 0.975, green: 0.98, blue: 0.985, alpha: 1),
        dark: NSColor(calibratedRed: 0.070, green: 0.087, blue: 0.105, alpha: 1)
    )
    static let surfaceRaised = adaptive(
        "WhyWait.SurfaceRaised",
        light: .white,
        dark: NSColor(calibratedRed: 0.092, green: 0.112, blue: 0.137, alpha: 1)
    )
    static let surfaceInset = adaptive(
        "WhyWait.SurfaceInset",
        light: NSColor(calibratedRed: 0.90, green: 0.915, blue: 0.93, alpha: 1),
        dark: NSColor(calibratedRed: 0.029, green: 0.039, blue: 0.049, alpha: 1)
    )
    static let hoverSurface = adaptive(
        "WhyWait.HoverSurface",
        light: NSColor(calibratedRed: 0.91, green: 0.955, blue: 0.965, alpha: 1),
        dark: NSColor(calibratedRed: 0.085, green: 0.137, blue: 0.155, alpha: 1)
    )
    static let selectedSurface = adaptive(
        "WhyWait.SelectedSurface",
        light: NSColor(calibratedRed: 0.87, green: 0.95, blue: 0.96, alpha: 1),
        dark: NSColor(calibratedRed: 0.075, green: 0.158, blue: 0.177, alpha: 1)
    )

    static let primaryText = NSColor.labelColor
    static let secondaryText = NSColor.secondaryLabelColor
    static let tertiaryText = NSColor.tertiaryLabelColor
    static let mutedText = NSColor.quaternaryLabelColor
    static let border = adaptive(
        "WhyWait.Border",
        light: NSColor.black.withAlphaComponent(0.09),
        dark: NSColor.white.withAlphaComponent(0.085)
    )
    static let softBorder = adaptive(
        "WhyWait.SoftBorder",
        light: NSColor.black.withAlphaComponent(0.055),
        dark: NSColor.white.withAlphaComponent(0.055)
    )
    static let focusBorder = accent.withAlphaComponent(0.72)
    static let gridMark = adaptive(
        "WhyWait.GridMark",
        light: NSColor.black.withAlphaComponent(0.035),
        dark: NSColor.white.withAlphaComponent(0.026)
    )

    static func gameAccent(for gameID: String) -> NSColor {
        switch gameID {
        case "cursor-golf":
            return adaptive("WhyWait.Golf", light: color(0.16, 0.54, 0.28), dark: color(0.38, 0.82, 0.47))
        case "cursor-pong":
            return adaptive("WhyWait.Pong", light: color(0.20, 0.45, 0.78), dark: color(0.39, 0.68, 0.96))
        case "fruit-slice":
            return adaptive("WhyWait.Fruit", light: color(0.86, 0.33, 0.23), dark: color(1.00, 0.48, 0.34))
        case "grapple":
            return adaptive("WhyWait.Grapple", light: color(0.47, 0.32, 0.73), dark: color(0.70, 0.52, 0.96))
        case "fishing":
            return adaptive("WhyWait.Fishing", light: color(0.00, 0.48, 0.52), dark: color(0.25, 0.79, 0.77))
        case "sword-dummy":
            return adaptive("WhyWait.Sword", light: color(0.73, 0.48, 0.08), dark: color(0.97, 0.72, 0.29))
        case "zombie-sword":
            return adaptive("WhyWait.Zombie", light: color(0.34, 0.52, 0.18), dark: color(0.65, 0.83, 0.35))
        default:
            return accent
        }
    }

    static func resolved(_ color: NSColor, for view: NSView) -> NSColor {
        var resolved = color
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.deviceRGB) ?? color
        }
        return resolved
    }

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }

    private static func adaptive(_ name: String, light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: NSColor.Name(name)) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }
}

enum LauncherButtonStyle {
    case primary
    case secondary
    case quiet
}

/// A native NSButton with the restrained press/hover vocabulary used by the
/// launcher. It keeps AppKit's keyboard, accessibility, and target/action model.
final class LauncherActionButton: NSButton {
    var launcherStyle: LauncherButtonStyle = .secondary {
        didSet { updateAppearance() }
    }
    var reduceMotion = false

    private var trackingAreaReference: NSTrackingArea?
    private var isHovered = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference { removeTrackingArea(trackingAreaReference) }
        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
        trackingAreaReference = tracking
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance(animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance(animated: true)
    }

    override func mouseDown(with event: NSEvent) {
        if !reduceMotion { layer?.setAffineTransform(CGAffineTransform(scaleX: 0.98, y: 0.98)) }
        super.mouseDown(with: event)
        layer?.setAffineTransform(.identity)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func configure() {
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        focusRingType = .default
        updateAppearance()
    }

    private func updateAppearance(animated: Bool = false) {
        guard let layer else { return }
        let background: NSColor
        let foreground: NSColor
        let border: NSColor
        switch launcherStyle {
        case .primary:
            background = isHovered
                ? (LauncherTheme.accent.blended(withFraction: 0.12, of: .white) ?? LauncherTheme.accent)
                : LauncherTheme.accent
            foreground = LauncherTheme.accentInk
            border = LauncherTheme.accent
        case .secondary:
            background = isHovered ? LauncherTheme.hoverSurface : LauncherTheme.surfaceRaised
            foreground = LauncherTheme.primaryText
            border = isHovered ? LauncherTheme.focusBorder : LauncherTheme.border
        case .quiet:
            background = isHovered ? LauncherTheme.hoverSurface : .clear
            foreground = isHovered ? LauncherTheme.primaryText : LauncherTheme.secondaryText
            border = isHovered ? LauncherTheme.softBorder : .clear
        }

        CATransaction.begin()
        CATransaction.setDisableActions(!animated || reduceMotion)
        CATransaction.setAnimationDuration(0.15)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        layer.backgroundColor = LauncherTheme.resolved(background, for: self).cgColor
        layer.borderColor = LauncherTheme.resolved(border, for: self).cgColor
        layer.borderWidth = launcherStyle == .quiet && !isHovered ? 0 : 1
        contentTintColor = foreground
        CATransaction.commit()
    }
}
