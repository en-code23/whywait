import AppKit

final class GameCardView: NSView {
    let gameID: String
    var onSelect: ((String) -> Void)?
    var onPlay: ((String) -> Void)?

    private let metadata: MinigameMetadata
    private let iconContainer = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let statLabel = NSTextField(labelWithString: "")
    private let playButton = NSButton()
    private let lastPlayedLabel = NSTextField(labelWithString: "LAST PLAYED")
    private var trackingAreaReference: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false
    private var isSelected = false

    init(game: LauncherGameViewModel) {
        metadata = game.metadata
        gameID = game.metadata.id
        super.init(frame: .zero)
        toolTip = game.metadata.summary
        setAccessibilityRole(.button)
        setAccessibilityLabel("Select \(game.metadata.name)")
        configureHierarchy()
        update(game: game)
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("GameCardView does not support NSCoding")
    }

    func update(game: LauncherGameViewModel) {
        statLabel.stringValue = game.cardStat.uppercased()
    }

    func setLastPlayed(_ lastPlayed: Bool) {
        lastPlayedLabel.isHidden = !lastPlayed
        updateAppearance()
    }

    func setSelected(_ selected: Bool) {
        guard isSelected != selected else { return }
        isSelected = selected
        updateAppearance(animated: true)
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
        isPressed = false
        updateAppearance(animated: true)
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        updateAppearance(animated: true)
        onSelect?(gameID)
        if event.clickCount >= 2 { onPlay?(gameID) }
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        updateAppearance(animated: true)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func configureHierarchy() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = LauncherTheme.cardRadius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = LauncherTheme.iconRadius
        iconContainer.layer?.cornerCurve = .continuous
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(
            systemSymbolName: metadata.symbolName,
            accessibilityDescription: metadata.name
        ) ?? NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: metadata.name)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        iconView.contentTintColor = LauncherTheme.accent

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = metadata.name
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = LauncherTheme.primaryText
        titleLabel.lineBreakMode = .byTruncatingTail

        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.stringValue = metadata.summary
        summaryLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        summaryLabel.textColor = LauncherTheme.secondaryText
        summaryLabel.lineBreakMode = .byTruncatingTail
        summaryLabel.maximumNumberOfLines = 1

        statLabel.translatesAutoresizingMaskIntoConstraints = false
        statLabel.font = NSFont.monospacedSystemFont(ofSize: 8.5, weight: .medium)
        statLabel.textColor = LauncherTheme.tertiaryText
        statLabel.lineBreakMode = .byTruncatingTail

        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.title = "PLAY"
        playButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        playButton.imagePosition = .imageLeading
        playButton.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        playButton.isBordered = false
        playButton.contentTintColor = LauncherTheme.accent
        playButton.target = self
        playButton.action = #selector(play)
        playButton.setAccessibilityLabel("Play \(metadata.name)")

        lastPlayedLabel.translatesAutoresizingMaskIntoConstraints = false
        lastPlayedLabel.font = NSFont.systemFont(ofSize: 8, weight: .bold)
        lastPlayedLabel.textColor = LauncherTheme.accent
        lastPlayedLabel.isHidden = true

        addSubview(iconContainer)
        iconContainer.addSubview(iconView)
        addSubview(titleLabel)
        addSubview(summaryLabel)
        addSubview(statLabel)
        addSubview(playButton)
        addSubview(lastPlayedLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: LauncherTheme.cardHeight),
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            iconContainer.widthAnchor.constraint(equalToConstant: 38),
            iconContainer.heightAnchor.constraint(equalToConstant: 38),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 21),
            iconView.heightAnchor.constraint(equalToConstant: 21),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 11),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -4),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            summaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            summaryLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

            playButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            playButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            playButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
            playButton.heightAnchor.constraint(equalToConstant: 28),

            lastPlayedLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            lastPlayedLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            statLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            statLabel.bottomAnchor.constraint(equalTo: lastPlayedLabel.bottomAnchor),
            statLabel.leadingAnchor.constraint(greaterThanOrEqualTo: lastPlayedLabel.trailingAnchor, constant: 8)
        ])
    }

    @objc private func play() {
        onPlay?(gameID)
    }

    private func updateAppearance(animated: Bool = false) {
        let changes = { [self] in
            let background: NSColor
            if isPressed {
                background = LauncherTheme.cardPressed
            } else if isSelected {
                background = LauncherTheme.cardSelected
            } else if isHovered {
                background = LauncherTheme.cardHover
            } else {
                background = LauncherTheme.cardBackground
            }
            layer?.backgroundColor = background.cgColor
            layer?.borderColor = (isSelected || isHovered
                ? LauncherTheme.borderHover
                : LauncherTheme.border).cgColor
            layer?.borderWidth = isSelected ? 1.5 : 1
            iconContainer.layer?.backgroundColor = LauncherTheme.accent.withAlphaComponent(
                isSelected ? 0.2 : (isHovered ? 0.16 : 0.09)
            ).cgColor

            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            layer?.shadowColor = NSColor.black.cgColor
            layer?.shadowOpacity = dark ? 0 : (isSelected || isHovered ? 0.14 : 0.06)
            layer?.shadowRadius = isSelected || isHovered ? 7 : 3
            layer?.shadowOffset = CGSize(width: 0, height: -2)
        }
        guard animated else {
            changes()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            changes()
        }
    }
}
