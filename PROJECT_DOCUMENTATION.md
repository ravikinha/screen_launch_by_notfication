# screen_launch_by_notfication - Complete Project Documentation

## 📦 Package Information

- **Package Name:** `screen_launch_by_notfication`
- **Version:** 1.1.0
- **Pub.dev:** [https://pub.dev/packages/screen_launch_by_notfication](https://pub.dev/packages/screen_launch_by_notfication)
- **GitHub:** [https://github.com/ravikinha/screen_launch_by_notfication](https://github.com/ravikinha/screen_launch_by_notfication)
- **Documentation:** [https://swiftflutter.com/dynamicnotification](https://swiftflutter.com/dynamicnotification)
- **License:** MIT

---

## 🎯 Project Overview

`screen_launch_by_notfication` is a Flutter plugin that solves a critical limitation: **Flutter cannot detect if an app was launched by tapping a notification**. This plugin bridges that gap by leveraging native Android and iOS capabilities to detect notification launches and retrieve notification payloads, enabling you to:

- ✅ Skip splash screens when opened from notifications
- ✅ Route directly to notification-specific screens
- ✅ Retrieve notification payload data
- ✅ Work seamlessly with `flutter_local_notifications`
- ✅ Handle all app states (killed, background, foreground)

### The Problem

Flutter by default cannot detect whether the app was launched by tapping a notification. However, Android & iOS natively can detect this even when the app is:
- ❌ Killed (terminated)
- ❌ In background
- ❌ Not running at all

### The Solution

This plugin uses a native-first approach:

1. **Native code captures** the notification launch event
2. **Native code saves** a flag and payload in SharedPreferences/UserDefaults
3. **Flutter reads** the flag via MethodChannel before `runApp()`
4. **Flutter decides** the initial screen → splash / home / notification screen

---

## ✨ Features

### Core Features

- **🔔 Notification Launch Detection** - Know when your app was opened from a notification
- **📦 Payload Retrieval** - Get all notification data including custom payload
- **🚀 Splash Screen Bypass** - Route directly to notification screens when opened from notification
- **📱 Cross-Platform** - Works on both Android and iOS
- **🔄 All App States** - Detects notification taps when app is killed, in background, or foreground
- **🔌 Plugin Integration** - Works seamlessly with `flutter_local_notifications`

### Version 1.1.0 Features

- **🎨 SwiftFlutterMaterial Widget** - Automatic notification-based routing widget
- **🔙 Smart Back Navigation** - Navigates to home instead of exiting app
- **📊 Payload Access** - Routes can access notification payload via `routesWithPayload`
- **🛡️ Error Handling** - Robust error handling with fallback mechanisms
- **📱 iOS Compatibility** - iOS 13+ support with version checks

---

## 📥 Installation

### Step 1: Add Dependency

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  screen_launch_by_notfication: ^1.1.0
  flutter_local_notifications: ^19.5.0  # Recommended for sending notifications
```

### Step 2: Install

```bash
flutter pub get
```

### Step 3: Platform Setup

#### Android Setup

1. **Enable core library desugaring** in `android/app/build.gradle.kts`:

```kotlin
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

2. **Update MainActivity.kt** - See [Android Implementation](#android-implementation) section below.

#### iOS Setup

1. **Update AppDelegate.swift** - See [iOS Implementation](#ios-implementation) section below.
2. **Request Permissions** - The plugin handles notification permissions automatically.

---

## 🚀 Quick Start

### Method 1: Using SwiftFlutterMaterial Widget (Recommended)

The easiest way to use this plugin:

```dart
import 'package:flutter/material.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SwiftFlutterMaterial(
      initialRoute: '/splash',
      homeRoute: '/home',
      routes: {
        '/splash': (_) => SplashScreen(),
        '/notification': (_) => NotificationScreen(),
        '/home': (_) => HomeScreen(),
      },
      onNotificationLaunch: ({required isFromNotification, required payload}) {
        if (isFromNotification) {
          return '/notification'; // Route to notification screen
        }
        return null; // Use initialRoute
      },
    );
  }
}
```

### Method 2: Manual Implementation

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final screenLaunchByNotfication = ScreenLaunchByNotfication();
  final result = await screenLaunchByNotfication.isFromNotification();
  
  final bool openFromNotification = result['isFromNotification'] ?? false;
  final String payload = result['payload'] ?? '{}';

  String initialRoute = openFromNotification
      ? "/notificationScreen"
      : "/normalSplash";

  runApp(MyApp(initialRoute: initialRoute, notificationPayload: payload));
}
```

---

## 📚 Complete Setup Guide

### Android Implementation

Update your `MainActivity.kt`:

```kotlin
package com.example.your_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "launch_channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkNotificationIntent(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkNotificationIntent(intent)
    }

    private fun checkNotificationIntent(intent: android.content.Intent) {
        val prefs = getSharedPreferences("launchStore", MODE_PRIVATE)

        // Check if app opened by notification tap
        val isFromFlutterNotification = intent.action == "com.dexterous.flutterlocalnotifications.NOTIFICATION_TAPPED" ||
                intent.hasExtra("notification_launch_app")
        val isFromCustomNotification = intent.extras?.getBoolean("fromNotification") == true
        val hasPayload = intent.extras?.containsKey("payload") == true

        if (isFromFlutterNotification || isFromCustomNotification || hasPayload) {
            prefs.edit().putBoolean("openFromNotification", true).apply()

            // Extract notification payload
            val payload = JSONObject()
            
            val flutterPayload = intent.extras?.getString("payload")
            if (!flutterPayload.isNullOrEmpty()) {
                try {
                    val payloadObj = JSONObject(flutterPayload)
                    payloadObj.keys().forEach { key ->
                        payload.put(key, payloadObj.get(key))
                    }
                } catch (e: Exception) {
                    payload.put("payload", flutterPayload)
                }
            }
            
            val storedPayload = prefs.getString("pendingNotificationPayload", null)
            if (storedPayload != null) {
                try {
                    val storedObj = JSONObject(storedPayload)
                    storedObj.keys().forEach { key ->
                        if (!payload.has(key)) {
                            payload.put(key, storedObj.get(key))
                        }
                    }
                    prefs.edit().remove("pendingNotificationPayload").apply()
                } catch (e: Exception) {
                    // Ignore
                }
            }
            
            intent.extras?.keySet()?.forEach { key ->
                if (key != "payload") {
                    when (val value = intent.extras?.get(key)) {
                        is String -> payload.put(key, value)
                        is Int -> payload.put(key, value)
                        is Boolean -> payload.put(key, value)
                        is Double -> payload.put(key, value)
                        else -> payload.put(key, value.toString())
                    }
                }
            }
            
            if (payload.length() > 0) {
                prefs.edit().putString("notificationPayload", payload.toString()).apply()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isFromNotification" -> {
                        val prefs = getSharedPreferences("launchStore", MODE_PRIVATE)
                        val isFromNotification = prefs.getBoolean("openFromNotification", false)
                        val payload = prefs.getString("notificationPayload", null)
                        
                        val response = mapOf(
                            "isFromNotification" to isFromNotification,
                            "payload" to (payload ?: "{}")
                        )
                        
                        result.success(response)

                        prefs.edit()
                            .putBoolean("openFromNotification", false)
                            .putString("notificationPayload", null)
                            .apply()
                    }
                    "storeNotificationPayload" -> {
                        try {
                            val payload = call.arguments as? String ?: "{}"
                            val prefs = getSharedPreferences("launchStore", MODE_PRIVATE)
                            prefs.edit().putString("pendingNotificationPayload", payload).apply()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to store payload: ${e.message}", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

### iOS Implementation

Update your `AppDelegate.swift`:

```swift
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
      if let jsonData = try? JSONSerialization.data(withJSONObject: notification),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        UserDefaults.standard.set(jsonString, forKey: "notificationPayload")
      }
      UserDefaults.standard.synchronize()
    }
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // Set up MethodChannel after Flutter engine is initialized
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
    
    var payloadString: String?
    
    if let payload = response.notification.request.content.userInfo["payload"] as? String {
      payloadString = payload
    } else {
      payloadString = UserDefaults.standard.string(forKey: "pendingNotificationPayload")
      UserDefaults.standard.removeObject(forKey: "pendingNotificationPayload")
    }
    
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
    UserDefaults.standard.set(true, forKey: "openFromNotification")
    
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
```

---

## 📖 API Reference

### ScreenLaunchByNotfication Class

#### `isFromNotification()`

Checks if the app was launched from a notification tap.

**Returns:** `Future<Map<String, dynamic>>`
- `isFromNotification` (bool): Whether the app was opened from a notification
- `payload` (String): The notification payload as a JSON string

**Example:**
```dart
final result = await screenLaunchByNotfication.isFromNotification();
if (result['isFromNotification'] == true) {
  final payload = jsonDecode(result['payload']);
  print('Opened from notification with payload: $payload');
}
```

#### `storeNotificationPayload(String payload)`

Stores notification payload in native storage for later retrieval.

**Parameters:**
- `payload` (String): JSON string containing the notification payload

**Returns:** `Future<bool>` - `true` if successful

**Example:**
```dart
final payload = jsonEncode({'title': 'Test', 'body': 'Message'});
await screenLaunchByNotfication.storeNotificationPayload(payload);
```

### SwiftFlutterMaterial Widget

A widget that wraps MaterialApp and automatically handles notification-based routing.

#### Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `initialRoute` | `String` | Yes | The initial route when app is launched normally |
| `homeRoute` | `String?` | No | Route to navigate to when back is pressed from notification (defaults to `initialRoute`) |
| `routes` | `Map<String, WidgetBuilder>?` | Yes* | Routes configuration |
| `routesWithPayload` | `Map<String, Widget Function(BuildContext, Map<String, dynamic>)>?` | Yes* | Routes with payload access |
| `onNotificationLaunch` | `NotificationRouteCallback?` | No | Callback to determine route based on notification |
| `onBackFromNotification` | `VoidCallback?` | No | Callback when back is pressed from notification screen |
| `title` | `String?` | No | App title |
| `theme` | `ThemeData?` | No | App theme |
| `darkTheme` | `ThemeData?` | No | Dark theme |
| `themeMode` | `ThemeMode?` | No | Theme mode |
| `debugShowCheckedModeBanner` | `bool?` | No | Show debug banner |
| `builder` | `Widget Function(BuildContext, Widget?)?` | No | Additional MaterialApp builder |

*Either `routes` or `routesWithPayload` must be provided.

#### Example Usage

```dart
SwiftFlutterMaterial(
  initialRoute: '/splash',
  homeRoute: '/home',
  routesWithPayload: {
    '/splash': (context, payload) => SplashScreen(),
    '/notification': (context, payload) => NotificationScreen(payload: payload),
    '/home': (context, payload) => HomeScreen(),
  },
  onNotificationLaunch: ({required isFromNotification, required payload}) {
    if (isFromNotification) {
      return '/notification';
    }
    return null;
  },
)
```

---

## 💡 Usage Examples

### Example 1: Basic Notification Detection

```dart
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final plugin = ScreenLaunchByNotfication();
  final result = await plugin.isFromNotification();
  
  if (result['isFromNotification'] == true) {
    print('App opened from notification!');
    print('Payload: ${result['payload']}');
  }
  
  runApp(MyApp());
}
```

### Example 2: With flutter_local_notifications

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';

final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
final ScreenLaunchByNotfication launchPlugin = ScreenLaunchByNotfication();

Future<void> sendNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'channel_id',
    'Channel Name',
    channelDescription: 'Channel Description',
    importance: Importance.high,
    priority: Priority.high,
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  final payload = jsonEncode({
    'title': 'Test Notification',
    'body': 'This is a test',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  });

  // Store payload before sending
  await launchPlugin.storeNotificationPayload(payload);

  await notifications.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    'Test Notification',
    'Tap to open app',
    details,
    payload: payload,
  );
}
```

### Example 3: Complete App with SwiftFlutterMaterial

```dart
import 'package:flutter/material.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SwiftFlutterMaterial(
      title: 'My App',
      initialRoute: '/splash',
      homeRoute: '/home',
      routesWithPayload: {
        '/splash': (context, payload) => const SplashScreen(),
        '/notification': (context, payload) => NotificationScreen(payload: payload),
        '/home': (context, payload) => const HomeScreen(),
      },
      onNotificationLaunch: ({required isFromNotification, required payload}) {
        if (isFromNotification) {
          // Custom logic based on payload
          if (payload['type'] == 'message') {
            return '/chat';
          } else if (payload['type'] == 'order') {
            return '/orders';
          }
          return '/notification';
        }
        return null; // Use initialRoute
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
    );
  }
}
```

---

## 🔧 Configuration

### Android Configuration

1. **Minimum SDK:** Android 5.0 (API 21)
2. **Target SDK:** Latest
3. **Core Library Desugaring:** Required (see installation)

### iOS Configuration

1. **Minimum iOS:** iOS 10.0
2. **Permissions:** Notification permissions are requested automatically
3. **Compatibility:** iOS 13+ uses `.banner`, iOS 13 uses `.alert`

---

## 🎯 How It Works

### Flow Diagram

```
User Taps Notification
        ↓
Native Code Captures Event (Android/iOS)
        ↓
Save Flag: openFromNotification = true
Save Payload: notificationPayload = {...}
        ↓
Flutter Starts
        ↓
Read Flag via MethodChannel (before runApp())
        ↓
Check: isFromNotification?
        ↓
    Yes → Route to Notification Screen (Skip Splash)
    No  → Route to Normal Splash Screen
```

### Technical Details

1. **Native Detection:**
   - Android: Checks Intent extras and action
   - iOS: Checks UNNotificationResponse and launchOptions

2. **Storage:**
   - Android: SharedPreferences
   - iOS: UserDefaults

3. **Communication:**
   - MethodChannel: `launch_channel`
   - Methods: `isFromNotification`, `storeNotificationPayload`

4. **Payload Format:**
   - Stored as JSON string
   - Parsed in Flutter using `jsonDecode()`

---

## 🐛 Troubleshooting

### Issue: App exits when pressing back from notification screen

**Solution:** Use `SwiftFlutterMaterial` widget with `homeRoute` parameter, or handle back navigation manually:

```dart
SwiftFlutterMaterial(
  homeRoute: '/home', // This prevents app exit
  // ...
)
```

### Issue: Payload is empty

**Solution:** Ensure you're storing the payload before sending the notification:

```dart
await screenLaunchByNotfication.storeNotificationPayload(payload);
await flutterLocalNotificationsPlugin.show(..., payload: payload);
```

### Issue: iOS build error with `.banner`

**Solution:** Already fixed in version 1.1.0. The code uses version checks:
- iOS 14+: Uses `.banner`
- iOS 13: Uses `.alert`

### Issue: Android build error about desugaring

**Solution:** Add to `android/app/build.gradle.kts`:

```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### Issue: Notification not detected

**Checklist:**
1. ✅ Native code is properly set up (MainActivity.kt / AppDelegate.swift)
2. ✅ MethodChannel name is `launch_channel`
3. ✅ Notification includes payload
4. ✅ `storeNotificationPayload` is called before sending notification
5. ✅ App is completely closed (not just in background) when testing

---

## 📋 Requirements

- **Flutter SDK:** `>=3.3.0`
- **Dart SDK:** `^3.10.0`
- **Android:** Minimum SDK 21 (Android 5.0)
- **iOS:** Minimum iOS 10.0
- **flutter_local_notifications:** `^19.5.0` (recommended)

---

## 🔗 Links & Resources

- **Pub.dev Package:** [https://pub.dev/packages/screen_launch_by_notfication](https://pub.dev/packages/screen_launch_by_notfication)
- **GitHub Repository:** [https://github.com/ravikinha/screen_launch_by_notfication](https://github.com/ravikinha/screen_launch_by_notfication)
- **Documentation:** [https://swiftflutter.com/dynamicnotification](https://swiftflutter.com/dynamicnotification)
- **Issues:** [https://github.com/ravikinha/screen_launch_by_notfication/issues](https://github.com/ravikinha/screen_launch_by_notfication/issues)

---

## 📝 Version History

### Version 1.1.0 (Current)

- ✅ Added `SwiftFlutterMaterial` widget for automatic notification-based routing
- ✅ Enhanced back navigation handling - navigates to home route instead of exiting app
- ✅ Added `homeRoute` parameter for custom back navigation destination
- ✅ Added `routesWithPayload` for routes that need access to notification payload
- ✅ Improved iOS compatibility (iOS 13+ support)
- ✅ Better error handling and fallback mechanisms

### Version 1.0.0

- ✅ Initial release
- ✅ Detect if app was launched by tapping a notification
- ✅ Retrieve notification payload (works with flutter_local_notifications)
- ✅ Skip splash screens when opened from notification
- ✅ Support for Android and iOS
- ✅ Store notification payload for later retrieval

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 💬 Support

- **Documentation:** [swiftflutter.com/dynamicnotification](https://swiftflutter.com/dynamicnotification)
- **GitHub Issues:** [https://github.com/ravikinha/screen_launch_by_notfication/issues](https://github.com/ravikinha/screen_launch_by_notfication/issues)
- **Email:** (Add your support email if available)

---

## 🎓 Best Practices

1. **Always store payload before sending notification:**
   ```dart
   await screenLaunchByNotfication.storeNotificationPayload(payload);
   await notifications.show(..., payload: payload);
   ```

2. **Use SwiftFlutterMaterial for automatic routing:**
   - Reduces boilerplate code
   - Handles edge cases automatically
   - Provides better user experience

3. **Handle errors gracefully:**
   ```dart
   try {
     final result = await screenLaunchByNotfication.isFromNotification();
     // Handle result
   } catch (e) {
     // Fallback to default route
   }
   ```

4. **Test on all app states:**
   - App killed (terminated)
   - App in background
   - App in foreground

5. **Use meaningful payload structure:**
   ```dart
   final payload = jsonEncode({
     'type': 'message',
     'id': '123',
     'title': 'New Message',
     'body': 'You have a new message',
   });
   ```

---

## 📊 Project Statistics

- **Total Files:** 90+
- **Lines of Code:** ~2000+
- **Platforms:** Android, iOS
- **Dependencies:** flutter_local_notifications (recommended)
- **License:** MIT
- **Maintainer:** ravikinha

---

## 🌟 Features Comparison

| Feature | Without Plugin | With Plugin |
|---------|---------------|-------------|
| Detect notification launch | ❌ No | ✅ Yes |
| Get notification payload | ❌ No | ✅ Yes |
| Skip splash on notification | ❌ No | ✅ Yes |
| Works when app is killed | ❌ No | ✅ Yes |
| Automatic routing | ❌ Manual | ✅ Automatic |
| Back navigation handling | ❌ Manual | ✅ Automatic |

---

## 🚀 Getting Started Checklist

- [ ] Add dependency to `pubspec.yaml`
- [ ] Run `flutter pub get`
- [ ] Update `MainActivity.kt` (Android)
- [ ] Update `AppDelegate.swift` (iOS)
- [ ] Enable core library desugaring (Android)
- [ ] Initialize `flutter_local_notifications` (if using)
- [ ] Use `SwiftFlutterMaterial` widget or manual implementation
- [ ] Test on both platforms
- [ ] Test all app states (killed, background, foreground)

---

## 📱 Example App

A complete example app is included in the `example/` directory. It demonstrates:

- Basic notification detection
- Using `SwiftFlutterMaterial` widget
- Sending test notifications
- Displaying notification payload
- Handling back navigation

To run the example:

```bash
cd example
flutter run
```

---

## 🎯 Use Cases

1. **E-commerce Apps:** Route to order details when notification is tapped
2. **Social Media Apps:** Navigate to specific chat or post
3. **News Apps:** Open specific article from notification
4. **Messaging Apps:** Go directly to conversation
5. **Task Management:** Open specific task or project
6. **Any app with notifications:** Skip splash and go directly to relevant content

---

## 📖 Additional Resources

- [Flutter Notification Guide](https://flutter.dev/docs/development/packages-and-plugins/developing-packages)
- [flutter_local_notifications Documentation](https://pub.dev/packages/flutter_local_notifications)
- [Android Notification Best Practices](https://developer.android.com/develop/ui/views/notifications)
- [iOS User Notifications](https://developer.apple.com/documentation/usernotifications)

---

**Made with ❤️ by the SwiftFlutter team**

For more information, visit: [swiftflutter.com/dynamicnotification](https://swiftflutter.com/dynamicnotification)

