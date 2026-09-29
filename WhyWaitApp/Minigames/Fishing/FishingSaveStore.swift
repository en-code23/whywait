import Foundation
import Darwin

final class FishingSaveStore {
    static let profileFilename = "fishing-profile.json"

    let profileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var loadedData: Data?
    private var hasLoaded = false
    private var canWrite = true
#if DEBUG
    private static let diagnosticDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("WhyWait-shell-fishing-\(UUID().uuidString)", isDirectory: true)
#endif

    convenience init(fileManager: FileManager = .default) {
#if DEBUG
        if let path = ProcessInfo.processInfo.environment["WHYWAIT_FISHING_PROFILE_DIRECTORY"] {
            self.init(directoryURL: URL(fileURLWithPath: path, isDirectory: true), fileManager: fileManager)
            return
        }
        if ProcessInfo.processInfo.environment["WHYWAIT_APP_SHELL_TESTS"] == "1" {
            self.init(directoryURL: Self.diagnosticDirectory, fileManager: fileManager)
            return
        }
#endif
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        self.init(
            directoryURL: applicationSupport.appendingPathComponent(
                "WhyWait",
                isDirectory: true
            ),
            fileManager: fileManager
        )
    }

    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        profileURL = directoryURL.appendingPathComponent(Self.profileFilename)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func load() -> FishingProfile {
        hasLoaded = true
        canWrite = true
        loadedData = try? Data(contentsOf: profileURL)
        guard fileManager.fileExists(atPath: profileURL.path) else {
            return FishingProfile()
        }

        do {
            let data = try Data(contentsOf: profileURL)
            var profile = try decoder.decode(FishingProfile.self, from: data)
            guard profile.version <= FishingProfile.currentVersion else {
                throw FishingSaveError.unsupportedVersion(profile.version)
            }
            profile = migrate(profile)
            profile.normalize()
            return profile
        } catch {
            if case FishingSaveError.unsupportedVersion = error {
                canWrite = false
            } else {
                canWrite = preserveCorruptProfile()
                if canWrite { loadedData = nil }
            }
#if DEBUG
            print("Fishing profile could not be loaded: \(error.localizedDescription)")
#endif
            return FishingProfile()
        }
    }

    @discardableResult
    func save(_ profile: FishingProfile) -> Bool {
        do {
            var normalized = profile
            normalized.version = FishingProfile.currentVersion
            normalized.normalize()
            let directory = profileURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            // Serialize writers across scenes AND app copies. Refuse stale snapshots
            // instead of resurrecting coins spent by a more recent session.
            let lockURL = directory.appendingPathComponent("fishing-profile.lock")
            let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
            guard descriptor >= 0 else { return false }
            defer { flock(descriptor, LOCK_UN); close(descriptor) }
            guard flock(descriptor, LOCK_EX) == 0, canWrite else { return false }
            let currentData = try? Data(contentsOf: profileURL)
            guard (hasLoaded && currentData == loadedData)
                || (!hasLoaded && currentData == nil) else { return false }
            let data = try encoder.encode(normalized)
            try data.write(to: profileURL, options: .atomic)
            loadedData = data
            hasLoaded = true
            return true
        } catch {
#if DEBUG
            print("Fishing profile could not be saved: \(error.localizedDescription)")
#endif
            return false
        }
    }

    private func migrate(_ profile: FishingProfile) -> FishingProfile {
        var migrated = profile
        switch migrated.version {
        case 1:
            // v2 adds Tidevault specimens, variant discoveries, and tackle
            // inventory. decodeIfPresent supplies lossless defaults for old saves.
            migrated.version = 2
            fallthrough
        case 2:
            migrated.version = 3
            fallthrough
        case 3:
            return migrated
        default:
            return FishingProfile()
        }
    }

    private func preserveCorruptProfile() -> Bool {
        guard fileManager.fileExists(atPath: profileURL.path) else { return true }
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = UUID().uuidString.prefix(8)
        let preservedURL = profileURL
            .deletingLastPathComponent()
            .appendingPathComponent("fishing-profile.corrupt-\(timestamp)-\(nonce).json")
        do {
            try fileManager.moveItem(at: profileURL, to: preservedURL)
            return true
        } catch {
#if DEBUG
            print("Fishing corrupt profile could not be preserved: \(error.localizedDescription)")
#endif
            return false
        }
    }
}

private enum FishingSaveError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            return "Unsupported Fishing save version \(version)"
        }
    }
}
