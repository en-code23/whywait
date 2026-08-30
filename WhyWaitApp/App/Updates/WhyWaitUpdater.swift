import Foundation

enum WhyWaitUpdaterState {
    case idle
    case checking
    case upToDate(WhyWaitSemanticVersion)
    case updateAvailable(WhyWaitUpdateRelease)
    case downloading(WhyWaitUpdateRelease)
    case preparing(WhyWaitUpdateRelease)
    case readyToInstall(WhyWaitPreparedInstallation)
    case installing(WhyWaitUpdateRelease)
    case failed(message: String, fallbackURL: URL)
}

/// Main-thread orchestration for launcher/menu UI. It deliberately does not
/// terminate the app: the shell calls `beginInstallation()` and, on success,
/// performs its normal coordinated shutdown.
@MainActor
final class WhyWaitUpdater {
    var onStateChange: ((WhyWaitUpdaterState) -> Void)?
    var onBackgroundCheckError: ((Error) -> Void)?

    private(set) var state: WhyWaitUpdaterState = .idle {
        didSet { onStateChange?(state) }
    }

    private let service: WhyWaitUpdateService
    private let installer: WhyWaitUpdateInstaller
    private var operation: Task<Void, Never>?
    private var generation = 0

    init(
        service: WhyWaitUpdateService = WhyWaitUpdateService(),
        installer: WhyWaitUpdateInstaller = WhyWaitUpdateInstaller()
    ) {
        self.service = service
        self.installer = installer
    }

    var fallbackReleaseURL: URL { service.fallbackReleaseURL }

    func startAutomaticCheck(after delay: TimeInterval = 2) {
        startCheck(delay: min(max(delay, 0), 60), reportsFailures: false)
    }

    func checkNow() {
        startCheck(delay: 0, reportsFailures: true)
    }

    func downloadAndPrepare(_ release: WhyWaitUpdateRelease? = nil) {
        let selectedRelease: WhyWaitUpdateRelease?
        if let release {
            selectedRelease = release
        } else if case let .updateAvailable(available) = state {
            selectedRelease = available
        } else {
            selectedRelease = nil
        }
        guard let selectedRelease else {
            state = .failed(
                message: WhyWaitUpdateError.invalidUpdaterState.localizedDescription,
                fallbackURL: fallbackReleaseURL
            )
            return
        }

        cancelOperation(discardPreparedUpdate: true)
        generation += 1
        let operationGeneration = generation
        state = .downloading(selectedRelease)
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                let downloaded = try await service.download(selectedRelease)
                try Task.checkCancellation()
                guard operationGeneration == generation else { return }
                state = .preparing(selectedRelease)
                let currentBundleURL = Bundle.main.bundleURL
                let prepared = try await Task.detached(priority: .userInitiated) { [installer] in
                    try installer.prepareInstallation(
                        from: downloaded,
                        replacing: currentBundleURL
                    )
                }.value
                try Task.checkCancellation()
                guard operationGeneration == generation else {
                    installer.discard(prepared)
                    return
                }
                state = .readyToInstall(prepared)
            } catch is CancellationError {
                guard operationGeneration == generation else { return }
                state = .idle
            } catch {
                guard operationGeneration == generation else { return }
                state = .failed(
                    message: error.localizedDescription,
                    fallbackURL: selectedRelease.releasePageURL
                )
            }
        }
    }

    /// Returns only after the detached replacement helper has started. The app
    /// shell should then stop its game/session state and terminate normally.
    func beginInstallation() throws {
        guard case let .readyToInstall(prepared) = state else {
            throw WhyWaitUpdateError.invalidUpdaterState
        }
        try installer.launchInstallationHelper(prepared)
        state = .installing(prepared.release)
    }

    func cancel() {
        cancelOperation(discardPreparedUpdate: true)
        state = .idle
    }

    private func startCheck(delay: TimeInterval, reportsFailures: Bool) {
        cancelOperation(discardPreparedUpdate: true)
        generation += 1
        let operationGeneration = generation
        state = .checking
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                let result = try await service.checkForUpdates()
                try Task.checkCancellation()
                guard operationGeneration == generation else { return }
                switch result {
                case let .upToDate(version):
                    state = .upToDate(version)
                case let .updateAvailable(release):
                    state = .updateAvailable(release)
                }
            } catch is CancellationError {
                guard operationGeneration == generation else { return }
                state = .idle
            } catch {
                guard operationGeneration == generation else { return }
                if reportsFailures {
                    state = .failed(
                        message: error.localizedDescription,
                        fallbackURL: fallbackReleaseURL
                    )
                } else {
                    state = .idle
                    onBackgroundCheckError?(error)
                }
            }
        }
    }

    private func cancelOperation(discardPreparedUpdate: Bool) {
        operation?.cancel()
        operation = nil
        generation += 1
        if discardPreparedUpdate,
           case let .readyToInstall(prepared) = state {
            installer.discard(prepared)
        }
    }
}
