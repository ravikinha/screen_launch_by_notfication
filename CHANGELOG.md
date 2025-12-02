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
