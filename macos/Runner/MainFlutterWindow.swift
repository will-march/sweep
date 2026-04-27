import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // Strong-ref the menu bar controller so its NSStatusItem stays alive
  // for the lifetime of the window. Without this the status item gets
  // collected the moment awakeFromNib returns.
  private var menuBarController: MenuBarController?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Aurora chrome: transparent titlebar so the app's custom bar reads as
    // the window header. Traffic lights still hover over the top-left.
    self.styleMask.insert(.fullSizeContentView)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.isMovableByWindowBackground = true

    RegisterGeneratedPlugins(registry: flutterViewController)

    // MethodChannel that the menu bar controller fires into when the
    // user picks an item from the menubar menu. Dart side listens via
    // services/menu_bar_channel.dart.
    let channel = FlutterMethodChannel(
      name: "sweep.menubar",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    menuBarController = MenuBarController(channel: channel, window: self)

    super.awakeFromNib()
  }
}
