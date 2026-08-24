import AppKit

enum LauncherTheme {
    static let windowSize = CGSize(width: 880, height: 580)
    static let outerPadding: CGFloat = 24
    static let gridGap: CGFloat = 10
    static let cardHeight: CGFloat = 86
    static let cardRadius: CGFloat = 12
    static let iconRadius: CGFloat = 9
    static let inspectorRadius: CGFloat = 14

    static let accent = NSColor.systemCyan
    static let primaryText = NSColor.labelColor
    static let secondaryText = NSColor.secondaryLabelColor
    static let tertiaryText = NSColor.tertiaryLabelColor
    static let cardBackground = NSColor.controlBackgroundColor
    static let cardHover = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.16)
    static let cardPressed = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.24)
    static let cardSelected = NSColor.systemCyan.withAlphaComponent(0.1)
    static let border = NSColor.separatorColor.withAlphaComponent(0.44)
    static let borderHover = NSColor.systemCyan.withAlphaComponent(0.5)
    static let inspectorBackground = NSColor.controlBackgroundColor.withAlphaComponent(0.7)
}
