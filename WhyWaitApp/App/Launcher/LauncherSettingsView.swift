import AppKit

private final class FlippedSettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class SettingsToggleRow: NSView {
    let key: WhyWaitSettingKey
    var onToggle: ((WhyWaitSettingKey, Bool) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let toggle = NSSwitch()

    init(key: WhyWaitSettingKey, title: String) {
        self.key = key
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = LauncherTheme.primaryText
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.controlSize = .small
        toggle.target = self
        toggle.action = #selector(changed)
        addSubview(titleLabel)
        addSubview(toggle)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -8),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("SettingsToggleRow does not support NSCoding")
    }

    func setEnabled(_ enabled: Bool) {
        toggle.state = enabled ? .on : .off
    }

    @objc private func changed() {
        onToggle?(key, toggle.state == .on)
    }
}

private final class SettingsScaleRow: NSView {
    var onChange: ((Double) -> Void)?

    private let valueLabel = NSTextField(labelWithString: "100%")
    private let slider = NSSlider(
        value: WhyWaitGameObjectScale.standard,
        minValue: WhyWaitGameObjectScale.minimum,
        maxValue: WhyWaitGameObjectScale.maximum,
        target: nil,
        action: nil
    )

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        titleLabel.textColor = LauncherTheme.primaryText

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        valueLabel.textColor = LauncherTheme.secondaryText
        valueLabel.alignment = .right

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.controlSize = .small
        slider.isContinuous = false
        slider.numberOfTickMarks = 12
        slider.allowsTickMarkValuesOnly = false
        slider.target = self
        slider.action = #selector(changed)

        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(slider)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 52),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
            slider.leadingAnchor.constraint(equalTo: leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor),
            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("SettingsScaleRow does not support NSCoding")
    }

    func setScale(_ value: Double) {
        slider.doubleValue = WhyWaitGameObjectScale.clamped(value)
        updateValueLabel()
    }

    @objc private func changed() {
        let value = WhyWaitGameObjectScale.clamped(slider.doubleValue)
        slider.doubleValue = value
        updateValueLabel()
        onChange?(value)
    }

    private func updateValueLabel() {
        valueLabel.stringValue = "\(Int((slider.doubleValue * 100).rounded()))%"
    }
}

final class LauncherSettingsView: NSView {
    var onToggle: ((WhyWaitSettingKey, Bool) -> Void)?
    var onObjectScaleChanged: ((Double) -> Void)?

    private let contentStack = NSStackView()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let accentLine = NSView()
    private var rows: [WhyWaitSettingKey: SettingsToggleRow] = [:]
    private let objectScaleRow = SettingsScaleRow(title: "Game object size")
    private let languagePicker = NSPopUpButton(frame: .zero, pullsDown: false)

    @objc private func languageChanged() {
        WhyWaitLanguage.current = languagePicker.indexOfSelectedItem == 1 ? .german : .english
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureHierarchy()
    }

    required init?(coder: NSCoder) {
        fatalError("LauncherSettingsView does not support NSCoding")
    }

    func configure(
        settings: WhyWaitSettings,
        launchAtLogin: LaunchAtLoginStatus,
        message: String?
    ) {
        rows[.launchAtLogin]?.setEnabled(launchAtLogin.isEnabled)
        rows[.menuBarEnabled]?.setEnabled(settings.menuBarEnabled)
        rows[.globalShortcutEnabled]?.setEnabled(settings.globalShortcutEnabled)
        rows[.automaticallyCheckForUpdates]?.setEnabled(settings.automaticallyCheckForUpdates)
        rows[.showGameHUD]?.setEnabled(settings.showGameHUD)
        rows[.reduceVisualEffects]?.setEnabled(settings.reduceVisualEffects)
        rows[.cursorTrailEffects]?.setEnabled(settings.cursorTrailEffects)
        objectScaleRow.setScale(settings.gameObjectScale)
        languagePicker.selectItem(at: WhyWaitLanguage.current == .german ? 1 : 0)
        rows[.escapeReturnsToLauncher]?.setEnabled(settings.escapeReturnsToLauncher)
        rows[.automaticallyReopenLauncher]?.setEnabled(settings.automaticallyReopenLauncher)
        statusLabel.stringValue = message ?? launchAtLogin.message ?? ""
        statusLabel.isHidden = statusLabel.stringValue.isEmpty
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applySurfaceAppearance()
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
        accentLine.layer?.backgroundColor = LauncherTheme.resolved(LauncherTheme.accent, for: self).cgColor

        let systemLabel = NSTextField(labelWithString: "SYSTEM  /  LOCAL")
        systemLabel.translatesAutoresizingMaskIntoConstraints = false
        systemLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .semibold)
        systemLabel.textColor = LauncherTheme.accent

