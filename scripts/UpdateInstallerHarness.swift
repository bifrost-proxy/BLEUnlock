import AppKit
import Darwin

func notifyUpdateAvailable() {}

@main
struct UpdateInstallerHarness {
    static func main() {
        guard CommandLine.arguments.count == 3,
              let downloadURL = URL(string: CommandLine.arguments[1]) else {
            fputs("usage: UpdateInstallerHarness <dmg-url> <version>\n", stderr)
            exit(2)
        }

        let version = CommandLine.arguments[2]
        UpdateInstaller.shared.prepareAndLaunch(version: version, downloadURL: downloadURL) { result in
            switch result {
            case .success:
                exit(0)
            case .failure(let error):
                fputs("update failed: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
        RunLoop.main.run()
    }
}
