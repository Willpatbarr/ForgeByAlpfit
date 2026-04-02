import FirebaseCore
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Must run before GeneratedPluginRegistrant: firebase_auth registers with FIRApp in its
    // plugin init, but firebase_core is registered *after* auth in GeneratedPluginRegistrant.m.
    // Calling configure() twice is a no-op once the default app exists (FlutterFire also guards).
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Match launch storyboard (#4D7CFF) so the gap before first Flutter frame isn’t white.
    let forgeBlue = UIColor(
      red: 77.0 / 255.0,
      green: 124.0 / 255.0,
      blue: 1.0,
      alpha: 1.0
    )
    window?.backgroundColor = forgeBlue
    if let flutterController = window?.rootViewController as? FlutterViewController {
      flutterController.view.backgroundColor = forgeBlue
    }
    DispatchQueue.main.async { [weak self] in
      self?.window?.backgroundColor = forgeBlue
      if let fc = self?.window?.rootViewController as? FlutterViewController {
        fc.view.backgroundColor = forgeBlue
      }
    }
    return result
  }
}
