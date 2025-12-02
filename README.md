# screen_launch_by_notfication

A Flutter plugin that detects if your app was launched by tapping a notification and retrieves the notification payload. This enables you to skip splash screens and route directly to notification-specific screens, just like native apps.

📚 **Learn more:** [swiftflutter.com/dynamicnotification](https://swiftflutter.com/dynamicnotification)

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
  screen_launch_by_notfication: ^2.1.0
  flutter_local_notifications: ^19.5.0  # Recommended for sending notifications
  get: ^4.6.6  # Required only if using GetMaterialApp
```

Then run:

```bash
flutter pub get
```

### Android Setup

**No native code setup required!** 🎉 The plugin handles everything automatically.

Just ensure you have the required dependencies in your `android/app/build.gradle.kts`:

```kotlin
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
```

### iOS Setup

**No native code setup required!** 🎉 The plugin handles everything automatically.

For iOS, you only need to request notification permissions in your app (if you haven't already):

```swift
import UserNotifications

// In your AppDelegate or wherever you request permissions
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted {
    DispatchQueue.main.async {
      UIApplication.shared.registerForRemoteNotifications()
    }
  }
}
```

**Note:** The plugin automatically handles all notification detection and payload storage. No need to modify `AppDelegate.swift` or `MainActivity.kt`!

## Usage

### Using SwiftFlutterMaterial Widget (Recommended)

The easiest way to use this plugin is with the `SwiftFlutterMaterial` widget. Simply wrap your existing `MaterialApp` or `GetMaterialApp`:

#### With MaterialApp

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
      materialApp: MaterialApp(
        title: 'My App',
        theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => SplashScreen(),
        '/notification': (_) => NotificationScreen(),
        '/home': (_) => HomeScreen(),
      },
      ),
      onNotificationLaunch: ({required isFromNotification, required payload}) {
        if (isFromNotification) {
          return '/notification';
        }
        return null; // Use MaterialApp's initialRoute
      },
    );
  }
}
```

#### With GetMaterialApp

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      getMaterialApp: GetMaterialApp(
        title: 'My App',
        theme: ThemeData(primarySwatch: Colors.blue),
        initialRoute: '/splash',
        getPages: [
          GetPage(name: '/splash', page: () => SplashScreen()),
          GetPage(name: '/notification', page: () => NotificationScreen()),
          GetPage(name: '/home', page: () => HomeScreen()),
        ],
      ),
      onNotificationLaunch: ({required isFromNotification, required payload}) {
        if (isFromNotification) {
          return '/notification';
        }
        return null; // Use GetMaterialApp's initialRoute
      },
    );
  }
}
```

**Key Features:**
- ✅ Pass your existing `MaterialApp` or `GetMaterialApp` - no need to duplicate properties
- ✅ All routing properties (routes, getPages, initialRoute, etc.) are automatically managed
- ✅ Zero native code setup required
- ✅ Works with your existing app structure

Learn more about `SwiftFlutterMaterial` at [swiftflutter.com/dynamicnotification](https://swiftflutter.com/dynamicnotification)

### Basic Usage (Manual)

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

## SwiftFlutterMaterial Widget

Version 2.1.0 introduces enhanced notification handling with real-time navigation support:

**New in 2.1.0:**
- ✅ **Real-time Navigation**: Automatically navigates when notification is tapped while app is running
- ✅ **Dynamic Routing**: `onNotificationLaunch` callback works for both initial launch and runtime taps
- ✅ **Event Stream**: `getNotificationStream()` method for listening to notification events
- ✅ **Custom Tap Handler**: `onNotificationTap` callback for custom handling of runtime notification taps

**Features (from 2.0.0):**
- ✅ Accepts `MaterialApp` or `GetMaterialApp` instances
- ✅ Zero native code setup required
- ✅ Automatic route management
- ✅ Full GetX navigation support
- ✅ Works seamlessly with existing app structure
- ✅ Custom routing based on conditions via `onNotificationLaunch` callback
- ✅ All MaterialApp/GetMaterialApp properties are preserved and managed
- ✅ Loading state while checking notification status
- ✅ Error handling with fallback to initial route
- ✅ Self-contained native implementation

**Example with dynamic routing:**
```dart
SwiftFlutterMaterial(
  materialApp: MaterialApp(
    routes: {
      '/home': (context) => HomeScreen(),
      '/chatPage': (context) => ChatScreen(),
      '/notificationScreen': (context) => NotificationScreen(),
    },
  ),
  onNotificationLaunch: ({required isFromNotification, required payload}) {
    // Works for both initial launch AND runtime notification taps
    if (payload.containsKey('chatnotification')) {
      return '/chatPage';  // Route to chat screen
    }
    if (isFromNotification) {
      return '/notificationScreen';  // Route to notification screen
    }
    return null;  // Use default initialRoute
  },
)
```

Learn more about `SwiftFlutterMaterial` at [swiftflutter.com/dynamicnotification](https://swiftflutter.com/dynamicnotification)

## Support

📚 **Documentation:** [swiftflutter.com/dynamicnotification](https://swiftflutter.com/dynamicnotification)

If you encounter any issues or have questions, please file an issue on the [GitHub repository](https://github.com/ravikinha/screen_launch_by_notfication/issues).
