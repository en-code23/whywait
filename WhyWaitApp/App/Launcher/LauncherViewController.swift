import AppKit

private final class LauncherQueueSurfaceView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = LauncherTheme.inspectorRadius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("LauncherQueueSurfaceView does not support NSCoding")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        layer?.backgroundColor = LauncherTheme.resolved(LauncherTheme.surface, for: self).cgColor
        layer?.borderColor = LauncherTheme.resolved(LauncherTheme.border, for: self).cgColor
    }
}

private final class LauncherModePillView: NSView {
    private let dot = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1

        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 2
        let label = NSTextField(labelWithString: "INTERMISSION READY")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.monospacedSystemFont(ofSize: 7.5, weight: .semibold)
        label.textColor = LauncherTheme.accent
        addSubview(dot)
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 20),
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 4),
            dot.heightAnchor.constraint(equalToConstant: 4),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("LauncherModePillView does not support NSCoding")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        layer?.backgroundColor = LauncherTheme.resolved(LauncherTheme.accent.withAlphaComponent(0.09), for: self).cgColor
        layer?.borderColor = LauncherTheme.resolved(LauncherTheme.accent.withAlphaComponent(0.18), for: self).cgColor
        dot.layer?.backgroundColor = LauncherTheme.resolved(LauncherTheme.accent, for: self).cgColor
    }
}

final class LauncherViewController: NSViewController {
    var onPlayGame: ((String) -> Void)?
    var onPlayLastGame: (() -> Void)?
    var onRandomGame: (() -> Void)?
    var onHideLauncher: (() -> Void)?
    var onSettingChanged: ((WhyWaitSettingKey, Bool) -> Void)?
    var onObjectScaleChanged: ((Double) -> Void)?

    private let metadata: [MinigameMetadata]
    private let rail = WaitingRailView()
    private let footerLabel = NSTextField(labelWithString: "")
    private let sessionSummaryLabel = NSTextField(labelWithString: "")
    private let playLastButton = LauncherActionButton()
    private let randomButton = LauncherActionButton()
    private let settingsButton = LauncherActionButton()
    private let detailView = GameDetailView()
    private let settingsView = LauncherSettingsView()
    private let quickActionAccessory = NSStackView()
    private var cards: [GameCardView] = []
    private var viewModel: LauncherViewModel?
    private var selectedIndex = 0
    private var isShowingSettings = false
    private var reduceMotion = false

    init(games: [MinigameMetadata]) {
        metadata = games
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("LauncherViewController does not support NSCoding")
    }

    override func loadView() {
        let root = LauncherRootView()
        root.onKeyEvent = { [weak self] event in self?.handleKeyEvent(event) == true }
        view = root
        buildInterface()
    }

    var preferredFirstResponder: NSResponder { view }

