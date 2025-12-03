# screen_launch_by_notfication_example

Demonstrates how to use the screen_launch_by_notfication plugin with both **notifications** and **deep links**.

## Features

- ✅ Notification-based routing
- ✅ Deep link routing
- ✅ Dynamic payload handling
- ✅ Multiple route patterns

## Getting Started

1. Run the app:
   ```bash
   flutter run
   ```

2. The app will show the home screen with options to test notifications and deep links.

## Testing Notifications

### Send Test Notifications

1. Tap any notification button on the home screen:
   - **Chat Notification** - Routes to chat screen
   - **Order Notification** - Routes to notification screen
   - **General Notification** - Routes to notification screen

2. Close the app completely

3. Tap the notification from the notification tray

4. The app will open directly to the appropriate screen, bypassing the splash screen!

## Testing Deep Links

### Android Commands

Open a terminal and run:

```bash
# Test product deep link (path-based)
adb shell am start -a android.intent.action.VIEW -d "notificationapp://product/123"

# Test product deep link (query params)
adb shell am start -a android.intent.action.VIEW -d "notificationapp://product?id=456&name=Widget"

# Test profile deep link
adb shell am start -a android.intent.action.VIEW -d "notificationapp://profile?userId=789"
```

### iOS Commands

Open a terminal and run:

```bash
# Test product deep link (path-based)
xcrun simctl openurl booted "notificationapp://product/123"

# Test product deep link (query params)
xcrun simctl openurl booted "notificationapp://product?id=456&name=Widget"

# Test profile deep link
xcrun simctl openurl booted "notificationapp://profile?userId=789"
```

### Test in Safari (iOS)

1. Open Safari on simulator/device
2. Type `notificationapp://product/123` in the address bar
3. Press Enter
4. The app will open to the product screen!

## Deep Link Examples

The example app handles these deep link patterns:

| Deep Link URL | Route | Result |
|--------------|-------|--------|
| `notificationapp://product/123` | `/product` | Opens product screen with ID 123 |
| `notificationapp://product?id=456` | `/product` | Opens product screen with ID 456 |
| `notificationapp://product?id=789&name=Widget` | `/product` | Opens product screen with ID 789 and name |
| `notificationapp://profile?userId=123` | `/notificationScreen` | Opens notification screen with profile data |

## App Structure

```
lib/
├── main.dart                    # Main app with SwiftFlutterMaterial
├── screens/
│   ├── home_screen.dart        # Home screen with test buttons
│   ├── product_screen.dart     # Product screen (deep link target)
│   ├── notification_screen.dart # Notification screen
│   ├── chat_screen.dart        # Chat screen
│   └── splash_screen.dart      # Splash screen
└── services/
    └── notification_service.dart # Notification service
```

## Configuration

### Android

Deep link intent filter is already configured in:
`android/app/src/main/AndroidManifest.xml`

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="notificationapp" android:host="*"/>
</intent-filter>
```

### iOS

URL scheme is already configured in:
`ios/Runner/Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>notificationapp</string>
        </array>
    </dict>
</array>
```

## How It Works

### Notification Routing

1. User taps notification
2. Plugin detects notification launch
3. `onNotificationLaunch` callback is called
4. Returns `SwiftRouting` with route and payload
5. App navigates to the specified route

### Deep Link Routing

1. User opens deep link (e.g., `myapp://product/123`)
2. Plugin captures the deep link
3. `onDeepLink` callback is called with parsed URL
4. Returns `SwiftRouting` with route and payload
5. App navigates to the specified route

### Priority

Deep links take priority over notifications when both are present.

## Code Examples

### Deep Link Handler

```dart
onDeepLink: ({required url, required route, required queryParams}) {
  // Handle product deep links
  if (route == '/product') {
    final productId = queryParams['id'] ?? queryParams['productId'];
    if (productId != null) {
      return SwiftRouting(
        route: '/product',
        payload: {
          'productId': productId,
          'source': 'deeplink',
        },
      );
    }
  }
  return null;
}
```

### Receiving Payload in Screen

```dart
class ProductScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments 
        as Map<String, dynamic>?;
    final productId = args?['productId'] ?? 'Unknown';
    
    return Scaffold(
      body: Text('Product ID: $productId'),
    );
  }
}
```

## Troubleshooting

### Deep link not working?

1. **Check configuration:**
   - Android: Verify `AndroidManifest.xml` has intent filter
   - iOS: Verify `Info.plist` has URL scheme

2. **Check URL scheme:**
   - Make sure you're using `notificationapp://` (matches the configured scheme)
   - Scheme is case-sensitive

3. **Test commands:**
   - Use the exact commands shown above
   - Check device/simulator logs for errors

4. **Check routes:**
   - Make sure the route exists in your `MaterialApp` routes
   - Verify `onDeepLink` callback returns `SwiftRouting` object

## More Information

- [Deep Link Setup Guide](../DEEPLINK_SETUP.md)
- [Quick Start Guide](../DEEPLINK_QUICKSTART.md)
- [Configuration Guide](../DEEPLINK_CONFIG.md)
