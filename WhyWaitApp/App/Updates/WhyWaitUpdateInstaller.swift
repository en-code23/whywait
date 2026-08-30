import AppKit
import Foundation

struct WhyWaitPreparedInstallation: Sendable {
    let release: WhyWaitUpdateRelease
    let currentApplicationURL: URL
    let replacementApplicationURL: URL
    let backupApplicationURL: URL
    let helperScriptURL: URL
    let helperWorkingDirectoryURL: URL
    let logURL: URL

    var fallbackReleaseURL: URL { release.releasePageURL }
}

protocol WhyWaitCodeSignatureValidating {
    func validateCodeSignature(at applicationURL: URL) throws
}

struct WhyWaitSystemCodeSignatureValidator: WhyWaitCodeSignatureValidating {
    private let commandRunner: WhyWaitUpdateCommandRunning

    init(commandRunner: WhyWaitUpdateCommandRunning = WhyWaitSystemCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func validateCodeSignature(at applicationURL: URL) throws {
        let result = try commandRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/codesign"),
            arguments: ["--verify", "--deep", "--strict", "--verbose=2", applicationURL.path]
        )
        guard result.exitCode == 0 else {
            throw WhyWaitUpdateError.signatureInvalid(result.conciseOutput)
        }
    }
}

struct WhyWaitApplicationValidator {
    let configuration: WhyWaitUpdateConfiguration
    let signatureValidator: WhyWaitCodeSignatureValidating
    let fileManager: FileManager

    init(
        configuration: WhyWaitUpdateConfiguration = .standard,
        signatureValidator: WhyWaitCodeSignatureValidating = WhyWaitSystemCodeSignatureValidator(),
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.signatureValidator = signatureValidator
        self.fileManager = fileManager
    }

    func validate(
        applicationURL: URL,
        expectedVersion: WhyWaitSemanticVersion? = nil
    ) throws -> WhyWaitValidatedApplication {
        let canonicalURL = applicationURL.standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard canonicalURL.pathExtension.lowercased() == "app",
              fileManager.fileExists(atPath: canonicalURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              let bundle = Bundle(url: canonicalURL) else {
            throw WhyWaitUpdateError.invalidApplication("The application bundle is missing.")
        }

        let identifier = bundle.bundleIdentifier
        guard identifier == configuration.expectedBundleIdentifier else {
            throw WhyWaitUpdateError.bundleIdentifierMismatch(
                expected: configuration.expectedBundleIdentifier,
                actual: identifier
            )
        }
        guard let versionString = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String,
              let version = WhyWaitSemanticVersion(versionString) else {
            throw WhyWaitUpdateError.invalidApplication("The application version is missing or invalid.")
        }
        if let expectedVersion, version != expectedVersion {
            throw WhyWaitUpdateError.applicationVersionMismatch(
                expected: expectedVersion,
                actual: version
            )
        }

        guard let executableURL = bundle.executableURL else {
            throw WhyWaitUpdateError.invalidApplication("The application executable is missing.")
        }
        let canonicalExecutable = executableURL.standardizedFileURL.resolvingSymlinksInPath()
        let contentsURL = canonicalURL.appendingPathComponent("Contents", isDirectory: true)
        guard canonicalExecutable.path.hasPrefix(contentsURL.path + "/"),
              fileManager.isExecutableFile(atPath: canonicalExecutable.path) else {
            throw WhyWaitUpdateError.invalidApplication("The application executable is unsafe.")
        }

        try signatureValidator.validateCodeSignature(at: canonicalURL)
        return WhyWaitValidatedApplication(
            bundleURL: canonicalURL,
            bundleIdentifier: identifier ?? configuration.expectedBundleIdentifier,
            version: version
        )
    }
}

final class WhyWaitUpdateInstaller: @unchecked Sendable {
    private let configuration: WhyWaitUpdateConfiguration
    private let fileManager: FileManager
    private let commandRunner: WhyWaitUpdateCommandRunning
    private let applicationValidator: WhyWaitApplicationValidator

