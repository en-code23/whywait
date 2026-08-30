import Foundation

final class FishingSaveStore {
    static let profileFilename = "fishing-profile.json"

    let profileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    convenience init(fileManager: FileManager = .default) {
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
            preserveCorruptProfile()
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
            let data = try encoder.encode(normalized)
            try data.write(to: profileURL, options: .atomic)
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
            return migrated
        default:
            return FishingProfile()
        }
    }

    private func preserveCorruptProfile() {
        guard fileManager.fileExists(atPath: profileURL.path) else { return }
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = UUID().uuidString.prefix(8)
        let preservedURL = profileURL
            .deletingLastPathComponent()
            .appendingPathComponent("fishing-profile.corrupt-\(timestamp)-\(nonce).json")
        do {
            try fileManager.moveItem(at: profileURL, to: preservedURL)
        } catch {
#if DEBUG
            print("Fishing corrupt profile could not be preserved: \(error.localizedDescription)")
#endif
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
