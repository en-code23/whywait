import CryptoKit
import Foundation

final class WhyWaitUpdateService: @unchecked Sendable {
    let configuration: WhyWaitUpdateConfiguration

    private let session: URLSession
    private let fileManager: FileManager

    init(
        configuration: WhyWaitUpdateConfiguration = .standard,
        session: URLSession? = nil,
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        if let session {
            self.session = session
        } else {
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
            sessionConfiguration.timeoutIntervalForRequest = 20
            sessionConfiguration.timeoutIntervalForResource = 120
            self.session = URLSession(configuration: sessionConfiguration)
        }
    }

    var fallbackReleaseURL: URL { configuration.releasesURL }

    /// Checks GitHub's `latest` release endpoint. Calling this method at launch
    /// is intentionally cheap and has no filesystem side effects.
    func checkForUpdates(
        currentVersionString: String? = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
    ) async throws -> WhyWaitUpdateCheckResult {
        guard let currentVersionString else {
            throw WhyWaitUpdateError.missingCurrentVersion
        }
        guard let currentVersion = WhyWaitSemanticVersion(currentVersionString) else {
            throw WhyWaitUpdateError.invalidCurrentVersion(currentVersionString)
        }

        var request = URLRequest(url: configuration.latestReleaseAPIURL)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("WhyWait/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        try Self.validateHTTPResponse(response)
        let release = try Self.parseRelease(data: data, configuration: configuration)
        if release.version > currentVersion {
            return .updateAvailable(release)
        }
        return .upToDate(latestVersion: release.version)
    }

    /// Downloads to an updater-owned temporary directory and verifies the
    /// release asset's byte count and mandatory published SHA-256 digest.
    func download(_ release: WhyWaitUpdateRelease) async throws -> WhyWaitDownloadedUpdate {
        guard let expectedDigest = release.sha256 else {
            throw WhyWaitUpdateError.missingDigest
        }
        guard release.assetSize <= configuration.maximumDownloadSize else {
            throw WhyWaitUpdateError.downloadTooLarge(release.assetSize)
        }

        var request = URLRequest(url: release.downloadURL)
        request.httpMethod = "GET"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("WhyWait-Updater/\(release.version)", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await session.download(for: request)
        try Self.validateHTTPResponse(response)

        let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
        let actualSize = Int64(values.fileSize ?? 0)
        guard actualSize > 0 else {
            throw WhyWaitUpdateError.downloadSizeMismatch(
                expected: release.assetSize,
                actual: actualSize
            )
        }
        if release.assetSize > 0, actualSize != release.assetSize {
            throw WhyWaitUpdateError.downloadSizeMismatch(
                expected: release.assetSize,
                actual: actualSize
            )
        }
        guard actualSize <= configuration.maximumDownloadSize else {
            throw WhyWaitUpdateError.downloadTooLarge(actualSize)
        }

        let actualDigest = try WhyWaitUpdateDigest.sha256(of: temporaryURL)
        guard actualDigest.caseInsensitiveCompare(expectedDigest) == .orderedSame else {
            throw WhyWaitUpdateError.digestMismatch(
                expected: expectedDigest,
                actual: actualDigest
            )
        }

        let updateDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("WhyWaitUpdates", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: updateDirectory, withIntermediateDirectories: true)
        let destination = updateDirectory.appendingPathComponent(release.assetName)
        do {
            try fileManager.moveItem(at: temporaryURL, to: destination)
        } catch {
            try fileManager.copyItem(at: temporaryURL, to: destination)
        }
        return WhyWaitDownloadedUpdate(release: release, archiveURL: destination)
    }

    static func parseRelease(
        data: Data,
        configuration: WhyWaitUpdateConfiguration = .standard
    ) throws -> WhyWaitUpdateRelease {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload: GitHubReleasePayload
        do {
            payload = try decoder.decode(GitHubReleasePayload.self, from: data)
        } catch {
            throw WhyWaitUpdateError.invalidReleaseResponse
        }

        guard !payload.draft, !payload.prerelease else {
            throw WhyWaitUpdateError.releaseIsNotInstallable
        }
        guard let version = WhyWaitSemanticVersion(payload.tagName) else {
            throw WhyWaitUpdateError.invalidReleaseVersion(payload.tagName)
        }
        guard let asset = payload.assets.first(where: { $0.name == configuration.assetName }) else {
            throw WhyWaitUpdateError.assetMissing(configuration.assetName)
        }
        guard asset.size >= 0, asset.size <= configuration.maximumDownloadSize else {
            throw WhyWaitUpdateError.downloadTooLarge(asset.size)
        }
        guard Self.isTrustedGitHubURL(asset.downloadURL),
              Self.isTrustedGitHubURL(payload.htmlURL) else {
            throw WhyWaitUpdateError.invalidReleaseResponse
        }

        let digest = WhyWaitUpdateDigest.normalizedSHA256(asset.digest)
            ?? WhyWaitUpdateDigest.digestInReleaseBody(
                payload.body ?? "",
                assetName: configuration.assetName
            )
        guard let digest else {
            throw WhyWaitUpdateError.missingDigest
        }
        return WhyWaitUpdateRelease(
            version: version,
            tagName: payload.tagName,
            title: payload.name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? payload.tagName,
            releasePageURL: payload.htmlURL,
            downloadURL: asset.downloadURL,
            assetName: asset.name,
            assetSize: asset.size,
            sha256: digest,
            publishedAt: payload.publishedAt
        )
    }

    private static func validateHTTPResponse(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            throw WhyWaitUpdateError.invalidReleaseResponse
        }
        guard (200...299).contains(response.statusCode) else {
            throw WhyWaitUpdateError.invalidServerResponse(response.statusCode)
        }
    }

    private static func isTrustedGitHubURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else {
            return false
        }
        return host == "github.com"
            || host == "api.github.com"
            || host == "objects.githubusercontent.com"
            || host.hasSuffix(".githubusercontent.com")
    }
}

enum WhyWaitUpdateDigest {
    static func sha256(of fileURL: URL) throws -> String {
        guard let stream = InputStream(url: fileURL) else {
            throw WhyWaitUpdateError.invalidApplication("Could not read downloaded archive.")
        }
        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw stream.streamError ?? CocoaError(.fileReadUnknown) }
            if count == 0 { break }
            hasher.update(data: Data(buffer[0..<count]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func normalizedSHA256(_ value: String?) -> String? {
        guard var candidate = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !candidate.isEmpty else { return nil }
        if candidate.hasPrefix("sha256:") {
            candidate.removeFirst("sha256:".count)
        } else if candidate.hasPrefix("sha256=") {
            candidate.removeFirst("sha256=".count)
        }
        candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate.count == 64,
              candidate.allSatisfy({ $0.isHexDigit }) else { return nil }
        return candidate
    }

    static func digestInReleaseBody(_ body: String, assetName: String) -> String? {
        for line in body.components(separatedBy: .newlines) {
            let lowercased = line.lowercased()
            guard lowercased.contains(assetName.lowercased()) || lowercased.contains("sha-256") else {
                continue
            }
            for token in line.split(whereSeparator: { !$0.isHexDigit }).map(String.init)
                where token.count == 64 {
                if let digest = normalizedSHA256(token) { return digest }
            }
        }
        return nil
    }
}

private struct GitHubReleasePayload: Decodable {
    struct Asset: Decodable {
        let name: String
        let downloadURL: URL
        let size: Int64
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
            case size
            case digest
        }
    }

    let tagName: String
    let name: String?
    let htmlURL: URL
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let publishedAt: Date?
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case body
        case draft
        case prerelease
        case publishedAt = "published_at"
        case assets
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
