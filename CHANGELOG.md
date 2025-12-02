## 2.2.0

* 🎯 **SwiftRouting Class**: New `SwiftRouting` class for type-safe routing with route and payload
* 📦 **Nullable Payload Support**: Payload in `SwiftRouting` is now optional - you can pass `null` if no data is needed
* 🔧 **Improved API**: `onNotificationLaunch` callback now returns `SwiftRouting?` instead of a map for better type safety
* ✨ **Better Developer Experience**: Cleaner API with `SwiftRouting(route: '/path', payload: {...})` syntax
* 📝 **Updated Examples**: Example app updated to demonstrate new `SwiftRouting` API
* Learn more: https://swiftflutter.com/dynamicnotification

## 2.1.0

* 🎯 **Dynamic Notification Routing**: `onNotificationLaunch` callback now works for both initial launch AND notification taps while app is running
* 🔄 **Real-time Navigation**: Automatically navigates to appropriate screen when notification is tapped while app is open (foreground/background)
* 📱 **Event Stream Support**: Added `getNotificationStream()` method to listen for notification taps in real-time
* 🎨 **Enhanced Callback**: `onNotificationTap` callback for custom handling of notification taps while app is running
* 🚀 **Improved Navigation**: Better navigator handling with retry logic and support for both MaterialApp and GetMaterialApp
* 📦 **Better Example**: Reorganized example app with multiple screens and dynamic routing based on notification payload
* Learn more: https://swiftflutter.com/dynamicnotification

## 2.0.0

* 🎉 **Major API Update**: `SwiftFlutterMaterial` now accepts `MaterialApp` or `GetMaterialApp` instances
* ✨ **Zero Native Setup**: Plugin now handles all native code automatically - no need to modify MainActivity or AppDelegate
* 🚀 **GetMaterialApp Support**: Full support for GetX navigation with `GetMaterialApp`
* 🎯 **Simplified API**: Pass your existing `MaterialApp` or `GetMaterialApp` widget - all routing properties are automatically managed
* 🔧 **Better Integration**: Works seamlessly with your existing app structure without code duplication
* 📦 **Self-Contained Plugin**: All native implementation moved to plugin itself - works for all projects out of the box
* 🎨 **Flexible Configuration**: Use `onNotificationLaunch` callback to customize routing based on notification status and payload
* Learn more: https://swiftflutter.com/dynamicnotification

## 1.1.0

* Added `SwiftFlutterMaterial` widget for automatic notification-based routing
* Enhanced back navigation handling - navigates to home route instead of exiting app
* Added `homeRoute` parameter for custom back navigation destination
* Added `routesWithPayload` for routes that need access to notification payload
* Improved iOS compatibility (iOS 13+ support)
* Better error handling and fallback mechanisms
* Learn more: https://swiftflutter.com/dynamicnotification

## 1.0.0

* Initial release
* Detect if app was launched by tapping a notification
* Retrieve notification payload (works with flutter_local_notifications)
* Skip splash screens when opened from notification
* Support for Android and iOS
* Store notification payload for later retrieval
