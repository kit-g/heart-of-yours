import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
      if let window = NSApp.windows.first {
        window.minSize = NSSize(width: 375, height: 667) // iPhone SE, 1 gen
      }
      super.applicationDidFinishLaunching(notification)
    }
}
