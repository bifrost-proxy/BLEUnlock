import AppKit

/// Command-Line-Tools-only entry point used by scripts/build-local.sh.
///
/// The release app instantiates AppDelegate from MainMenu.nib. The local build
/// intentionally omits that nib because ibtool ships with full Xcode, so it
/// must install the delegate programmatically to exercise the real lifecycle.
@main
struct BLEUnlockLocalMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
