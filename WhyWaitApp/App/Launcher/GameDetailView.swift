import AppKit

final class GameDetailView: NSView {
    var onPlay: ((String) -> Void)?

    private let iconContainer = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "")
    private let controlsLabel = NSTextField(wrappingLabelWithString: "")
    private let statsStack = NSStackView()
    private let playButton = NSButton()
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
        iconView.image = NSImage(
            systemSymbolName: game.metadata.symbolName,
            accessibilityDescription: game.metadata.name
        ) ?? NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: game.metadata.name)
        titleLabel.stringValue = game.metadata.name
        descriptionLabel.stringValue = game.metadata.detail
        controlsLabel.stringValue = game.metadata.controls
        playButton.title = "Play \(game.metadata.name)"
        playButton.setAccessibilityLabel("Play \(game.metadata.name)")

        statsStack.arrangedSubviews.forEach {
            statsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for stat in game.detailStats.prefix(5) {
            let row = makeStatRow(stat)
            statsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: statsStack.widthAnchor).isActive = true
        }
    }

    private func configureHierarchy() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = LauncherTheme.inspectorRadius
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = LauncherTheme.inspectorBackground.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = LauncherTheme.border.cgColor

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 10
        iconContainer.layer?.cornerCurve = .continuous
        iconContainer.layer?.backgroundColor = LauncherTheme.accent.withAlphaComponent(0.12).cgColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = LauncherTheme.accent
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = LauncherTheme.primaryText

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        descriptionLabel.textColor = LauncherTheme.secondaryText
        descriptionLabel.maximumNumberOfLines = 4

        let controlsHeading = sectionLabel("CONTROLS")
        controlsLabel.translatesAutoresizingMaskIntoConstraints = false
        controlsLabel.font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .medium)
        controlsLabel.textColor = LauncherTheme.secondaryText
        controlsLabel.maximumNumberOfLines = 3

        let statsHeading = sectionLabel("AT A GLANCE")
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        statsStack.orientation = .vertical
        statsStack.alignment = .leading
        statsStack.spacing = 7

        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.bezelStyle = .rounded
        playButton.controlSize = .large
        playButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        playButton.imagePosition = .imageLeading
        playButton.contentTintColor = LauncherTheme.accent
        playButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        playButton.target = self
        playButton.action = #selector(play)

        addSubview(iconContainer)
        iconContainer.addSubview(iconView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(controlsHeading)
        addSubview(controlsLabel)
        addSubview(statsHeading)
        addSubview(statsStack)
        addSubview(playButton)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            descriptionLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 15),
            descriptionLabel.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),

            controlsHeading.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 18),
            controlsHeading.leadingAnchor.constraint(equalTo: descriptionLabel.leadingAnchor),
            controlsLabel.topAnchor.constraint(equalTo: controlsHeading.bottomAnchor, constant: 6),
            controlsLabel.leadingAnchor.constraint(equalTo: descriptionLabel.leadingAnchor),
            controlsLabel.trailingAnchor.constraint(equalTo: descriptionLabel.trailingAnchor),

            statsHeading.topAnchor.constraint(equalTo: controlsLabel.bottomAnchor, constant: 18),
            statsHeading.leadingAnchor.constraint(equalTo: descriptionLabel.leadingAnchor),
            statsStack.topAnchor.constraint(equalTo: statsHeading.bottomAnchor, constant: 7),
            statsStack.leadingAnchor.constraint(equalTo: descriptionLabel.leadingAnchor),
            statsStack.trailingAnchor.constraint(equalTo: descriptionLabel.trailingAnchor),

            playButton.leadingAnchor.constraint(equalTo: descriptionLabel.leadingAnchor),
            playButton.trailingAnchor.constraint(equalTo: descriptionLabel.trailingAnchor),
            playButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            playButton.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func makeStatRow(_ stat: LauncherStat) -> NSView {
        let label = NSTextField(labelWithString: stat.label)
        label.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        label.textColor = LauncherTheme.tertiaryText
        let value = NSTextField(labelWithString: stat.value)
        value.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        value.textColor = LauncherTheme.primaryText
        value.alignment = .right
        let row = NSStackView(views: [label, value])
        row.orientation = .horizontal
        row.distribution = .fill
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        value.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        label.textColor = LauncherTheme.tertiaryText
        return label
    }

    @objc private func play() {
        guard let gameID else { return }
        onPlay?(gameID)
    }
}
