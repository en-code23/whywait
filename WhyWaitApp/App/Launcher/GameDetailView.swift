import AppKit

final class GameDetailView: NSView {
    var onPlay: ((String) -> Void)?

    private let accentLine = NSView()
    private let artifactLabel = NSTextField(labelWithString: "ACTIVE ARTIFACT")
    private let iconContainer = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "")
    private let controlsSurface = NSView()
    private let controlsLabel = NSTextField(wrappingLabelWithString: "")
    private let statsStack = NSStackView()
    private let playButton = LauncherActionButton()
    private var gameID: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureHierarchy()
    }

    required init?(coder: NSCoder) {
        fatalError("GameDetailView does not support NSCoding")
    }

    func configure(game: LauncherGameViewModel) {
        gameID = game.metadata.id
        let registryIndex = MinigameRegistry.allGames.firstIndex(where: { $0.id == game.metadata.id }) ?? 0
        artifactLabel.stringValue = "ACTIVE ARTIFACT  /  \(String(format: "%02d", registryIndex + 1))"
        iconView.image = NSImage(
            systemSymbolName: game.metadata.symbolName,
            accessibilityDescription: game.metadata.name
        ) ?? NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: game.metadata.name)
        titleLabel.stringValue = game.metadata.name
        descriptionLabel.stringValue = game.metadata.detail
        controlsLabel.stringValue = game.metadata.controls.uppercased()
        playButton.title = "Launch \(game.metadata.name)"
        playButton.setAccessibilityLabel("Play \(game.metadata.name)")

        let gameAccent = LauncherTheme.gameAccent(for: game.metadata.id)
        iconView.contentTintColor = gameAccent
        accentLine.layer?.backgroundColor = LauncherTheme.resolved(gameAccent, for: self).cgColor
        iconContainer.layer?.backgroundColor = LauncherTheme.resolved(gameAccent.withAlphaComponent(0.14), for: self).cgColor

        statsStack.arrangedSubviews.forEach {
            statsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for (index, stat) in game.detailStats.prefix(4).enumerated() {
            let row = makeStatRow(stat, showDivider: index > 0)
            statsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: statsStack.widthAnchor).isActive = true
        }
    }

    func setReduceMotion(_ reduced: Bool) {
        playButton.reduceMotion = reduced
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applySurfaceAppearance()
        if let gameID {
            let gameAccent = LauncherTheme.gameAccent(for: gameID)
            accentLine.layer?.backgroundColor = LauncherTheme.resolved(gameAccent, for: self).cgColor
            iconContainer.layer?.backgroundColor = LauncherTheme.resolved(gameAccent.withAlphaComponent(0.14), for: self).cgColor
        }
    }

    private func configureHierarchy() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = LauncherTheme.inspectorRadius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        applySurfaceAppearance()

        accentLine.translatesAutoresizingMaskIntoConstraints = false
        accentLine.wantsLayer = true

        artifactLabel.translatesAutoresizingMaskIntoConstraints = false
        artifactLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .semibold)
        artifactLabel.textColor = LauncherTheme.accent

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 10
        iconContainer.layer?.cornerCurve = .continuous
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = LauncherTheme.primaryText
        titleLabel.lineBreakMode = .byTruncatingTail

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        descriptionLabel.textColor = LauncherTheme.secondaryText
        descriptionLabel.maximumNumberOfLines = 3

        controlsSurface.translatesAutoresizingMaskIntoConstraints = false
        controlsSurface.wantsLayer = true
        controlsSurface.layer?.cornerRadius = 8
        controlsSurface.layer?.cornerCurve = .continuous
        controlsSurface.layer?.borderWidth = 1

        let controlsHeading = sectionLabel("CONTROL SIGNAL")
        controlsLabel.translatesAutoresizingMaskIntoConstraints = false
        controlsLabel.font = NSFont.monospacedSystemFont(ofSize: 8.5, weight: .medium)
        controlsLabel.textColor = LauncherTheme.secondaryText
        controlsLabel.maximumNumberOfLines = 3

        let statsHeading = sectionLabel("RUN TELEMETRY")
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        statsStack.orientation = .vertical
        statsStack.alignment = .leading
        statsStack.spacing = 0

        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.launcherStyle = .primary
        playButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        playButton.imagePosition = .imageLeading
        playButton.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        playButton.target = self
        playButton.action = #selector(play)

        [accentLine, artifactLabel, iconContainer, titleLabel, descriptionLabel, controlsSurface, statsHeading, statsStack, playButton].forEach(addSubview)
        iconContainer.addSubview(iconView)
        controlsSurface.addSubview(controlsHeading)
        controlsSurface.addSubview(controlsLabel)

        NSLayoutConstraint.activate([
            accentLine.topAnchor.constraint(equalTo: topAnchor),
            accentLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            accentLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            accentLine.heightAnchor.constraint(equalToConstant: 2),

            artifactLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            artifactLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            artifactLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            iconContainer.leadingAnchor.constraint(equalTo: artifactLabel.leadingAnchor),
            iconContainer.topAnchor.constraint(equalTo: artifactLabel.bottomAnchor, constant: 10),
            iconContainer.widthAnchor.constraint(equalToConstant: 42),
            iconContainer.heightAnchor.constraint(equalToConstant: 42),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            descriptionLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: artifactLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: artifactLabel.trailingAnchor),

            controlsSurface.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            controlsSurface.leadingAnchor.constraint(equalTo: artifactLabel.leadingAnchor),
            controlsSurface.trailingAnchor.constraint(equalTo: artifactLabel.trailingAnchor),
            controlsSurface.heightAnchor.constraint(greaterThanOrEqualToConstant: 55),
            controlsHeading.topAnchor.constraint(equalTo: controlsSurface.topAnchor, constant: 8),
            controlsHeading.leadingAnchor.constraint(equalTo: controlsSurface.leadingAnchor, constant: 10),
            controlsHeading.trailingAnchor.constraint(equalTo: controlsSurface.trailingAnchor, constant: -10),
            controlsLabel.topAnchor.constraint(equalTo: controlsHeading.bottomAnchor, constant: 4),
            controlsLabel.leadingAnchor.constraint(equalTo: controlsHeading.leadingAnchor),
            controlsLabel.trailingAnchor.constraint(equalTo: controlsHeading.trailingAnchor),
            controlsLabel.bottomAnchor.constraint(lessThanOrEqualTo: controlsSurface.bottomAnchor, constant: -8),

            statsHeading.topAnchor.constraint(equalTo: controlsSurface.bottomAnchor, constant: 12),
            statsHeading.leadingAnchor.constraint(equalTo: artifactLabel.leadingAnchor),
            statsStack.topAnchor.constraint(equalTo: statsHeading.bottomAnchor, constant: 4),
            statsStack.leadingAnchor.constraint(equalTo: artifactLabel.leadingAnchor),
            statsStack.trailingAnchor.constraint(equalTo: artifactLabel.trailingAnchor),

            playButton.leadingAnchor.constraint(equalTo: artifactLabel.leadingAnchor),
            playButton.trailingAnchor.constraint(equalTo: artifactLabel.trailingAnchor),
            playButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            playButton.heightAnchor.constraint(equalToConstant: 34)
        ])
        applySurfaceAppearance()
    }

    private func makeStatRow(_ stat: LauncherStat, showDivider: Bool) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let divider = NSView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = LauncherTheme.resolved(LauncherTheme.softBorder, for: self).cgColor
        divider.isHidden = !showDivider

        let label = NSTextField(labelWithString: stat.label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 8.5, weight: .medium)
        label.textColor = LauncherTheme.tertiaryText
        let value = NSTextField(labelWithString: stat.value)
        value.translatesAutoresizingMaskIntoConstraints = false
        value.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        value.textColor = LauncherTheme.primaryText
        value.alignment = .right
        value.setContentHuggingPriority(.required, for: .horizontal)

        [divider, label, value].forEach(row.addSubview)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 24),
            divider.topAnchor.constraint(equalTo: row.topAnchor),
            divider.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor, constant: 1),
            value.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            value.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            value.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8)
        ])
        return row
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .bold)
        label.textColor = LauncherTheme.tertiaryText
        return label
    }

    private func applySurfaceAppearance() {
        layer?.backgroundColor = LauncherTheme.resolved(LauncherTheme.surfaceRaised, for: self).cgColor
        layer?.borderColor = LauncherTheme.resolved(LauncherTheme.border, for: self).cgColor
        controlsSurface.layer?.backgroundColor = LauncherTheme.resolved(LauncherTheme.surfaceInset, for: self).cgColor
        controlsSurface.layer?.borderColor = LauncherTheme.resolved(LauncherTheme.softBorder, for: self).cgColor
    }

    @objc private func play() {
        guard let gameID else { return }
        onPlay?(gameID)
    }
}
