import 'screen_launch_by_notfication_platform_interface.dart';

/// A Flutter plugin to detect if the app was launched by tapping a notification
/// and retrieve the notification payload, allowing you to skip splash screens
/// and route directly to notification-specific screens.
class ScreenLaunchByNotfication {
  /// Gets the platform version (for testing purposes).
  Future<String?> getPlatformVersion() {
    return ScreenLaunchByNotficationPlatform.instance.getPlatformVersion();
  }

  /// Checks if the app was launched from a notification tap.
  /// 
  /// Returns a Map containing:
  /// - `isFromNotification` (bool): Whether the app was opened from a notification
  /// - `payload` (String): The notification payload as a JSON string
  /// 
  /// Example:
  /// ```dart
  /// final result = await screenLaunchByNotfication.isFromNotification();
  /// if (result['isFromNotification'] == true) {
  ///   final payload = jsonDecode(result['payload']);
  ///   // Handle notification launch
  /// }
  /// ```
  Future<Map<String, dynamic>> isFromNotification() {
    return ScreenLaunchByNotficationPlatform.instance.isFromNotification();
  }

  /// Stores notification payload in native storage for later retrieval.
  /// 
  /// This is useful when you want to send a notification and then close the app,
  /// ensuring the payload is available when the app is reopened from the notification.
  /// 
  /// The payload should be a JSON string.
  /// 
  /// Example:
  /// ```dart
  /// final payload = jsonEncode({'title': 'Test', 'body': 'Message'});
  /// await screenLaunchByNotfication.storeNotificationPayload(payload);
  /// ```
  Future<bool> storeNotificationPayload(String payload) {
    return ScreenLaunchByNotficationPlatform.instance.storeNotificationPayload(payload);
  }
}
