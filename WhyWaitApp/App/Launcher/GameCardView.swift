import AppKit

/// A compact artifact row rather than a dashboard card. Seven rows share one
/// queue surface so the catalog reads as a single, purposeful instrument.
final class GameCardView: NSView {
    let gameID: String
    var onSelect: ((String) -> Void)?
    var onPlay: ((String) -> Void)?

    private let metadata: MinigameMetadata
    private let accentBar = NSView()
    private let indexLabel = NSTextField(labelWithString: "")
    private let iconContainer = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let statLabel = NSTextField(labelWithString: "")
    private let playButton = LauncherActionButton()
    private let lastPlayedLabel = NSTextField(labelWithString: "LAST")
    private var trackingAreaReference: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false
    private var isSelected = false
    private var reduceMotion = false

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
    }

    func setSelected(_ selected: Bool) {
        guard isSelected != selected else { return }
        isSelected = selected
        updateAppearance(animated: true)
    }

    func setReduceMotion(_ reduced: Bool) {
        reduceMotion = reduced
        playButton.reduceMotion = reduced
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
        layer?.borderWidth = 0

        let registryIndex = MinigameRegistry.allGames.firstIndex(where: { $0.id == gameID }) ?? 0
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        indexLabel.stringValue = String(format: "%02d", registryIndex + 1)
        indexLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium)
        indexLabel.textColor = LauncherTheme.mutedText
        indexLabel.alignment = .right

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.wantsLayer = true
        accentBar.layer?.cornerRadius = 1

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = LauncherTheme.iconRadius
        iconContainer.layer?.cornerCurve = .continuous
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(
            systemSymbolName: metadata.symbolName,
            accessibilityDescription: metadata.name
        ) ?? NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: metadata.name)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        iconView.contentTintColor = LauncherTheme.gameAccent(for: gameID)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = metadata.name
        titleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        titleLabel.textColor = LauncherTheme.primaryText
        titleLabel.lineBreakMode = .byTruncatingTail

        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.stringValue = metadata.summary
        summaryLabel.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        summaryLabel.textColor = LauncherTheme.secondaryText
        summaryLabel.lineBreakMode = .byTruncatingTail
        summaryLabel.maximumNumberOfLines = 1

        statLabel.translatesAutoresizingMaskIntoConstraints = false
        statLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .medium)
        statLabel.textColor = LauncherTheme.tertiaryText
        statLabel.alignment = .right
        statLabel.lineBreakMode = .byTruncatingHead

        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.title = "PLAY"
        playButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        playButton.imagePosition = .imageLeading
        playButton.launcherStyle = .quiet
        playButton.font = NSFont.monospacedSystemFont(ofSize: 8.5, weight: .semibold)
        playButton.target = self
        playButton.action = #selector(play)
        playButton.setAccessibilityLabel("Play \(metadata.name)")

        lastPlayedLabel.translatesAutoresizingMaskIntoConstraints = false
        lastPlayedLabel.font = NSFont.monospacedSystemFont(ofSize: 7.5, weight: .bold)
        lastPlayedLabel.textColor = LauncherTheme.accent
        lastPlayedLabel.isHidden = true

        [accentBar, indexLabel, iconContainer, titleLabel, summaryLabel, statLabel, playButton, lastPlayedLabel].forEach(addSubview)
        iconContainer.addSubview(iconView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: LauncherTheme.cardHeight),
            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            accentBar.centerYAnchor.constraint(equalTo: centerYAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 2),
            accentBar.heightAnchor.constraint(equalToConstant: 22),

            indexLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            indexLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            indexLabel.widthAnchor.constraint(equalToConstant: 18),

            iconContainer.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 8),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 30),
            iconContainer.heightAnchor.constraint(equalToConstant: 30),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 17),
            iconView.heightAnchor.constraint(equalToConstant: 17),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 128),
            summaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            summaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: statLabel.leadingAnchor, constant: -12),

            lastPlayedLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 7),
            lastPlayedLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            playButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 55),
            playButton.heightAnchor.constraint(equalToConstant: 30),

            statLabel.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -7),
            statLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 124),
            statLabel.leadingAnchor.constraint(greaterThanOrEqualTo: lastPlayedLabel.trailingAnchor, constant: 8)
        ])
    }

    @objc private func play() {
        onPlay?(gameID)
    }

    private func updateAppearance(animated: Bool = false) {
        guard let layer else { return }
        let background: NSColor
        if isPressed {
            background = LauncherTheme.accent.withAlphaComponent(0.16)
        } else if isSelected {
            background = LauncherTheme.selectedSurface
        } else if isHovered {
            background = LauncherTheme.hoverSurface
        } else {
            background = .clear
        }
        let gameAccent = LauncherTheme.gameAccent(for: gameID)

        CATransaction.begin()
        CATransaction.setDisableActions(!animated || reduceMotion)
        CATransaction.setAnimationDuration(0.16)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        layer.backgroundColor = LauncherTheme.resolved(background, for: self).cgColor
        layer.borderColor = LauncherTheme.resolved(isSelected ? LauncherTheme.softBorder : .clear, for: self).cgColor
        layer.borderWidth = isSelected ? 1 : 0
        accentBar.layer?.backgroundColor = LauncherTheme.resolved(
            isSelected ? LauncherTheme.accent : (isHovered ? gameAccent.withAlphaComponent(0.7) : .clear),
            for: self
        ).cgColor
        iconContainer.layer?.backgroundColor = LauncherTheme.resolved(
            gameAccent.withAlphaComponent(isSelected ? 0.18 : 0.10),
            for: self
        ).cgColor
        CATransaction.commit()
    }
}
