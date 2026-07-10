import Cocoa

private let KEY = "lastUpdateCheck"
private let INTERVAL = 24.0 * 60 * 60
private var notified = false
private var lastCheckAt = UserDefaults.standard.double(forKey: KEY)
private let releasesURL = URL(string: "https://api.github.com/repos/bifrost-proxy/BLEUnlock/releases/latest")!
private let autoCheckUpdatesKey = "autoCheckUpdates"
private let pendingUpdateVersionKey = "pendingUpdateVersion"
private let pendingUpdateDownloadURLKey = "pendingUpdateDownloadURL"
private let pendingUpdateReleaseURLKey = "pendingUpdateReleaseURL"

enum UpdateCheckResult {
    case available(version: String, downloadURL: URL?, releaseURL: URL)
    case upToDate
    case failure(String)
}

struct PendingUpdate {
    let version: String
    let downloadURL: URL?
    let releaseURL: URL
}

private struct ReleaseAsset {
    let name: String
    let downloadURL: URL
}

private struct ReleaseInfo {
    let version: String
    let releaseURL: URL
    let assets: [ReleaseAsset]
}

func checkUpdate(force: Bool = false, completion: ((UpdateCheckResult) -> Void)? = nil) {
    if !force {
        guard automaticUpdateChecksEnabled() else { return }
        guard !notified else { return }
        let now = NSDate().timeIntervalSince1970
        guard now - lastCheckAt >= INTERVAL else { return }
    }
    doCheckUpdate(force: force, completion: completion)
}

func automaticUpdateChecksEnabled() -> Bool {
    let prefs = UserDefaults.standard
    if prefs.object(forKey: autoCheckUpdatesKey) == nil {
        return true
    }
    return prefs.bool(forKey: autoCheckUpdatesKey)
}

func pendingUpdate() -> PendingUpdate? {
    let prefs = UserDefaults.standard
    guard automaticUpdateChecksEnabled(),
          let version = prefs.string(forKey: pendingUpdateVersionKey),
          let releaseURLString = prefs.string(forKey: pendingUpdateReleaseURLKey),
          let releaseURL = URL(string: releaseURLString) else {
        return nil
    }

    if let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
       normalizedVersion(currentVersion) == normalizedVersion(version) {
        clearPendingUpdate()
        return nil
    }

    let downloadURL = prefs.string(forKey: pendingUpdateDownloadURLKey).flatMap(URL.init(string:))
    return PendingUpdate(version: version, downloadURL: downloadURL, releaseURL: releaseURL)
}

func savePendingUpdate(version: String, downloadURL: URL?, releaseURL: URL) {
    let prefs = UserDefaults.standard
    prefs.set(version, forKey: pendingUpdateVersionKey)
    prefs.set(releaseURL.absoluteString, forKey: pendingUpdateReleaseURLKey)
    if let downloadURL {
        prefs.set(downloadURL.absoluteString, forKey: pendingUpdateDownloadURLKey)
    } else {
        prefs.removeObject(forKey: pendingUpdateDownloadURLKey)
    }
}

func clearPendingUpdate() {
    let prefs = UserDefaults.standard
    prefs.removeObject(forKey: pendingUpdateVersionKey)
    prefs.removeObject(forKey: pendingUpdateDownloadURLKey)
    prefs.removeObject(forKey: pendingUpdateReleaseURLKey)
}

private func doCheckUpdate(force: Bool, completion: ((UpdateCheckResult) -> Void)? = nil) {
    var request = URLRequest(url: releasesURL)
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    let task = URLSession.shared.dataTask(with: request) { data, _, error in
        if let error {
            completion?(.failure(error.localizedDescription))
            return
        }

        guard let data else {
            completion?(.failure("No response data"))
            return
        }

        guard let releaseInfo = parseReleaseInfo(from: data) else {
            completion?(.failure("Invalid GitHub release response"))
            return
        }

        lastCheckAt = NSDate().timeIntervalSince1970
        UserDefaults.standard.set(lastCheckAt, forKey: KEY)
        let result = compareVersions(releaseInfo: releaseInfo, shouldNotify: !force)
        completion?(result)
    }
    task.resume()
}

private func parseReleaseInfo(from data: Data) -> ReleaseInfo? {
    guard let json = try? JSONSerialization.jsonObject(with: data),
          let dict = json as? [String: Any],
          let version = dict["tag_name"] as? String,
          let htmlURLString = dict["html_url"] as? String,
          let releaseURL = URL(string: htmlURLString) else {
        return nil
    }

    let assets = (dict["assets"] as? [[String: Any]] ?? []).compactMap { assetDict -> ReleaseAsset? in
        guard let name = assetDict["name"] as? String,
              let downloadURLString = assetDict["browser_download_url"] as? String,
              let downloadURL = URL(string: downloadURLString) else {
            return nil
        }
        return ReleaseAsset(name: name, downloadURL: downloadURL)
    }

    return ReleaseInfo(version: version, releaseURL: releaseURL, assets: assets)
}

