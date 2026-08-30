#if DEBUG
import Foundation

enum WhyWaitUpdateDiagnostics {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func runAll() throws -> [String] {
        var reports: [String] = []
        try verifySemanticVersions()
        reports.append("semantic versions: precedence, prereleases, invalid values")

        try verifyReleaseParsing()
        reports.append("release parsing: exact asset, trusted URLs, published digest")

        try verifyDigest()
        reports.append("digest: deterministic SHA-256 and normalization")

        try verifyApplicationValidation()
        reports.append("application validation: bundle ID, version, executable, signature boundary")

        try verifyInstallationPathValidation()
        reports.append("installer: constrained target, candidate, backup and fallback URL")

        try verifyPreparationPipeline()
        reports.append("staging: deterministic ZIP extraction, app validation and cleanup")
        return reports
    }

    private static func verifySemanticVersions() throws {
        let ordered = [
            "1.0.0-alpha",
            "1.0.0-alpha.1",
            "1.0.0-alpha.beta",
            "1.0.0-beta",
            "1.0.0-beta.2",
            "1.0.0-beta.11",
            "1.0.0-rc.1",
            "1.0.0",
            "1.1",
            "2"
        ].compactMap(WhyWaitSemanticVersion.init)
        try require(ordered.count == 10, "A valid semantic version was rejected")
        try require(ordered == ordered.sorted(), "SemVer precedence is incorrect")
        try require(
            WhyWaitSemanticVersion("v1.2.3+build.9") == WhyWaitSemanticVersion("1.2.3+other"),
            "Build metadata incorrectly changes version precedence"
        )
        for invalid in ["", "1..2", "01.2.3", "1.2.3.4", "1.0.0-01", "v"] {
            try require(WhyWaitSemanticVersion(invalid) == nil, "Accepted invalid version \(invalid)")
        }
    }

    private static func verifyReleaseParsing() throws {
        let digest = String(repeating: "ab", count: 32)
        let json = """
        {
          "tag_name": "v2.3.0",
          "name": "WhyWait 2.3",
          "html_url": "https://github.com/en-code23/whywait/releases/tag/v2.3.0",
          "body": "WhyWait-macOS.zip SHA-256: \(digest)",
          "draft": false,
          "prerelease": false,
          "published_at": "2026-08-24T12:00:00Z",
          "assets": [
            {
              "name": "source.zip",
              "browser_download_url": "https://github.com/en-code23/whywait/releases/download/v2.3.0/source.zip",
              "size": 12,
              "digest": null
            },
            {
              "name": "WhyWait-macOS.zip",
              "browser_download_url": "https://github.com/en-code23/whywait/releases/download/v2.3.0/WhyWait-macOS.zip",
              "size": 4242,
              "digest": null
            }
          ]
        }
        """
        let release = try WhyWaitUpdateService.parseRelease(data: Data(json.utf8))
        try require(release.version == WhyWaitSemanticVersion("2.3.0"), "Release version mismatch")
        try require(release.assetName == "WhyWait-macOS.zip", "Wrong release asset selected")
        try require(release.assetSize == 4_242, "Release asset size mismatch")
        try require(release.sha256 == digest, "Release body digest was not parsed")

        let untrusted = json.replacingOccurrences(
            of: "https://github.com/en-code23/whywait/releases/download/v2.3.0/WhyWait-macOS.zip",
            with: "https://downloads.example.invalid/WhyWait-macOS.zip"
        )
        try requireThrows("Accepted an update asset outside GitHub") {
            _ = try WhyWaitUpdateService.parseRelease(data: Data(untrusted.utf8))
        }

        let noAsset = json.replacingOccurrences(of: "WhyWait-macOS.zip", with: "Other.app.zip")
        try requireThrows("Accepted a release without the canonical asset") {
            _ = try WhyWaitUpdateService.parseRelease(data: Data(noAsset.utf8))
        }

        let noDigest = json.replacingOccurrences(
            of: "WhyWait-macOS.zip SHA-256: \(digest)",
            with: "No checksum was published."
        )
        try requireThrows("Accepted an update without a published SHA-256 digest") {
            _ = try WhyWaitUpdateService.parseRelease(data: Data(noDigest.utf8))
        }
    }

