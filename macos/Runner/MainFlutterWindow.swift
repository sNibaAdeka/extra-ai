import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Window 1 is the real, normal app window (titled, resizable). The
    // transparent/borderless overlay is Window 2 — a separate sub-window
    // created on demand via desktop_multi_window, configured on the Dart side.

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Ensure every sub-window (the overlay) also gets all plugins registered
    // in its own engine, so Hive/path_provider/etc. work there too.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    super.awakeFromNib()
  }
}