private func normalizedVersion(_ version: String) -> String {
    let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.lowercased().hasPrefix("v") {
        return String(trimmed.dropFirst())
    }
    return trimmed
}

private func compareVersions(releaseInfo: ReleaseInfo, shouldNotify: Bool) -> UpdateCheckResult {
    guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
        return .failure("Missing app version")
    }

    if compareSemanticVersions(version, releaseInfo.version) == .orderedAscending {
        if shouldNotify {
            notifyUpdateAvailable()
            notified = true
        }
        return .available(version: releaseInfo.version,
                          downloadURL: latestDMGDownloadURL(from: releaseInfo.assets),
                          releaseURL: releaseInfo.releaseURL)
    }

    return .upToDate
}

private func compareSemanticVersions(_ current: String, _ candidate: String) -> ComparisonResult {
    let lhs = normalizedVersion(current).split(separator: ".").map { Int($0) ?? 0 }
    let rhs = normalizedVersion(candidate).split(separator: ".").map { Int($0) ?? 0 }
    let count = max(lhs.count, rhs.count)

    for index in 0..<count {
        let left = index < lhs.count ? lhs[index] : 0
        let right = index < rhs.count ? rhs[index] : 0
        if left < right { return .orderedAscending }
        if left > right { return .orderedDescending }
    }
    return .orderedSame
}

private func latestDMGDownloadURL(from assets: [ReleaseAsset]) -> URL? {
    assets.first {
        $0.name.lowercased().hasSuffix(".dmg")
    }?.downloadURL
}

enum UpdateInstallerError: LocalizedError {
    case invalidChecksum
    case commandFailed(String)
    case appMissing
    case invalidBundleIdentifier(String)
    case invalidVersion(expected: String, actual: String)
    case helperFailed

    var errorDescription: String? {
        switch self {
        case .invalidChecksum:
            return "The update checksum is missing or does not match."
        case .commandFailed(let message):
            return message
        case .appMissing:
            return "BLEUnlock.app is missing from the update image."
        case .invalidBundleIdentifier(let identifier):
            return "The update has an unexpected bundle identifier: \(identifier)"
        case .invalidVersion(let expected, let actual):
            return "Expected update \(expected), but the downloaded app is \(actual)."
        case .helperFailed:
            return "The update helper could not start."
        }
    }
}

final class UpdateInstaller {
    static let shared = UpdateInstaller()

    private init() {}

    func prepareAndLaunch(version: String,
                          downloadURL: URL,
                          completion: @escaping (Result<Void, Error>) -> Void) {
        let task = URLSession.shared.downloadTask(with: downloadURL) { temporaryURL, _, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let temporaryURL else {
                DispatchQueue.main.async { completion(.failure(UpdateInstallerError.appMissing)) }
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.prepareDownloadedUpdate(temporaryURL: temporaryURL,
                                                     downloadURL: downloadURL,
                                                     version: version,
                                                     completion: completion)
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
        }
        task.resume()
    }

    private func prepareDownloadedUpdate(temporaryURL: URL,
                                         downloadURL: URL,
                                         version: String,
                                         completion: @escaping (Result<Void, Error>) -> Void) throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("BLEUnlock-update-\(UUID().uuidString)", isDirectory: true)
        let dmgURL = temporaryRoot.appendingPathComponent("BLEUnlock-update.dmg")
        let mountURL = temporaryRoot.appendingPathComponent("mounted", isDirectory: true)
        let helperURL = temporaryRoot.appendingPathComponent("install-update.sh")
        let readyURL = temporaryRoot.appendingPathComponent("helper-ready")

        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: mountURL, withIntermediateDirectories: true)
        try fileManager.moveItem(at: temporaryURL, to: dmgURL)

        do {
            let checksumURL = URL(string: downloadURL.absoluteString + ".sha256")!
            let checksumData = try Data(contentsOf: checksumURL)
            guard let checksumText = String(data: checksumData, encoding: .utf8),
                  let expectedChecksum = checksumText.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).first,
                  expectedChecksum.count == 64 else {
                throw UpdateInstallerError.invalidChecksum
            }

            let checksumOutput = try runCommand("/usr/bin/shasum", ["-a", "256", dmgURL.path])
            guard checksumOutput.lowercased().hasPrefix(expectedChecksum.lowercased()) else {
                throw UpdateInstallerError.invalidChecksum
            }

            _ = try runCommand("/usr/bin/hdiutil", [
                "attach", "-nobrowse", "-readonly", "-mountpoint", mountURL.path, dmgURL.path
            ])

            let sourceAppURL = mountURL.appendingPathComponent("BLEUnlock.app", isDirectory: true)
            guard fileManager.fileExists(atPath: sourceAppURL.path),
                  let sourceBundle = Bundle(url: sourceAppURL) else {
                throw UpdateInstallerError.appMissing
            }

            _ = try runCommand("/usr/bin/codesign", [
                "--verify", "--deep", "--strict", "--verbose=2", sourceAppURL.path
            ])

