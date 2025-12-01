# screen_launch_by_notfication

A Flutter plugin that detects if your app was launched by tapping a notification and retrieves the notification payload. This enables you to skip splash screens and route directly to notification-specific screens, just like native apps.

## Features

✅ **Detect notification launches** - Know when your app was opened from a notification  
✅ **Retrieve notification payload** - Get all notification data including custom payload  
✅ **Skip splash screens** - Route directly to notification screens when opened from notification  
✅ **Works in all app states** - Detects notification taps when app is killed, in background, or foreground  
✅ **Cross-platform** - Works on both Android and iOS  
✅ **Compatible with flutter_local_notifications** - Works seamlessly with the popular notification plugin  

## Overview

Flutter by default cannot detect whether the app was launched by tapping a notification. However, Android & iOS natively can detect this even when the app is:
- ❌ Killed (terminated)
- ❌ In background
- ❌ Not running at all

This plugin bridges that gap by:
1. Native code captures the notification launch event
2. Native code saves a flag and payload
3. Flutter reads the flag via MethodChannel before `runApp()`
4. Flutter decides the initial screen → splash / home / notification screen

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  screen_launch_by_notfication: ^1.0.0
  flutter_local_notifications: ^19.5.0  # Recommended for sending notifications
```

Then run:

```bash
flutter pub get
```

### Android Setup

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

2. **Update your MainActivity.kt** to detect notification taps:

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

### iOS Setup

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
    
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted {
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      }
    }
    
    UNUserNotificationCenter.current().delegate = self
    
    if let notification = launchOptions?[.remoteNotification] as? [String: Any] {
      UserDefaults.standard.set(true, forKey: "openFromNotification")
      if let jsonData = try? JSONSerialization.data(withJSONObject: notification),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        UserDefaults.standard.set(jsonString, forKey: "notificationPayload")
      }
      UserDefaults.standard.synchronize()
    }
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
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
    
    completionHandler([.banner, .sound, .badge])
  }
}
```

## Usage

### Basic Usage

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

### With flutter_local_notifications

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> sendNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'channel_id',
    'Channel Name',
    channelDescription: 'Channel Description',
    importance: Importance.high,
    priority: Priority.high,
  );

  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  final payload = jsonEncode({
    'title': 'Test Notification',
    'body': 'This is a test',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  });

  // Store payload before sending notification
  final screenLaunchByNotfication = ScreenLaunchByNotfication();
  await screenLaunchByNotfication.storeNotificationPayload(payload);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    'Test Notification',
    'Tap to open app',
    platformChannelSpecifics,
    payload: payload,
  );
}
```

### Displaying Notification Payload

```dart
class NotificationScreen extends StatelessWidget {
  final String payload;

  const NotificationScreen({super.key, required this.payload});

  Map<String, dynamic> getPayloadMap() {
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final payloadMap = getPayloadMap();

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Screen')),
      body: payloadMap.isNotEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: payloadMap.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key),
                  subtitle: Text(entry.value.toString()),
                );
              }).toList(),
            )
          : const Center(child: Text('No payload data')),
    );
  }
}
```

## API Reference

### `isFromNotification()`

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

### `storeNotificationPayload(String payload)`

Stores notification payload in native storage for later retrieval.

**Parameters:**
- `payload` (String): JSON string containing the notification payload

**Returns:** `Future<bool>` - `true` if successful

**Example:**
```dart
final payload = jsonEncode({'title': 'Test', 'body': 'Message'});
await screenLaunchByNotfication.storeNotificationPayload(payload);
```

## How It Works

1. **User taps notification** → Native code captures the launch event
2. **Native code saves flag** → `openFromNotification = true` in SharedPreferences/UserDefaults
3. **Native code saves payload** → Notification data stored as JSON
4. **Flutter starts** → Reads flag via MethodChannel before `runApp()`
5. **Flutter decides route** → Bypasses splash if opened from notification

## Result

- **Normal launch:** Splash → Home
- **Notification launch:** Directly to NotificationScreen (No Splash)

## Requirements

- Flutter SDK: `>=3.3.0`
- Dart SDK: `^3.10.0`
- Android: Minimum SDK 21 (Android 5.0)
- iOS: Minimum iOS 10.0

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions, please file an issue on the [GitHub repository](https://github.com/ravikinha/screen_launch_by_notfication/issues).
