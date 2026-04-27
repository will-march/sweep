import Cocoa
import FlutterMacOS

/// Owns the iMaculate NSStatusItem in the macOS menu bar.
///
/// Each menu item invokes a method on the Dart-side `imaculate.menubar`
/// channel; the Dart handler (lib/services/menu_bar_channel.dart) maps
/// those into the same calls the GUI buttons make. The menu bar stays
/// available even when the main window is hidden, giving users a
/// "always on" surface for routine operations.
final class MenuBarController: NSObject {
  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?
  private let statusItem: NSStatusItem

  init(channel: FlutterMethodChannel, window: NSWindow) {
    self.channel = channel
    self.window = window
    self.statusItem = NSStatusBar.system.statusItem(
      withLength: NSStatusItem.variableLength
    )
    super.init()
    configureButton()
    configureMenu()
  }

  // MARK: - Setup

  private func configureButton() {
    guard let button = statusItem.button else { return }
    // SF Symbols arrived in macOS 11. The project's deployment target
    // is 10.15, so we feature-gate the symbol path and fall back to a
    // glyph on older systems.
    if #available(macOS 11.0, *),
       let img = NSImage(
        systemSymbolName: "sparkles",
        accessibilityDescription: "iMaculate"
       )
    {
      button.image = img
      button.imagePosition = .imageOnly
    } else {
      button.title = "✦"
    }
    button.toolTip = "iMaculate"
  }

  private func configureMenu() {
    let menu = NSMenu()
    menu.autoenablesItems = false
    menu.addItem(
      makeItem(
        title: "Open iMaculate",
        action: #selector(openApp),
        key: "o"
      )
    )
    menu.addItem(.separator())
    menu.addItem(
      makeItem(
        title: "Quick Light Scrub",
        action: #selector(lightScrub),
        key: ""
      )
    )
    menu.addItem(
      makeItem(
        title: "Run Threat Scan",
        action: #selector(threatScan),
        key: ""
      )
    )
    menu.addItem(
      makeItem(
        title: "Update Threat Definitions",
        action: #selector(updateDefs),
        key: ""
      )
    )
    menu.addItem(
      makeItem(
        title: "Run Scheduled Job Now",
        action: #selector(scheduledJob),
        key: ""
      )
    )
    menu.addItem(.separator())
    menu.addItem(
      makeItem(
        title: "Install Command-Line Tool…",
        action: #selector(installCli),
        key: ""
      )
    )
    menu.addItem(
      makeItem(
        title: "Reveal Logs in Finder",
        action: #selector(revealLogs),
        key: ""
      )
    )
    menu.addItem(.separator())
    let quit = NSMenuItem(
      title: "Quit iMaculate",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    menu.addItem(quit)
    statusItem.menu = menu
  }

  private func makeItem(title: String, action: Selector, key: String)
    -> NSMenuItem
  {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.target = self
    return item
  }

  // MARK: - Actions

  @objc private func openApp() {
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
    channel.invokeMethod("openApp", arguments: nil)
  }

  @objc private func lightScrub() {
    channel.invokeMethod("lightScrub", arguments: nil)
  }

  @objc private func threatScan() {
    channel.invokeMethod("threatScan", arguments: nil)
  }

  @objc private func updateDefs() {
    channel.invokeMethod("updateDefs", arguments: nil)
  }

  @objc private func scheduledJob() {
    channel.invokeMethod("scheduledJob", arguments: nil)
  }

  @objc private func installCli() {
    channel.invokeMethod("installCli", arguments: nil)
  }

  @objc private func revealLogs() {
    let home =
      ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
    let logsPath =
      "\(home)/Library/Application Support/iMaculate/logs"
    NSWorkspace.shared.selectFile(
      nil,
      inFileViewerRootedAtPath: logsPath
    )
  }
}
