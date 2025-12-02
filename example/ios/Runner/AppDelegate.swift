import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Request notification permissions (needed for example app to show notifications)
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted {
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      }
    }
    
    // Handle launch notification (when app is terminated)
    // The plugin's delegate will handle foreground/background notifications automatically
    if let notification = launchOptions?[.remoteNotification] as? [String: Any] {
      // Call the plugin's static method to handle launch notification
      // Note: The plugin must be registered first (which happens in GeneratedPluginRegistrant above)
      ScreenLaunchByNotficationPlugin.handleLaunchNotification(notification)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
