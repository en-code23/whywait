import AppKit

/// Compact launcher affordance for updates. The cyan waitline keeps the state
/// visually related to WhyWait without turning updates into a modal dashboard.
final class WhyWaitUpdateAccessoryView: NSView {
    var onAction: (() -> Void)?

    private let statusDot = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let actionButton = LauncherActionButton()
    private let activity = NSProgressIndicator()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildInterface()
        update(state: .idle)
    }

    required init?(coder: NSCoder) {
        fatalError("WhyWaitUpdateAccessoryView does not support NSCoding")
    }

    func update(state: WhyWaitUpdaterState) {
        activity.stopAnimation(nil)
        activity.isHidden = true
        actionButton.isHidden = false
        actionButton.isEnabled = true

        switch state {
        case .idle, .upToDate:
            isHidden = true
        case .checking:
            isHidden = false
            statusLabel.stringValue = "CHECKING RELEASES"
            actionButton.isHidden = true
            activity.isHidden = false
            activity.startAnimation(nil)
        case let .updateAvailable(release):
            isHidden = false
            statusLabel.stringValue = "v\(release.version) READY"
            actionButton.title = "Download"
        case let .downloading(release):
            showBusy("GETTING v\(release.version)")
        case let .preparing(release):
            showBusy("VERIFYING v\(release.version)")
        case let .readyToInstall(prepared):
            isHidden = false
            statusLabel.stringValue = "v\(prepared.release.version) VERIFIED"
            actionButton.title = "Restart & Update"
        case .installing:
            showBusy("INSTALLING")
        case .failed:
            isHidden = false
            statusLabel.stringValue = "UPDATE PAUSED"
            actionButton.title = "Details"
        }
        setAccessibilityLabel(statusLabel.stringValue)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    private func buildInterface() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1

        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 2

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .semibold)
        statusLabel.textColor = LauncherTheme.accent
        statusLabel.lineBreakMode = .byTruncatingTail

        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.style = .spinning
        activity.controlSize = .small

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.launcherStyle = .quiet
        actionButton.font = NSFont.systemFont(ofSize: 9.5, weight: .semibold)
        actionButton.target = self
        actionButton.action = #selector(performAction)

        addSubview(statusDot)
        addSubview(statusLabel)
        addSubview(activity)
        addSubview(actionButton)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 30),
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            statusDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 4),
            statusDot.heightAnchor.constraint(equalToConstant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 116),
            activity.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 7),
            activity.centerYAnchor.constraint(equalTo: centerYAnchor),
            activity.widthAnchor.constraint(equalToConstant: 14),
            activity.heightAnchor.constraint(equalToConstant: 14),
            actionButton.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 5),
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 24),
            trailingAnchor.constraint(greaterThanOrEqualTo: activity.trailingAnchor, constant: 8)
        ])
        applyAppearance()
    }

    private func showBusy(_ title: String) {
        isHidden = false
        statusLabel.stringValue = title
        actionButton.isHidden = true
        activity.isHidden = false
        activity.startAnimation(nil)
    }

    private func applyAppearance() {
        layer?.backgroundColor = LauncherTheme.resolved(
            LauncherTheme.accent.withAlphaComponent(0.07),
            for: self
        ).cgColor
        layer?.borderColor = LauncherTheme.resolved(
            LauncherTheme.accent.withAlphaComponent(0.18),
            for: self
        ).cgColor
        statusDot.layer?.backgroundColor = LauncherTheme.resolved(LauncherTheme.accent, for: self).cgColor
    }

    @objc private func performAction() {
        onAction?()
    }
}