    private static func verifyDigest() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhyWaitUpdaterDiagnostics-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("digest.txt")
        try Data("abc".utf8).write(to: file, options: .atomic)
        let computedDigest = try WhyWaitUpdateDigest.sha256(of: file)
        try require(
            computedDigest == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            "SHA-256 output changed"
        )
        try require(
            WhyWaitUpdateDigest.normalizedSHA256(
                "sha256:BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"
            ) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            "GitHub digest normalization failed"
        )
        try require(WhyWaitUpdateDigest.normalizedSHA256("sha256:not-a-digest") == nil,
                    "Malformed digest was accepted")
    }

    private static func verifyApplicationValidation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhyWaitAppValidation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let validApp = try makeApplication(
            in: root,
            name: "WhyWait.app",
            identifier: "com.whywait.app",
            version: "2.0.0"
        )
        let validator = WhyWaitApplicationValidator(
            signatureValidator: AcceptingSignatureValidator()
        )
        let validated = try validator.validate(
            applicationURL: validApp,
            expectedVersion: WhyWaitSemanticVersion("2.0.0")!
        )
        try require(validated.bundleIdentifier == "com.whywait.app", "Bundle ID was not retained")
        try require(validated.version == WhyWaitSemanticVersion("2"), "Bundle version was not retained")

        let impostor = try makeApplication(
            in: root,
            name: "Impostor.app",
            identifier: "invalid.example.app",
            version: "2.0.0"
        )
        try requireThrows("Accepted an application with an unexpected bundle ID") {
            _ = try validator.validate(applicationURL: impostor)
        }
        try requireThrows("Accepted an application with an unexpected version") {
            _ = try validator.validate(
                applicationURL: validApp,
                expectedVersion: WhyWaitSemanticVersion("2.1.0")!
            )
        }

        let rejectingValidator = WhyWaitApplicationValidator(
            signatureValidator: RejectingSignatureValidator()
        )
        try requireThrows("Accepted an application with an invalid signature") {
            _ = try rejectingValidator.validate(applicationURL: validApp)
        }
    }

    private static func verifyInstallationPathValidation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhyWaitPreparedPaths-\(UUID().uuidString)", isDirectory: true)
        let current = root.appendingPathComponent("WhyWait.app", isDirectory: true)
        let release = WhyWaitUpdateRelease(
            version: WhyWaitSemanticVersion("2.0")!,
            tagName: "v2.0.0",
            title: "WhyWait 2",
            releasePageURL: URL(string: "https://github.com/en-code23/whywait/releases/tag/v2.0.0")!,
            downloadURL: URL(string: "https://github.com/en-code23/whywait/releases/download/v2.0.0/WhyWait-macOS.zip")!,
            assetName: "WhyWait-macOS.zip",
            assetSize: 10,
            sha256: nil,
            publishedAt: nil
        )
        let valid = WhyWaitPreparedInstallation(
            release: release,
            currentApplicationURL: current,
            replacementApplicationURL: root.appendingPathComponent(".WhyWait-update-123.app"),
            backupApplicationURL: root.appendingPathComponent(".WhyWait-backup-123.app"),
            helperScriptURL: root.appendingPathComponent("install.zsh"),
            helperWorkingDirectoryURL: root,
            logURL: root.appendingPathComponent("updater.log")
        )
        try WhyWaitUpdateInstaller.validatePreparedPaths(valid)
        try require(valid.fallbackReleaseURL == release.releasePageURL, "Fallback URL changed")

        let unsafe = WhyWaitPreparedInstallation(
            release: release,
            currentApplicationURL: current,
            replacementApplicationURL: URL(fileURLWithPath: "/tmp/Unrelated.app"),
            backupApplicationURL: valid.backupApplicationURL,
            helperScriptURL: valid.helperScriptURL,
            helperWorkingDirectoryURL: valid.helperWorkingDirectoryURL,
            logURL: valid.logURL
        )
        try requireThrows("Accepted a replacement outside the current app directory") {
            try WhyWaitUpdateInstaller.validatePreparedPaths(unsafe)
        }
    }

    private static func verifyPreparationPipeline() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("WhyWaitStagingDiagnostics-\(UUID().uuidString)", isDirectory: true)
        let installedDirectory = root.appendingPathComponent("Installed", isDirectory: true)
        let releaseDirectory = root.appendingPathComponent("Release", isDirectory: true)
        try fileManager.createDirectory(at: installedDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: releaseDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let current = try makeApplication(
            in: installedDirectory,
            name: "WhyWait.app",
            identifier: "com.whywait.app",
            version: "1.0.0"
        )
        let candidate = try makeApplication(
            in: releaseDirectory,
            name: "WhyWait.app",
            identifier: "com.whywait.app",
            version: "2.0.0"
        )
        let archive = root.appendingPathComponent("WhyWait-macOS.zip")
        let runner = WhyWaitSystemCommandRunner()
        let zipResult = try runner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", candidate.path, archive.path]
        )
        try require(zipResult.exitCode == 0, "Could not create deterministic diagnostic ZIP")
        let archiveSize = try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let release = WhyWaitUpdateRelease(
            version: WhyWaitSemanticVersion("2.0.0")!,
            tagName: "v2.0.0",
            title: "WhyWait 2",
            releasePageURL: URL(string: "https://github.com/en-code23/whywait/releases/tag/v2.0.0")!,
            downloadURL: URL(string: "https://github.com/en-code23/whywait/releases/download/v2.0.0/WhyWait-macOS.zip")!,
            assetName: "WhyWait-macOS.zip",
            assetSize: Int64(archiveSize),
            sha256: try WhyWaitUpdateDigest.sha256(of: archive),
            publishedAt: nil
        )
        let validator = WhyWaitApplicationValidator(
            signatureValidator: AcceptingSignatureValidator()
        )
        let installer = WhyWaitUpdateInstaller(
            commandRunner: runner,
            applicationValidator: validator
        )
        let prepared = try installer.prepareInstallation(
            from: WhyWaitDownloadedUpdate(release: release, archiveURL: archive),
            replacing: current
        )
        try require(
            fileManager.fileExists(atPath: prepared.replacementApplicationURL.path),
            "Prepared replacement was not copied beside the current app"
        )
        let syntax = try runner.run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-n", prepared.helperScriptURL.path]
        )
        try require(syntax.exitCode == 0, "Generated relaunch helper has invalid shell syntax")
        installer.discard(prepared)
        try require(
            !fileManager.fileExists(atPath: prepared.replacementApplicationURL.path)
                && !fileManager.fileExists(atPath: prepared.helperWorkingDirectoryURL.path),
            "Discard did not clean the prepared update"
        )
    }

    private static func makeApplication(
        in root: URL,
        name: String,
        identifier: String,
        version: String
    ) throws -> URL {
        let application = root.appendingPathComponent(name, isDirectory: true)
        let contents = application.appendingPathComponent("Contents", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": identifier,
            "CFBundleShortVersionString": version,
            "CFBundleVersion": "1",
            "CFBundleExecutable": "WhyWait",
            "CFBundlePackageType": "APPL"
        ]
        let plist = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try plist.write(to: contents.appendingPathComponent("Info.plist"), options: .atomic)
        let executable = macOS.appendingPathComponent("WhyWait")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: executable.path
        )
        return application
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw Failure(description: message) }
    }

    private static func requireThrows(_ message: String, operation: () throws -> Void) throws {
        do {
            try operation()
            throw Failure(description: message)
        } catch is Failure {
            throw Failure(description: message)
        } catch {
            return
        }
    }
}

private struct AcceptingSignatureValidator: WhyWaitCodeSignatureValidating {
    func validateCodeSignature(at applicationURL: URL) throws {}
}

private struct RejectingSignatureValidator: WhyWaitCodeSignatureValidating {
    func validateCodeSignature(at applicationURL: URL) throws {
        throw WhyWaitUpdateError.signatureInvalid("diagnostic rejection")
    }
}
#endif
