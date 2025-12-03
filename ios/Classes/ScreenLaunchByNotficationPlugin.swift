import Flutter
import UIKit
import UserNotifications
import ObjectiveC

// Store original implementations
private var originalIMP: IMP?
private var originalOpenIMP: IMP?
private var originalContinueIMP: IMP?

// Extension to FlutterAppDelegate to automatically handle launch notifications and deep links
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
    
    // Handle deep link from launch options (if app was opened via URL)
    if let url = launchOptions?[.url] as? URL {
      ScreenLaunchByNotficationPlugin.sharedInstance?.handleDeepLink(url)
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
  private var deepLinkChannel: FlutterMethodChannel?
  private var deepLinkEventChannel: FlutterEventChannel?
  var deepLinkEventSink: FlutterEventSink? // Changed to internal so DeepLinkStreamHandler can access it
  private var initialDeepLink: String?
  public static var sharedInstance: ScreenLaunchByNotficationPlugin?
  private static var hasSwizzled = false
  private static var hasSwizzledDeepLink = false
  private static var isAppInitialized = false
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "launch_channel", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "launch_channel_events", binaryMessenger: registrar.messenger())
    
    // Deep link channels
    let deepLinkChannel = FlutterMethodChannel(name: "screen_launch_by_notfication/deep_link", binaryMessenger: registrar.messenger())
    let deepLinkEventChannel = FlutterEventChannel(name: "screen_launch_by_notfication/deep_link_events", binaryMessenger: registrar.messenger())
    
    let instance = ScreenLaunchByNotficationPlugin()
    instance.channel = channel
    instance.deepLinkChannel = deepLinkChannel
    sharedInstance = instance
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addMethodCallDelegate(instance, channel: deepLinkChannel)
    eventChannel.setStreamHandler(instance)
    deepLinkEventChannel.setStreamHandler(DeepLinkStreamHandler(instance: instance))
    
    // Set up notification delegate
    UNUserNotificationCenter.current().delegate = instance
    
    // Swizzle AppDelegate to automatically handle launch notifications and deep links
    swizzleAppDelegate()
    swizzleDeepLinkHandlers()
    
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
    case "getInitialLink":
      let link = initialDeepLink
      result(link)
      initialDeepLink = nil // Clear after reading
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // Handle deep link
  public func handleDeepLink(_ url: URL) {
    let urlString = url.absoluteString
    
    if ScreenLaunchByNotficationPlugin.isAppInitialized {
      // App is already running, send event
      if let sink = deepLinkEventSink {
        sink(urlString)
      }
    } else {
      // App is launching, store for initial read
      initialDeepLink = urlString
    }
  }
  
  // Handle notification tap when app is in foreground or background
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
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
    
    // Check if app is already running (not initial launch)
    let appState = UIApplication.shared.applicationState
    let isAppRunning = ScreenLaunchByNotficationPlugin.isAppInitialized || 
                       appState == .active || 
                       appState == .inactive
    
    // CRITICAL FIX: Only store in persistent storage for initial launch
    // When app is already running, just send event without storing
    // This prevents stale notification state from persisting if app is closed
    if isAppRunning {
      // App is running - send event immediately without storing persistently
      sendNotificationEvent(payload: finalPayload)
    } else {
      // Initial launch - store in persistent storage for isFromNotification() to read
      UserDefaults.standard.set(true, forKey: "openFromNotification")
      UserDefaults.standard.set(finalPayload, forKey: "notificationPayload")
      UserDefaults.standard.synchronize()
    }
    
    completionHandler()
  }
  
  // Handle notification when app is in foreground
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // App is in foreground - notification is received but not tapped yet
    // Don't store state here as user hasn't tapped the notification
    // State will only be stored when user taps (in didReceive method)
    
    // Use .alert for iOS 13 compatibility, .banner for iOS 14+
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  // Swizzle AppDelegate methods to handle deep links
  private static func swizzleDeepLinkHandlers() {
    guard !hasSwizzledDeepLink else { return }
    hasSwizzledDeepLink = true
    
    guard let appDelegateClass = NSClassFromString("FlutterAppDelegate") as? AnyClass else {
      return
    }
    
    // Swizzle application(_:open:options:)
    let originalOpenSelector = #selector(UIApplicationDelegate.application(_:open:options:))
    let swizzledOpenSelector = #selector(FlutterAppDelegate.screenLaunch_application(_:open:options:))
    
    if let originalOpenMethod = class_getInstanceMethod(appDelegateClass, originalOpenSelector),
       let swizzledOpenMethod = class_getInstanceMethod(appDelegateClass, swizzledOpenSelector) {
      originalOpenIMP = method_getImplementation(originalOpenMethod)
      method_exchangeImplementations(originalOpenMethod, swizzledOpenMethod)
    }
    
    // Swizzle application(_:continue:restorationHandler:)
    let originalContinueSelector = #selector(UIApplicationDelegate.application(_:continue:restorationHandler:))
    let swizzledContinueSelector = #selector(FlutterAppDelegate.screenLaunch_application(_:continue:restorationHandler:))
    
    if let originalContinueMethod = class_getInstanceMethod(appDelegateClass, originalContinueSelector),
       let swizzledContinueMethod = class_getInstanceMethod(appDelegateClass, swizzledContinueSelector) {
      originalContinueIMP = method_getImplementation(originalContinueMethod)
      method_exchangeImplementations(originalContinueMethod, swizzledContinueMethod)
    }
  }
}

// Deep link stream handler
class DeepLinkStreamHandler: NSObject, FlutterStreamHandler {
  weak var instance: ScreenLaunchByNotficationPlugin?
  
  init(instance: ScreenLaunchByNotficationPlugin) {
    self.instance = instance
  }
  
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    instance?.deepLinkEventSink = events
    return nil
  }
  
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    instance?.deepLinkEventSink = nil
    return nil
  }
}

// Extension to FlutterAppDelegate for deep link handling
extension FlutterAppDelegate {
  @objc public func screenLaunch_application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // Handle deep link
    ScreenLaunchByNotficationPlugin.sharedInstance?.handleDeepLink(url)
    
    // Call original implementation using stored IMP
    if let originalIMP = originalOpenIMP {
      typealias OriginalFunction = @convention(c) (AnyObject, Selector, UIApplication, URL, [UIApplication.OpenURLOptionsKey : Any]) -> Bool
      let originalFunction = unsafeBitCast(originalIMP, to: OriginalFunction.self)
      let originalSelector = #selector(UIApplicationDelegate.application(_:open:options:))
      return originalFunction(self, originalSelector, app, url, options)
    }
    
    return false
  }
  
  @objc public func screenLaunch_application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    // Handle Universal Links
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      ScreenLaunchByNotficationPlugin.sharedInstance?.handleDeepLink(url)
      return true
    }
    
    // Call original implementation using stored IMP
    if let originalIMP = originalContinueIMP {
      typealias OriginalFunction = @convention(c) (AnyObject, Selector, UIApplication, NSUserActivity, @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool
      let originalFunction = unsafeBitCast(originalIMP, to: OriginalFunction.self)
      let originalSelector = #selector(UIApplicationDelegate.application(_:continue:restorationHandler:))
      return originalFunction(self, originalSelector, application, userActivity, restorationHandler)
    }
    
    return false
  }
}