            let bundleIdentifier = sourceBundle.bundleIdentifier ?? ""
            guard bundleIdentifier == "com.bifrost-proxy.BLEUnlock" else {
                throw UpdateInstallerError.invalidBundleIdentifier(bundleIdentifier)
            }

            let actualVersion = sourceBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            guard normalizedVersion(actualVersion) == normalizedVersion(version) else {
                throw UpdateInstallerError.invalidVersion(expected: version, actual: actualVersion)
            }

            let destinationURL = Bundle.main.bundleURL.standardizedFileURL
            let helper = makeHelperScript(sourceAppURL: sourceAppURL,
                                          destinationURL: destinationURL,
                                          mountURL: mountURL,
                                          temporaryRoot: temporaryRoot,
                                          readyURL: readyURL)
            try helper.write(to: helperURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helperURL.path)

            try launchHelper(helperURL: helperURL,
                             readyURL: readyURL,
                             destinationURL: destinationURL,
                             completion: completion)
        } catch {
            _ = try? runCommand("/usr/bin/hdiutil", ["detach", mountURL.path, "-quiet"])
            try? fileManager.removeItem(at: temporaryRoot)
            throw error
        }
    }

    private func makeHelperScript(sourceAppURL: URL,
                                  destinationURL: URL,
                                  mountURL: URL,
                                  temporaryRoot: URL,
                                  readyURL: URL) -> String {
        let destination = destinationURL.path
        let newApp = destination + ".update-new"
        let backupApp = destination + ".update-backup"
        return """
        #!/bin/bash
        set -euo pipefail
        SOURCE=\(shellQuote(sourceAppURL.path))
        DESTINATION=\(shellQuote(destination))
        NEW_APP=\(shellQuote(newApp))
        BACKUP_APP=\(shellQuote(backupApp))
        MOUNT=\(shellQuote(mountURL.path))
        TEMP_ROOT=\(shellQuote(temporaryRoot.path))
        READY=\(shellQuote(readyURL.path))
        PARENT_PID=\(ProcessInfo.processInfo.processIdentifier)

        cleanup() {
          /usr/bin/hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || true
          /bin/rm -rf "$TEMP_ROOT"
        }
        trap cleanup EXIT

        /usr/bin/touch "$READY"
        while /bin/kill -0 "$PARENT_PID" >/dev/null 2>&1; do /bin/sleep 0.2; done

        /bin/rm -rf "$NEW_APP" "$BACKUP_APP"
        /usr/bin/ditto "$SOURCE" "$NEW_APP"
        /usr/bin/codesign --verify --deep --strict --verbose=2 "$NEW_APP"

        if [[ -e "$DESTINATION" || -L "$DESTINATION" ]]; then
          /bin/mv "$DESTINATION" "$BACKUP_APP"
        fi

        if ! /bin/mv "$NEW_APP" "$DESTINATION"; then
          [[ ! -e "$DESTINATION" && -e "$BACKUP_APP" ]] && /bin/mv "$BACKUP_APP" "$DESTINATION"
          exit 1
        fi

        if ! /usr/bin/codesign --verify --deep --strict --verbose=2 "$DESTINATION"; then
          /bin/rm -rf "$DESTINATION"
          [[ -e "$BACKUP_APP" || -L "$BACKUP_APP" ]] && /bin/mv "$BACKUP_APP" "$DESTINATION"
          exit 1
        fi

        /bin/rm -rf "$BACKUP_APP"
        /usr/bin/xattr -dr com.apple.quarantine "$DESTINATION" >/dev/null 2>&1 || true
        /usr/bin/open -n "$DESTINATION"
        """
    }

    private func launchHelper(helperURL: URL,
                              readyURL: URL,
                              destinationURL: URL,
                              completion: @escaping (Result<Void, Error>) -> Void) throws {
        let fileManager = FileManager.default
        let parentWritable = fileManager.isWritableFile(atPath: destinationURL.deletingLastPathComponent().path)
        let process = Process()

        if parentWritable {
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [helperURL.path]
        } else {
            let command = "/bin/bash \(shellQuote(helperURL.path))"
            let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
        }

        try process.run()

        DispatchQueue.global(qos: .userInitiated).async {
            let deadline = Date().addingTimeInterval(120)
            while Date() < deadline {
                if fileManager.fileExists(atPath: readyURL.path) {
                    DispatchQueue.main.async { completion(.success(())) }
                    return
                }
                if !process.isRunning {
                    DispatchQueue.main.async { completion(.failure(UpdateInstallerError.helperFailed)) }
                    return
                }
                Thread.sleep(forTimeInterval: 0.2)
            }
            process.terminate()
            DispatchQueue.main.async { completion(.failure(UpdateInstallerError.helperFailed)) }
        }
    }
}

private func runCommand(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()

    let data = output.fileHandleForReading.readDataToEndOfFile()
    let message = String(data: data, encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else {
        throw UpdateInstallerError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return message
}

private func shellQuote(_ value: String) -> String {
    return "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
}