    /// Generic visual extension point for a compact status/action beside Quick
    /// Play (for example an updater pill). It deliberately owns no updater logic.
    func installQuickActionAccessory(_ accessory: NSView?) {
        quickActionAccessory.arrangedSubviews.forEach {
            quickActionAccessory.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        guard let accessory else { return }
        accessory.translatesAutoresizingMaskIntoConstraints = false
        quickActionAccessory.addArrangedSubview(accessory)
    }

    func refresh(_ viewModel: LauncherViewModel) {
        _ = view
        let previouslySelectedID = selectedGameID
        self.viewModel = viewModel
        reduceMotion = viewModel.settings.reduceVisualEffects
        for (index, card) in cards.enumerated() where index < viewModel.games.count {
            card.update(game: viewModel.games[index])
            card.setLastPlayed(card.gameID == viewModel.lastPlayedID)
            card.setReduceMotion(reduceMotion)
        }
        detailView.setReduceMotion(reduceMotion)
        playLastButton.reduceMotion = reduceMotion
        randomButton.reduceMotion = reduceMotion
        settingsButton.reduceMotion = reduceMotion
        rail.highlightedIndex = viewModel.games.firstIndex {
            $0.metadata.id == viewModel.lastPlayedID
        }
        sessionSummaryLabel.stringValue = viewModel.globalSummary.uppercased()
        playLastButton.isHidden = viewModel.lastPlayedID == nil
        if let lastID = viewModel.lastPlayedID,
           let game = viewModel.games.first(where: { $0.metadata.id == lastID }) {
            playLastButton.title = "Resume  ·  \(game.metadata.name)"
        }
        settingsView.configure(
            settings: viewModel.settings,
            launchAtLogin: viewModel.launchAtLogin,
            message: viewModel.settingsMessage
        )
        setShortcutDescription(viewModel.shortcutDescription)

        if let selectedID = previouslySelectedID,
           let refreshedIndex = viewModel.games.firstIndex(where: { $0.metadata.id == selectedID }) {
            selectedIndex = refreshedIndex
        } else if let lastID = viewModel.lastPlayedID,
                  let lastIndex = viewModel.games.firstIndex(where: { $0.metadata.id == lastID }) {
            selectedIndex = lastIndex
        } else {
            selectedIndex = 0
        }
        updateSelection(animated: false)
    }

    func setShortcutDescription(_ description: String) {
        footerLabel.stringValue = "↑↓  SELECT    RETURN  LAUNCH    ⌘,  PREFERENCES    ESC  HIDE    \(description.uppercased())  OPEN"
    }

    func showSettings() {
        isShowingSettings = true
        updateInspector(animated: true)
    }

    private var selectedGameID: String? {
        guard let viewModel, viewModel.games.indices.contains(selectedIndex) else { return nil }
        return viewModel.games[selectedIndex].metadata.id
    }

    private func buildInterface() {
        // Intent: developers choose one tiny diversion while long work continues.
        // Hierarchy: selected artifact inspector > queue > global telemetry.
        // Palette: graphite hardware, cyan waitline, sparse artifact colors.
        // Depth: quiet surface shifts plus hairline borders; no glass or card wall.
        // Type: monospaced operational labels paired with readable system text.
        // Spacing: a compact four-point grid.
        let wordmark = makeWordmark()
        let subtitle = NSTextField(labelWithString: "Small games for the long-running parts.")
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        subtitle.textColor = LauncherTheme.secondaryText

        let modePill = makeModePill()

        sessionSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        sessionSummaryLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .medium)
        sessionSummaryLabel.textColor = LauncherTheme.tertiaryText
        sessionSummaryLabel.alignment = .right
        sessionSummaryLabel.lineBreakMode = .byTruncatingHead

        rail.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.title = ""
        settingsButton.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Preferences")
        settingsButton.launcherStyle = .quiet
        settingsButton.target = self
        settingsButton.action = #selector(toggleSettings)
        settingsButton.toolTip = "Preferences (⌘,)"
        settingsButton.setAccessibilityLabel("Open WhyWait preferences")

        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        [wordmark, modePill, subtitle, sessionSummaryLabel, rail, settingsButton].forEach(header.addSubview)
        NSLayoutConstraint.activate([
            wordmark.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            wordmark.topAnchor.constraint(equalTo: header.topAnchor),
            modePill.leadingAnchor.constraint(equalTo: wordmark.trailingAnchor, constant: 12),
            modePill.centerYAnchor.constraint(equalTo: wordmark.centerYAnchor),
            subtitle.leadingAnchor.constraint(equalTo: wordmark.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: wordmark.bottomAnchor, constant: 3),

            settingsButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            settingsButton.topAnchor.constraint(equalTo: header.topAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 30),
            sessionSummaryLabel.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -10),
            sessionSummaryLabel.centerYAnchor.constraint(equalTo: settingsButton.centerYAnchor),
            sessionSummaryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: modePill.trailingAnchor, constant: 16),
            rail.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            rail.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            rail.widthAnchor.constraint(equalToConstant: 224),
            rail.heightAnchor.constraint(equalToConstant: 18),
            header.heightAnchor.constraint(equalToConstant: 58)
        ])

        configureQuickActions()
        quickActionAccessory.translatesAutoresizingMaskIntoConstraints = false
        quickActionAccessory.orientation = .horizontal
        quickActionAccessory.alignment = .centerY
        quickActionAccessory.setContentHuggingPriority(.required, for: .horizontal)
        let quickSpacer = NSView()
        quickSpacer.translatesAutoresizingMaskIntoConstraints = false
        quickSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let quickActions = NSStackView(views: [playLastButton, randomButton, quickSpacer, quickActionAccessory])
        quickActions.translatesAutoresizingMaskIntoConstraints = false
        quickActions.orientation = .horizontal
        quickActions.spacing = 8
        quickActions.alignment = .centerY

        let placeholderGames = metadata.map {
            LauncherGameViewModel(
                metadata: $0,
                cardStat: "Ready to play",
                detailStats: [
                    LauncherStat(label: "LAUNCHES", value: "0"),
                    LauncherStat(label: "PLAY TIME", value: "0m")
                ]
            )
        }
        cards = placeholderGames.map { game in
            let card = GameCardView(game: game)
            card.onSelect = { [weak self] id in self?.selectGame(id: id) }
            card.onPlay = { [weak self] id in self?.onPlayGame?(id) }
            return card
        }

        let queueSurface = makeQueueSurface(cards: cards)

        detailView.onPlay = { [weak self] id in self?.onPlayGame?(id) }
        settingsView.onToggle = { [weak self] key, enabled in
            self?.onSettingChanged?(key, enabled)
        }
        settingsView.onObjectScaleChanged = { [weak self] value in
            self?.onObjectScaleChanged?(value)
        }
        settingsView.isHidden = true

        let inspectorContainer = NSView()
        inspectorContainer.translatesAutoresizingMaskIntoConstraints = false
        inspectorContainer.addSubview(detailView)
        inspectorContainer.addSubview(settingsView)
        NSLayoutConstraint.activate([
            detailView.topAnchor.constraint(equalTo: inspectorContainer.topAnchor),
            detailView.leadingAnchor.constraint(equalTo: inspectorContainer.leadingAnchor),
            detailView.trailingAnchor.constraint(equalTo: inspectorContainer.trailingAnchor),
            detailView.bottomAnchor.constraint(equalTo: inspectorContainer.bottomAnchor),
            settingsView.topAnchor.constraint(equalTo: inspectorContainer.topAnchor),
            settingsView.leadingAnchor.constraint(equalTo: inspectorContainer.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: inspectorContainer.trailingAnchor),
            settingsView.bottomAnchor.constraint(equalTo: inspectorContainer.bottomAnchor)
        ])

        let mainContent = NSStackView(views: [queueSurface, inspectorContainer])
        mainContent.translatesAutoresizingMaskIntoConstraints = false
        mainContent.orientation = .horizontal
        mainContent.spacing = LauncherTheme.contentGap
        mainContent.alignment = .top
        queueSurface.widthAnchor.constraint(equalToConstant: LauncherTheme.queueWidth).isActive = true
        inspectorContainer.widthAnchor.constraint(equalToConstant: LauncherTheme.inspectorWidth).isActive = true
        inspectorContainer.heightAnchor.constraint(equalToConstant: 374).isActive = true

        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .medium)
        footerLabel.textColor = LauncherTheme.tertiaryText
        footerLabel.alignment = .center
        setShortcutDescription("⌥ Space")

        view.addSubview(header)
        view.addSubview(quickActions)
        view.addSubview(mainContent)
        view.addSubview(footerLabel)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 27),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: LauncherTheme.outerPadding),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -LauncherTheme.outerPadding),

            quickActions.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            quickActions.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            quickActions.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            quickActions.heightAnchor.constraint(equalToConstant: 34),

            mainContent.topAnchor.constraint(equalTo: quickActions.bottomAnchor, constant: 12),
            mainContent.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            mainContent.trailingAnchor.constraint(equalTo: header.trailingAnchor),

            footerLabel.topAnchor.constraint(equalTo: mainContent.bottomAnchor, constant: 14),
            footerLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            footerLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            footerLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -14)
        ])
    }

    private func makeWordmark() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        let baseFont = NSFont.monospacedSystemFont(ofSize: 21, weight: .bold)
        let value = NSMutableAttributedString(
            string: "WHY/WAIT",
            attributes: [
                .font: baseFont,
                .foregroundColor: LauncherTheme.primaryText,
                .kern: -0.7
            ]
        )
        value.addAttribute(.foregroundColor, value: LauncherTheme.accent, range: NSRange(location: 3, length: 1))
        label.attributedStringValue = value
        label.setAccessibilityLabel("WhyWait")
        return label
    }

    private func makeModePill() -> NSView {
        LauncherModePillView()
    }

    private func makeQueueSurface(cards: [GameCardView]) -> NSView {
        let container = LauncherQueueSurfaceView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let heading = NSTextField(labelWithString: "PLAY QUEUE")
        heading.translatesAutoresizingMaskIntoConstraints = false
        heading.font = NSFont.monospacedSystemFont(ofSize: 8.5, weight: .bold)
        heading.textColor = LauncherTheme.secondaryText
        let count = NSTextField(labelWithString: "\(cards.count) ARTIFACTS  /  ONE ACTIVE")
        count.translatesAutoresizingMaskIntoConstraints = false
        count.font = NSFont.monospacedSystemFont(ofSize: 7.5, weight: .medium)
        count.textColor = LauncherTheme.tertiaryText
        count.alignment = .right

        let stack = NSStackView(views: cards)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.distribution = .fill
        cards.forEach { $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }

        container.addSubview(heading)
        container.addSubview(count)
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 374),
            heading.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            heading.topAnchor.constraint(equalTo: container.topAnchor, constant: 9),
            count.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            count.centerYAnchor.constraint(equalTo: heading.centerYAnchor),
            count.leadingAnchor.constraint(greaterThanOrEqualTo: heading.trailingAnchor, constant: 12),
            stack.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 7),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -6)
        ])
        return container
    }

    private func configureQuickActions() {
        playLastButton.translatesAutoresizingMaskIntoConstraints = false
        playLastButton.title = "Resume Last Game"
        playLastButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        playLastButton.imagePosition = .imageLeading
        playLastButton.launcherStyle = .primary
        playLastButton.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        playLastButton.target = self
        playLastButton.action = #selector(playLast)
        playLastButton.heightAnchor.constraint(equalToConstant: 34).isActive = true

        randomButton.translatesAutoresizingMaskIntoConstraints = false
        randomButton.title = "Surprise Me"
        randomButton.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: nil)
        randomButton.imagePosition = .imageLeading
        randomButton.launcherStyle = .secondary
        randomButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        randomButton.target = self
        randomButton.action = #selector(playRandom)
        randomButton.heightAnchor.constraint(equalToConstant: 34).isActive = true
    }

    private func selectGame(id: String) {
        guard let viewModel,
              let index = viewModel.games.firstIndex(where: { $0.metadata.id == id }) else { return }
        selectedIndex = index
        isShowingSettings = false
        updateSelection(animated: true)
    }

    private func updateSelection(animated: Bool) {
        guard let viewModel, !viewModel.games.isEmpty else { return }
        selectedIndex = min(max(0, selectedIndex), viewModel.games.count - 1)
        for (index, card) in cards.enumerated() {
            card.setSelected(index == selectedIndex)
        }
        rail.selectedIndex = selectedIndex
        detailView.configure(game: viewModel.games[selectedIndex])
        if !isShowingSettings { updateInspector(animated: animated) }
    }

    private func updateInspector(animated: Bool) {
        let incoming: NSView = isShowingSettings ? settingsView : detailView
        let outgoing: NSView = isShowingSettings ? detailView : settingsView
        guard animated, !reduceMotion else {
            incoming.alphaValue = 1
            incoming.isHidden = false
            outgoing.alphaValue = 1
            outgoing.isHidden = true
            settingsButton.contentTintColor = isShowingSettings ? LauncherTheme.accent : LauncherTheme.secondaryText
            return
        }

        incoming.alphaValue = 0
        incoming.isHidden = false
        outgoing.isHidden = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            incoming.animator().alphaValue = 1
            outgoing.animator().alphaValue = 0
        } completionHandler: {
            outgoing.isHidden = true
            outgoing.alphaValue = 1
        }
        settingsButton.contentTintColor = isShowingSettings ? LauncherTheme.accent : LauncherTheme.secondaryText
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 43, modifiers.contains(.command) {
            showSettings()
            return true
        }
        if event.keyCode == 53 {
            onHideLauncher?()
            return true
        }
        guard !isShowingSettings, let viewModel, !viewModel.games.isEmpty else { return false }
        switch event.keyCode {
        case 123, 126:
            selectedIndex = max(0, selectedIndex - 1)
        case 124, 125:
            selectedIndex = min(viewModel.games.count - 1, selectedIndex + 1)
        case 36, 76:
            if let selectedGameID { onPlayGame?(selectedGameID) }
            return true
        default:
            return false
        }
        updateSelection(animated: true)
        return true
    }

    @objc private func playLast() { onPlayLastGame?() }
    @objc private func playRandom() { onRandomGame?() }
    @objc private func toggleSettings() {
        isShowingSettings.toggle()
        updateInspector(animated: true)
    }

#if DEBUG
    var diagnosticCardIDs: [String] { cards.map(\.gameID) }
    var diagnosticFooterText: String { footerLabel.stringValue }
    var diagnosticSelectedGameID: String? { selectedGameID }
    var diagnosticSettingsVisible: Bool { isShowingSettings }

    func selectCardForDiagnostics(id: String) { selectGame(id: id) }
    func playCardForDiagnostics(id: String) { onPlayGame?(id) }
    func playLastForDiagnostics() { playLast() }
    func playRandomForDiagnostics() { playRandom() }
    func changeSettingForDiagnostics(_ key: WhyWaitSettingKey, enabled: Bool) {
        onSettingChanged?(key, enabled)
    }
    func changeObjectScaleForDiagnostics(_ value: Double) {
        onObjectScaleChanged?(value)
    }
    func keyEventForDiagnostics(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) {
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        ) else { return }
        _ = handleKeyEvent(event)
    }
#endif
}
