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
    
    // Request notification permissions
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted {
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      }
    }
    
    // Set up notification delegate
    UNUserNotificationCenter.current().delegate = self
    
    // Check if app was launched from notification (when terminated)
    if let notification = launchOptions?[.remoteNotification] as? [String: Any] {
      UserDefaults.standard.set(true, forKey: "openFromNotification")
      // Store notification payload
      if let jsonData = try? JSONSerialization.data(withJSONObject: notification),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        UserDefaults.standard.set(jsonString, forKey: "notificationPayload")
      }
      UserDefaults.standard.synchronize()
    }
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // Set up MethodChannel after Flutter engine is initialized
    // Use a small delay to ensure window and rootViewController are ready
    DispatchQueue.main.async {
      if let controller = self.window?.rootViewController as? FlutterViewController {
        let channel = FlutterMethodChannel(name: "launch_channel",
                                           binaryMessenger: controller.binaryMessenger)
        
        channel.setMethodCallHandler { call, result in
          if call.method == "isFromNotification" {
            let flag = UserDefaults.standard.bool(forKey: "openFromNotification")
            let payload = UserDefaults.standard.string(forKey: "notificationPayload") ?? "{}"
            
            let response: [String: Any] = [
              "isFromNotification": flag,
              "payload": payload
            ]
            
            result(response)
            
            // clear after reading
            UserDefaults.standard.set(false, forKey: "openFromNotification")
            UserDefaults.standard.removeObject(forKey: "notificationPayload")
            UserDefaults.standard.synchronize()
          } else if call.method == "storeNotificationPayload" {
            if let payload = call.arguments as? String {
              UserDefaults.standard.set(payload, forKey: "pendingNotificationPayload")
              UserDefaults.standard.synchronize()
              result(true)
            } else {
              result(FlutterMethodNotImplemented)
            }
          } else {
            result(FlutterMethodNotImplemented)
          }
        }
      }
    }
    
    return result
  }
  
  // Handle notification tap when app is in foreground or background
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    UserDefaults.standard.set(true, forKey: "openFromNotification")
    
    // Extract notification payload from flutter_local_notifications
    // The payload is stored in userInfo["payload"] as a string
    var payloadString: String?
    
    if let payload = response.notification.request.content.userInfo["payload"] as? String {
      payloadString = payload
    } else {
      // If not in payload field, try to get stored payload
      payloadString = UserDefaults.standard.string(forKey: "pendingNotificationPayload")
      UserDefaults.standard.removeObject(forKey: "pendingNotificationPayload")
    }
    
    // If we have a payload string, use it; otherwise serialize userInfo
    if let payload = payloadString {
      UserDefaults.standard.set(payload, forKey: "notificationPayload")
    } else {
      let userInfo = response.notification.request.content.userInfo
      if let jsonData = try? JSONSerialization.data(withJSONObject: userInfo),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        UserDefaults.standard.set(jsonString, forKey: "notificationPayload")
      }
    }
    
    UserDefaults.standard.synchronize()
    
    completionHandler()
  }
  
  // Handle notification when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // App is in foreground, you can still set the flag if needed
    UserDefaults.standard.set(true, forKey: "openFromNotification")
    
    // Extract notification payload from flutter_local_notifications
    if let payload = notification.request.content.userInfo["payload"] as? String {
      UserDefaults.standard.set(payload, forKey: "notificationPayload")
    } else {
      let userInfo = notification.request.content.userInfo
      if let jsonData = try? JSONSerialization.data(withJSONObject: userInfo),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        UserDefaults.standard.set(jsonString, forKey: "notificationPayload")
      }
    }
    
    UserDefaults.standard.synchronize()
    
    // Use .alert for iOS 13 compatibility, .banner for iOS 14+
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}
