import Foundation

/// A small SemVer implementation used by the updater. App Store style two-part
/// versions (for example `1.4`) are accepted and normalized to `1.4.0`.
struct WhyWaitSemanticVersion: Comparable, CustomStringConvertible, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
    let prereleaseIdentifiers: [String]
    let buildIdentifiers: [String]

    init?(_ value: String) {
        var candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.first == "v" || candidate.first == "V" {
            candidate.removeFirst()
        }

        let buildParts = candidate.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        guard !buildParts[0].isEmpty,
              buildParts.count == 1 || !buildParts[1].isEmpty else { return nil }

        let versionParts = buildParts[0].split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard !versionParts[0].isEmpty,
              versionParts.count == 1 || !versionParts[1].isEmpty else { return nil }

        let core = versionParts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(core.count),
              core.allSatisfy({ Self.isValidCoreNumber(String($0)) }) else { return nil }

        let numbers = core.compactMap { Int($0) }
        guard numbers.count == core.count else { return nil }
        major = numbers[0]
        minor = numbers.count > 1 ? numbers[1] : 0
        patch = numbers.count > 2 ? numbers[2] : 0

        let prerelease = versionParts.count > 1
            ? versionParts[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            : []
        let build = buildParts.count > 1
            ? buildParts[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            : []
        guard prerelease.allSatisfy(Self.isValidIdentifier),
              build.allSatisfy(Self.isValidIdentifier),
              prerelease.allSatisfy(Self.isValidPrereleaseIdentifier) else { return nil }
        prereleaseIdentifiers = prerelease
        buildIdentifiers = build
    }

    var description: String {
        var value = "\(major).\(minor).\(patch)"
        if !prereleaseIdentifiers.isEmpty {
            value += "-" + prereleaseIdentifiers.joined(separator: ".")
        }
        if !buildIdentifiers.isEmpty {
            value += "+" + buildIdentifiers.joined(separator: ".")
        }
        return value
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.major == rhs.major
            && lhs.minor == rhs.minor
            && lhs.patch == rhs.patch
            && lhs.prereleaseIdentifiers == rhs.prereleaseIdentifiers
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        let leftCore = (lhs.major, lhs.minor, lhs.patch)
        let rightCore = (rhs.major, rhs.minor, rhs.patch)
        if leftCore != rightCore {
            if lhs.major != rhs.major { return lhs.major < rhs.major }
            if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
            return lhs.patch < rhs.patch
        }

        if lhs.prereleaseIdentifiers.isEmpty { return false }
        if rhs.prereleaseIdentifiers.isEmpty { return true }

        for index in 0..<min(lhs.prereleaseIdentifiers.count, rhs.prereleaseIdentifiers.count) {
            let left = lhs.prereleaseIdentifiers[index]
            let right = rhs.prereleaseIdentifiers[index]
            if left == right { continue }
            let leftNumber = Int(left)
            let rightNumber = Int(right)
            switch (leftNumber, rightNumber) {
            case let (.some(a), .some(b)):
                return a < b
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return left < right
            }
        }
        return lhs.prereleaseIdentifiers.count < rhs.prereleaseIdentifiers.count
    }

    private static func isValidCoreNumber(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.allSatisfy(\.isNumber),
              value == "0" || value.first != "0" else { return false }
        return Int(value) != nil
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        return value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "-"
        }
    }

    private static func isValidPrereleaseIdentifier(_ value: String) -> Bool {
        guard value.allSatisfy(\.isNumber) else { return true }
        return value == "0" || value.first != "0"
    }
}

struct WhyWaitUpdateConfiguration: Sendable {
    static let standard = WhyWaitUpdateConfiguration()

    var owner = "en-code23"
    var repository = "whywait"
    var assetName = "WhyWait-macOS.zip"
    var expectedBundleIdentifier = "com.whywait.app"
    var maximumDownloadSize: Int64 = 250 * 1_024 * 1_024

    var releasesURL: URL {
        URL(string: "https://github.com/\(owner)/\(repository)/releases")!
    }