    init(
        configuration: WhyWaitUpdateConfiguration = .standard,
        fileManager: FileManager = .default,
        commandRunner: WhyWaitUpdateCommandRunning = WhyWaitSystemCommandRunner(),
        applicationValidator: WhyWaitApplicationValidator? = nil
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.commandRunner = commandRunner
        self.applicationValidator = applicationValidator ?? WhyWaitApplicationValidator(
            configuration: configuration,
            signatureValidator: WhyWaitSystemCodeSignatureValidator(commandRunner: commandRunner),
            fileManager: fileManager
        )
    }

    /// Unpacks and validates an update, then copies it beside the running app.
    /// Run this off the main thread because `ditto` and code-sign validation are synchronous.
    func prepareInstallation(
        from downloadedUpdate: WhyWaitDownloadedUpdate,
        replacing currentApplicationURL: URL = Bundle.main.bundleURL
    ) throws -> WhyWaitPreparedInstallation {
        let archiveURL = downloadedUpdate.archiveURL.standardizedFileURL
        guard archiveURL.pathExtension.lowercased() == "zip",
              fileManager.isReadableFile(atPath: archiveURL.path) else {
            throw WhyWaitUpdateError.invalidApplication("The downloaded ZIP archive is missing.")
        }

        let current = try validateInstallTarget(currentApplicationURL)
        let currentApplication = try applicationValidator.validate(applicationURL: current)
        guard downloadedUpdate.release.version > currentApplication.version else {
            throw WhyWaitUpdateError.applicationVersionMismatch(
                expected: downloadedUpdate.release.version,
                actual: currentApplication.version
            )
        }

        let helperRoot = fileManager.temporaryDirectory
            .appendingPathComponent("WhyWaitUpdates", isDirectory: true)
            .appendingPathComponent("Install-\(UUID().uuidString)", isDirectory: true)
        let extractionURL = helperRoot.appendingPathComponent("Extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)

        do {
            let result = try commandRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/ditto"),
                arguments: ["-x", "-k", "--sequesterRsrc", archiveURL.path, extractionURL.path]
            )
            guard result.exitCode == 0 else {
                throw WhyWaitUpdateError.extractionFailed(result.conciseOutput)
            }
            try validateExtractedTree(at: extractionURL)
            let extractedApplication = try findExtractedApplication(in: extractionURL)
            _ = try applicationValidator.validate(
                applicationURL: extractedApplication,
                expectedVersion: downloadedUpdate.release.version
            )

            let parent = current.deletingLastPathComponent()
            let nonce = UUID().uuidString
            let replacement = parent.appendingPathComponent(
                ".WhyWait-update-\(nonce).app",
                isDirectory: true
            )
            let backup = parent.appendingPathComponent(
                ".WhyWait-backup-\(nonce).app",
                isDirectory: true
            )
            do {
                try fileManager.copyItem(at: extractedApplication, to: replacement)
            } catch {
                throw WhyWaitUpdateError.installLocationNotWritable(parent)
            }
            do {
                _ = try applicationValidator.validate(
                    applicationURL: replacement,
                    expectedVersion: downloadedUpdate.release.version
                )
            } catch {
                try? fileManager.removeItem(at: replacement)
                throw error
            }

            let scriptURL = helperRoot.appendingPathComponent("install.zsh")
            try Self.helperScript.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o700))],
                ofItemAtPath: scriptURL.path
            )
            let logURL = try updaterLogURL()
            return WhyWaitPreparedInstallation(
                release: downloadedUpdate.release,
                currentApplicationURL: current,
                replacementApplicationURL: replacement,
                backupApplicationURL: backup,
                helperScriptURL: scriptURL,
                helperWorkingDirectoryURL: helperRoot,
                logURL: logURL
            )
        } catch {
            try? fileManager.removeItem(at: helperRoot)
            throw error
        }
    }

    /// Starts a detached helper. After this returns, the caller should terminate
    /// WhyWait normally so the helper can atomically replace and relaunch it.
    func launchInstallationHelper(
        _ installation: WhyWaitPreparedInstallation,
        waitingFor processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) throws {
        try Self.validatePreparedPaths(installation)
        guard fileManager.fileExists(atPath: installation.currentApplicationURL.path),
              fileManager.fileExists(atPath: installation.replacementApplicationURL.path),
              fileManager.isExecutableFile(atPath: installation.helperScriptURL.path) else {
            throw WhyWaitUpdateError.helperLaunchFailed("Prepared update files are missing.")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        process.arguments = [
            "/bin/zsh",
            installation.helperScriptURL.path,
            String(processIdentifier),
            installation.currentApplicationURL.path,
            installation.replacementApplicationURL.path,
            installation.backupApplicationURL.path,
            installation.helperWorkingDirectoryURL.path,
            installation.logURL.path
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw WhyWaitUpdateError.helperLaunchFailed(error.localizedDescription)
        }
    }

    func discard(_ installation: WhyWaitPreparedInstallation) {
        let replacement = installation.replacementApplicationURL.standardizedFileURL
        let parent = installation.currentApplicationURL.deletingLastPathComponent().standardizedFileURL
        if replacement.deletingLastPathComponent() == parent,
           replacement.lastPathComponent.hasPrefix(".WhyWait-update-"),
           replacement.pathExtension == "app" {
            try? fileManager.removeItem(at: replacement)
        }
        try? fileManager.removeItem(at: installation.helperWorkingDirectoryURL)
    }

    @discardableResult
    func openManualDownloadPage(for release: WhyWaitUpdateRelease? = nil) -> Bool {
        NSWorkspace.shared.open(release?.releasePageURL ?? configuration.releasesURL)
    }

    private func validateInstallTarget(_ url: URL) throws -> URL {
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        let parent = canonical.deletingLastPathComponent()
        guard canonical.lastPathComponent == "WhyWait.app",
              canonical.pathExtension == "app",
              parent.path != "/",
              parent.path != "/Applications" || canonical.path == "/Applications/WhyWait.app" else {
            throw WhyWaitUpdateError.unsafeInstallLocation(canonical)
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: canonical.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw WhyWaitUpdateError.unsafeInstallLocation(canonical)
        }
        return canonical
    }

    private func findExtractedApplication(in extractionURL: URL) throws -> URL {
        let direct = extractionURL.appendingPathComponent("WhyWait.app", isDirectory: true)
        if fileManager.fileExists(atPath: direct.path) { return direct }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: extractionURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { throw WhyWaitUpdateError.applicationMissing }

        var matches: [URL] = []
        for case let candidate as URL in enumerator {
            let relativeComponents = candidate.pathComponents.count - extractionURL.pathComponents.count
            if relativeComponents > 2 {
                enumerator.skipDescendants()
                continue
            }
            if candidate.lastPathComponent == "WhyWait.app" {
                matches.append(candidate)
                enumerator.skipDescendants()
            }
        }
        guard matches.count == 1, let application = matches.first else {
            throw WhyWaitUpdateError.applicationMissing
        }
        return application
    }

    private func validateExtractedTree(at root: URL) throws {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .fileSizeKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: []
        ) else { throw WhyWaitUpdateError.extractionFailed("Could not inspect extracted files.") }
        var itemCount = 0
        var allocatedBytes: Int64 = 0
        for case let item as URL in enumerator {
            itemCount += 1
            guard itemCount <= 12_000 else {
                throw WhyWaitUpdateError.extractionFailed("The archive contains too many files.")
            }
            let values = try item.resourceValues(forKeys: Set(keys))
            if values.isRegularFile == true {
                allocatedBytes += Int64(max(values.fileAllocatedSize ?? 0, values.fileSize ?? 0))
                guard allocatedBytes <= 800 * 1_024 * 1_024 else {
                    throw WhyWaitUpdateError.extractionFailed("The extracted update is too large.")
                }
            }
            if values.isSymbolicLink == true {
                let destination = item.resolvingSymlinksInPath().standardizedFileURL
                guard destination.path.hasPrefix(root.standardizedFileURL.path + "/") else {
                    throw WhyWaitUpdateError.extractionFailed("The archive contains an unsafe symbolic link.")
                }
            }
        }
    }

    private func updaterLogURL() throws -> URL {
        let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let logs = library
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("WhyWait", isDirectory: true)
        try fileManager.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("updater.log")
    }

    static func validatePreparedPaths(_ installation: WhyWaitPreparedInstallation) throws {
        let current = installation.currentApplicationURL.standardizedFileURL
        let parent = current.deletingLastPathComponent()
        let replacement = installation.replacementApplicationURL.standardizedFileURL
        let backup = installation.backupApplicationURL.standardizedFileURL
        guard current.lastPathComponent == "WhyWait.app",
              replacement.deletingLastPathComponent() == parent,
              backup.deletingLastPathComponent() == parent,
              replacement.lastPathComponent.hasPrefix(".WhyWait-update-"),
              backup.lastPathComponent.hasPrefix(".WhyWait-backup-"),
              replacement.pathExtension == "app",
              backup.pathExtension == "app",
              replacement != backup else {
            throw WhyWaitUpdateError.unsafeInstallLocation(current)
        }
    }

    private static let helperScript = #"""
