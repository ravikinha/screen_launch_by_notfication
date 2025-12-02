import Flutter
import UIKit
import UserNotifications

public class ScreenLaunchByNotficationPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
  private var channel: FlutterMethodChannel?
  private static var sharedInstance: ScreenLaunchByNotficationPlugin?
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "launch_channel", binaryMessenger: registrar.messenger())
    let instance = ScreenLaunchByNotficationPlugin()
    instance.channel = channel
    sharedInstance = instance
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    // Set up notification delegate
    // Note: If the app already has a delegate, it should forward calls to this plugin
    UNUserNotificationCenter.current().delegate = instance
  }
  
  // Method to be called from AppDelegate when app launches with notification
  public static func handleLaunchNotification(_ notification: [String: Any]?) {
    if let notification = notification {
      UserDefaults.standard.set(true, forKey: "openFromNotification")
      // Store notification payload
      if let jsonData = try? JSONSerialization.data(withJSONObject: notification),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        UserDefaults.standard.set(jsonString, forKey: "notificationPayload")
      }
      UserDefaults.standard.synchronize()
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "isFromNotification":
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
    case "storeNotificationPayload":
      if let payload = call.arguments as? String {
        UserDefaults.standard.set(payload, forKey: "pendingNotificationPayload")
        UserDefaults.standard.synchronize()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // Handle notification tap when app is in foreground or background
  public func userNotificationCenter(
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
  public func userNotificationCenter(
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