        let title = NSTextField(labelWithString: "Preferences")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        title.textColor = LauncherTheme.primaryText

        let subtitle = NSTextField(labelWithString: "Tune the intermission, keep the desktop quiet.")
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        subtitle.textColor = LauncherTheme.secondaryText

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 0

        // A native bilingual selector, placed before the compact existing sections.
        let languageLabel = NSTextField(labelWithString: "Language / Sprache")
        languageLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        languagePicker.addItems(withTitles: ["English", "Deutsch"])
        languagePicker.controlSize = .small
        languagePicker.target = self
        languagePicker.action = #selector(languageChanged)
        languagePicker.setAccessibilityLabel("Language / Sprache")
        let languageRow = NSStackView(views: [languageLabel, languagePicker])
        languageRow.distribution = .fillEqually
        languageRow.spacing = 8
        contentStack.addArrangedSubview(languageRow)
        languageRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        languageRow.heightAnchor.constraint(equalToConstant: 38).isActive = true

        addSection("GENERAL", rows: [
            (.launchAtLogin, "Launch WhyWait at login"),
            (.menuBarEnabled, "Keep menu-bar icon enabled"),
            (.globalShortcutEnabled, "Global shortcut enabled"),
            (.automaticallyCheckForUpdates, "Automatically check for updates")
        ])
        addSection("GAMEPLAY", rows: [
            (.showGameHUD, "Show game HUD"),
            (.reduceVisualEffects, "Reduce visual effects"),
            (.cursorTrailEffects, "Cursor trail effects")
        ])
        objectScaleRow.onChange = { [weak self] value in
            self?.onObjectScaleChanged?(value)
        }
        contentStack.addArrangedSubview(objectScaleRow)
        objectScaleRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        addSection("BEHAVIOR", rows: [
            (.escapeReturnsToLauncher, "Escape returns to launcher"),
            (.automaticallyReopenLauncher, "Reopen launcher after game ends")
        ])

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        statusLabel.textColor = LauncherTheme.secondaryText
        statusLabel.maximumNumberOfLines = 3

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        let document = FlippedSettingsDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(contentStack)
        scrollView.documentView = document
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: document.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        addSubview(accentLine)
        addSubview(systemLabel)
        addSubview(title)
        addSubview(subtitle)
        addSubview(scrollView)
        addSubview(statusLabel)
        NSLayoutConstraint.activate([
            accentLine.topAnchor.constraint(equalTo: topAnchor),
            accentLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            accentLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            accentLine.heightAnchor.constraint(equalToConstant: 2),
            systemLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            systemLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            systemLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            title.topAnchor.constraint(equalTo: systemLabel.bottomAnchor, constant: 7),
            title.leadingAnchor.constraint(equalTo: systemLabel.leadingAnchor),
            title.trailingAnchor.constraint(equalTo: systemLabel.trailingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
            statusLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 14)
        ])
    }

    private func applySurfaceAppearance() {
        layer?.backgroundColor = LauncherTheme.resolved(LauncherTheme.surfaceRaised, for: self).cgColor
        layer?.borderColor = LauncherTheme.resolved(LauncherTheme.border, for: self).cgColor
        accentLine.layer?.backgroundColor = LauncherTheme.resolved(LauncherTheme.accent, for: self).cgColor
    }

    private func addSection(
        _ title: String,
        rows descriptors: [(WhyWaitSettingKey, String)]
    ) {
        let heading = NSTextField(labelWithString: title)
        heading.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .bold)
        heading.textColor = LauncherTheme.accent.withAlphaComponent(0.82)
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        heading.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(heading)
        NSLayoutConstraint.activate([
            wrapper.heightAnchor.constraint(equalToConstant: rows.isEmpty ? 18 : 24),
            heading.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            heading.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -4)
        ])
        contentStack.addArrangedSubview(wrapper)
        wrapper.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        for (key, rowTitle) in descriptors {
            let row = SettingsToggleRow(key: key, title: rowTitle)
            row.onToggle = { [weak self] key, value in self?.onToggle?(key, value) }
            rows[key] = row
            contentStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }
    }
}
