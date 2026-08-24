import AppKit

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
    private let playLastButton = NSButton()
    private let randomButton = NSButton()
    private let settingsButton = NSButton()
    private let detailView = GameDetailView()
    private let settingsView = LauncherSettingsView()
    private var cards: [GameCardView] = []
    private var viewModel: LauncherViewModel?
    private var selectedIndex = 0
    private var isShowingSettings = false

    init(games: [MinigameMetadata]) {
        metadata = games
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("LauncherViewController does not support NSCoding")
    }

    override func loadView() {
        let root = LauncherRootView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        root.onKeyEvent = { [weak self] event in self?.handleKeyEvent(event) == true }
        view = root
        buildInterface()
    }

    var preferredFirstResponder: NSResponder { view }

    func refresh(_ viewModel: LauncherViewModel) {
        _ = view
        let previouslySelectedID = selectedGameID
        self.viewModel = viewModel
        for (index, card) in cards.enumerated() where index < viewModel.games.count {
            card.update(game: viewModel.games[index])
            card.setLastPlayed(card.gameID == viewModel.lastPlayedID)
        }
        rail.highlightedIndex = viewModel.games.firstIndex {
            $0.metadata.id == viewModel.lastPlayedID
        }
        sessionSummaryLabel.stringValue = viewModel.globalSummary.uppercased()
        playLastButton.isHidden = viewModel.lastPlayedID == nil
        if let lastID = viewModel.lastPlayedID,
           let game = viewModel.games.first(where: { $0.metadata.id == lastID }) {
            playLastButton.title = "Play Last — \(game.metadata.name)"
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
        footerLabel.stringValue = "← ↑ ↓ →  SELECT     •     RETURN  PLAY     •     ⌘,  SETTINGS     •     ESC  HIDE     •     \(description.uppercased())  OPEN"
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
        let title = NSTextField(labelWithString: "WHYWAIT")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = NSFont.systemFont(ofSize: 25, weight: .bold).withDesign(.rounded)
        title.textColor = LauncherTheme.primaryText

        let subtitle = NSTextField(labelWithString: "Pick something small while the big work runs.")
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = LauncherTheme.secondaryText

        sessionSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        sessionSummaryLabel.font = NSFont.monospacedSystemFont(ofSize: 8.5, weight: .medium)
        sessionSummaryLabel.textColor = LauncherTheme.tertiaryText
        sessionSummaryLabel.alignment = .right
        sessionSummaryLabel.lineBreakMode = .byTruncatingHead

        rail.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.title = ""
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        settingsButton.bezelStyle = .texturedRounded
        settingsButton.target = self
        settingsButton.action = #selector(toggleSettings)
        settingsButton.toolTip = "Settings (⌘,)"

        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        [title, subtitle, sessionSummaryLabel, rail, settingsButton].forEach(header.addSubview)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            title.topAnchor.constraint(equalTo: header.topAnchor),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3),
            settingsButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            settingsButton.topAnchor.constraint(equalTo: header.topAnchor, constant: 1),
            settingsButton.widthAnchor.constraint(equalToConstant: 34),
            settingsButton.heightAnchor.constraint(equalToConstant: 30),
            sessionSummaryLabel.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -10),
            sessionSummaryLabel.centerYAnchor.constraint(equalTo: settingsButton.centerYAnchor),
            sessionSummaryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: subtitle.trailingAnchor, constant: 20),
            rail.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            rail.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            rail.widthAnchor.constraint(equalToConstant: 156),
            rail.heightAnchor.constraint(equalToConstant: 5),
            header.heightAnchor.constraint(equalToConstant: 57)
        ])

        configureQuickActions()
        let quickActions = NSStackView(views: [playLastButton, randomButton])
        quickActions.translatesAutoresizingMaskIntoConstraints = false
        quickActions.orientation = .horizontal
        quickActions.spacing = 10
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

        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = LauncherTheme.gridGap
        grid.columnSpacing = LauncherTheme.gridGap
        grid.xPlacement = .fill
        grid.yPlacement = .fill
        for index in stride(from: 0, to: cards.count, by: 2) {
            let second: NSView = index + 1 < cards.count ? cards[index + 1] : NSView()
            grid.addRow(with: [cards[index], second])
        }

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

        let mainContent = NSStackView(views: [grid, inspectorContainer])
        mainContent.translatesAutoresizingMaskIntoConstraints = false
        mainContent.orientation = .horizontal
        mainContent.spacing = 14
        mainContent.alignment = .top
        grid.widthAnchor.constraint(equalToConstant: 570).isActive = true
        inspectorContainer.widthAnchor.constraint(equalToConstant: 248).isActive = true
        inspectorContainer.heightAnchor.constraint(equalToConstant: 374).isActive = true

        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = NSFont.monospacedSystemFont(ofSize: 8.5, weight: .medium)
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

            quickActions.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            quickActions.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            quickActions.heightAnchor.constraint(equalToConstant: 34),

            mainContent.topAnchor.constraint(equalTo: quickActions.bottomAnchor, constant: 14),
            mainContent.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            mainContent.trailingAnchor.constraint(equalTo: header.trailingAnchor),

            footerLabel.topAnchor.constraint(equalTo: mainContent.bottomAnchor, constant: 15),
            footerLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            footerLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            footerLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -14)
        ])
    }

    private func configureQuickActions() {
        playLastButton.translatesAutoresizingMaskIntoConstraints = false
        playLastButton.title = "Play Last Game"
        playLastButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        playLastButton.imagePosition = .imageLeading
        playLastButton.bezelStyle = .rounded
        playLastButton.controlSize = .large
        playLastButton.bezelColor = LauncherTheme.accent
        playLastButton.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        playLastButton.target = self
        playLastButton.action = #selector(playLast)
        playLastButton.heightAnchor.constraint(equalToConstant: 34).isActive = true

        randomButton.translatesAutoresizingMaskIntoConstraints = false
        randomButton.title = "Random Game"
        randomButton.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: nil)
        randomButton.imagePosition = .imageLeading
        randomButton.bezelStyle = .rounded
        randomButton.controlSize = .large
        randomButton.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
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
        detailView.configure(game: viewModel.games[selectedIndex])
        if !isShowingSettings { updateInspector(animated: animated) }
    }

    private func updateInspector(animated: Bool) {
        let changes = { [self] in
            detailView.isHidden = isShowingSettings
            settingsView.isHidden = !isShowingSettings
            settingsButton.contentTintColor = isShowingSettings ? LauncherTheme.accent : nil
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
        case 123:
            selectedIndex = max(0, selectedIndex - 1)
        case 124:
            selectedIndex = min(viewModel.games.count - 1, selectedIndex + 1)
        case 125:
            selectedIndex = min(viewModel.games.count - 1, selectedIndex + 2)
        case 126:
            selectedIndex = max(0, selectedIndex - 2)
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

private extension NSFont {
    func withDesign(_ design: NSFontDescriptor.SystemDesign) -> NSFont {
        guard let descriptor = fontDescriptor.withDesign(design) else { return self }
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
