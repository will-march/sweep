import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
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

    super.awakeFromNib()
  }
}