    var latestReleaseAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!
    }
}

struct WhyWaitUpdateRelease: Equatable, Sendable {
    let version: WhyWaitSemanticVersion
    let tagName: String
    let title: String
    let releasePageURL: URL
    let downloadURL: URL
    let assetName: String
    let assetSize: Int64
    let sha256: String?
    let publishedAt: Date?
}

enum WhyWaitUpdateCheckResult: Equatable, Sendable {
    case upToDate(latestVersion: WhyWaitSemanticVersion)
    case updateAvailable(WhyWaitUpdateRelease)
}

struct WhyWaitDownloadedUpdate: Sendable {
    let release: WhyWaitUpdateRelease
    let archiveURL: URL
}

struct WhyWaitValidatedApplication: Sendable {
    let bundleURL: URL
    let bundleIdentifier: String
    let version: WhyWaitSemanticVersion
}

enum WhyWaitUpdateError: LocalizedError, Sendable {
    case missingCurrentVersion
    case invalidCurrentVersion(String)
    case invalidReleaseResponse
    case invalidReleaseVersion(String)
    case releaseIsNotInstallable
    case assetMissing(String)
    case invalidServerResponse(Int)
    case downloadTooLarge(Int64)
    case downloadSizeMismatch(expected: Int64, actual: Int64)
    case missingDigest
    case digestMismatch(expected: String, actual: String)
    case extractionFailed(String)
    case applicationMissing
    case invalidApplication(String)
    case bundleIdentifierMismatch(expected: String, actual: String?)
    case applicationVersionMismatch(expected: WhyWaitSemanticVersion, actual: WhyWaitSemanticVersion)
    case signatureInvalid(String)
    case unsafeInstallLocation(URL)
    case installLocationNotWritable(URL)
    case helperLaunchFailed(String)
    case invalidUpdaterState

    var errorDescription: String? {
        switch self {
        case .missingCurrentVersion:
            return "WhyWait's current version could not be read."
        case let .invalidCurrentVersion(value):
            return "WhyWait's current version is invalid: \(value)."
        case .invalidReleaseResponse:
            return "GitHub returned release information WhyWait could not read."
        case let .invalidReleaseVersion(value):
            return "The release has an invalid version tag: \(value)."
        case .releaseIsNotInstallable:
            return "The latest GitHub release is a draft or prerelease."
        case let .assetMissing(name):
            return "The release does not contain \(name)."
        case let .invalidServerResponse(status):
            return "The update server returned HTTP \(status)."
        case let .downloadTooLarge(size):
            return "The update is unexpectedly large (\(size) bytes)."
        case let .downloadSizeMismatch(expected, actual):
            return "The update download is incomplete (expected \(expected), received \(actual) bytes)."
        case .missingDigest:
            return "The update has no SHA-256 digest."
        case let .digestMismatch(expected, actual):
            return "The update checksum does not match (expected \(expected), received \(actual))."
        case let .extractionFailed(reason):
            return "The update could not be unpacked: \(reason)"
        case .applicationMissing:
            return "The update archive does not contain WhyWait.app."
        case let .invalidApplication(reason):
            return "The downloaded application is invalid: \(reason)"
        case let .bundleIdentifierMismatch(expected, actual):
            return "The downloaded app has bundle identifier \(actual ?? "missing"), expected \(expected)."
        case let .applicationVersionMismatch(expected, actual):
            return "The downloaded app is version \(actual), expected \(expected)."
        case let .signatureInvalid(reason):
            return "The downloaded app failed code-signature validation: \(reason)"
        case let .unsafeInstallLocation(url):
            return "WhyWait cannot safely update from \(url.path)."
        case let .installLocationNotWritable(url):
            return "WhyWait cannot replace the copy in \(url.path). Download the update manually instead."
        case let .helperLaunchFailed(reason):
            return "The update installer could not start: \(reason)"
        case .invalidUpdaterState:
            return "The updater is not ready for that action."
        }
    }
}
