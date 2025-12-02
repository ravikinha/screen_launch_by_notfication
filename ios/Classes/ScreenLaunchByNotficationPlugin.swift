import Flutter
import UIKit
import UserNotifications
import ObjectiveC

// Store original implementation
private var originalIMP: IMP?

// Extension to FlutterAppDelegate to automatically handle launch notifications
extension FlutterAppDelegate {
  @objc public func screenLaunch_application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Handle launch notification before calling original method
    if let notification = launchOptions?[.remoteNotification] as? [String: Any] {
      UserDefaults.standard.set(true, forKey: "openFromNotification")
      if let jsonData = try? JSONSerialization.data(withJSONObject: notification),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        UserDefaults.standard.set(jsonString, forKey: "notificationPayload")
      }
      UserDefaults.standard.synchronize()
    }
    
    // Call original implementation using stored IMP
    if let originalIMP = originalIMP {
      typealias OriginalFunction = @convention(c) (AnyObject, Selector, UIApplication, [UIApplication.LaunchOptionsKey: Any]?) -> Bool
      let originalFunction = unsafeBitCast(originalIMP, to: OriginalFunction.self)
      let originalSelector = #selector(FlutterAppDelegate.application(_:didFinishLaunchingWithOptions:))
      return originalFunction(self, originalSelector, application, launchOptions)
    }
    
    // Fallback
    return false
  }
}

public class ScreenLaunchByNotficationPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate, FlutterStreamHandler {
  private var channel: FlutterMethodChannel?
  private var eventSink: FlutterEventSink?
  private static var sharedInstance: ScreenLaunchByNotficationPlugin?
  private static var hasSwizzled = false
  private static var isAppInitialized = false
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "launch_channel", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "launch_channel_events", binaryMessenger: registrar.messenger())
    let instance = ScreenLaunchByNotficationPlugin()
    instance.channel = channel
    sharedInstance = instance
    registrar.addMethodCallDelegate(instance, channel: channel)
    eventChannel.setStreamHandler(instance)
    
    // Set up notification delegate
    UNUserNotificationCenter.current().delegate = instance
    
    // Swizzle AppDelegate to automatically handle launch notifications
    swizzleAppDelegate()
    
    // Mark app as initialized after a short delay to ensure didFinishLaunchingWithOptions completes
    // This prevents sending events during initial launch
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      isAppInitialized = true
    }
  }
  
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }
  
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
  
  private func sendNotificationEvent(payload: String) {
    if let sink = eventSink {
      sink([
        "isFromNotification": true,
        "payload": payload
      ])
    }
  }
  
  // Swizzle AppDelegate to automatically handle launch notifications
  private static func swizzleAppDelegate() {
    guard !hasSwizzled else { return }
    hasSwizzled = true
    
    guard let appDelegateClass = NSClassFromString("FlutterAppDelegate") as? AnyClass else {
      return
    }
    
    let originalSelector = #selector(FlutterAppDelegate.application(_:didFinishLaunchingWithOptions:))
    let swizzledSelector = #selector(FlutterAppDelegate.screenLaunch_application(_:didFinishLaunchingWithOptions:))
    
    guard let originalMethod = class_getInstanceMethod(appDelegateClass, originalSelector),
          let swizzledMethod = class_getInstanceMethod(appDelegateClass, swizzledSelector) else {
      return
    }
    
    // Store original implementation before swizzling
    originalIMP = method_getImplementation(originalMethod)
    
    // Exchange implementations
    method_exchangeImplementations(originalMethod, swizzledMethod)
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
    let finalPayload: String
    if let payload = payloadString {
      finalPayload = payload
    } else {
      let userInfo = response.notification.request.content.userInfo
      if let jsonData = try? JSONSerialization.data(withJSONObject: userInfo),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        finalPayload = jsonString
      } else {
        finalPayload = "{}"
      }
    }
    
    UserDefaults.standard.set(finalPayload, forKey: "notificationPayload")
    UserDefaults.standard.synchronize()
    
    // Send event to Flutter ONLY when app is already running (not initial launch)
    // Check both the initialization flag and application state
    let appState = UIApplication.shared.applicationState
    let isAppRunning = ScreenLaunchByNotficationPlugin.isAppInitialized || 
                       appState == .active || 
                       appState == .inactive
    
    if isAppRunning {
      sendNotificationEvent(payload: finalPayload)
    }
    
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