#!/bin/zsh
set -u

pid="$1"
target="$2"
candidate="$3"
backup="$4"
workdir="$5"
log="$6"

mkdir -p "${log:h}"
exec >>"$log" 2>&1
echo "$(date -u +%FT%TZ) update helper started"

case "$target" in
  */WhyWait.app) ;;
  *) echo "unsafe target"; exit 64 ;;
esac
parent="${target:h}"
case "$candidate" in
  "$parent"/.WhyWait-update-*.app) ;;
  *) echo "unsafe candidate"; exit 65 ;;
esac
case "$backup" in
  "$parent"/.WhyWait-backup-*.app) ;;
  *) echo "unsafe backup"; exit 66 ;;
esac

attempt=0
while /bin/kill -0 "$pid" 2>/dev/null; do
  /bin/sleep 0.10
  attempt=$((attempt + 1))
  if (( attempt > 300 )); then
    echo "timed out waiting for WhyWait to quit"
    exit 67
  fi
done

if [[ ! -d "$target" || ! -d "$candidate" || -e "$backup" ]]; then
  echo "install paths changed while waiting"
  exit 68
fi

if ! /bin/mv "$target" "$backup"; then
  echo "could not back up current app"
  exit 69
fi
if ! /bin/mv "$candidate" "$target"; then
  echo "could not install candidate; restoring backup"
  /bin/mv "$backup" "$target"
  exit 70
fi

if ! /usr/bin/open -n "$target"; then
  echo "could not relaunch update; restoring backup"
  /bin/rm -rf -- "$target"
  /bin/mv "$backup" "$target"
  /usr/bin/open -n "$target" || true
  exit 71
fi

/bin/sleep 4
/bin/rm -rf -- "$backup"
/bin/rm -rf -- "$workdir"
echo "$(date -u +%FT%TZ) update installed"
"""#
}

struct WhyWaitUpdateCommandResult: Sendable {
    let exitCode: Int32
    let output: String

    var conciseOutput: String {
        let value = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "command exited with status \(exitCode)" }
        return String(value.prefix(2_000))
    }
}

protocol WhyWaitUpdateCommandRunning {
    func run(executableURL: URL, arguments: [String]) throws -> WhyWaitUpdateCommandResult
}

struct WhyWaitSystemCommandRunner: WhyWaitUpdateCommandRunning {
    func run(executableURL: URL, arguments: [String]) throws -> WhyWaitUpdateCommandResult {
        let process = Process()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return WhyWaitUpdateCommandResult(
            exitCode: process.terminationStatus,
            output: String(decoding: data, as: UTF8.self)
        )
    }
}
