export 'screen_launch_by_notfication_widget.dart';
export 'deep_link_parser.dart';
export 'deep_link_handler.dart';
export 'routing_types.dart';

import 'screen_launch_by_notfication_platform_interface.dart';
import 'screen_launch_by_notfication_method_channel.dart';

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
  
  /// Stream of notification tap events when app is already running.
  /// 
  /// Subscribe to this stream to handle navigation when user taps a notification
  /// while the app is already open (foreground or background).
  /// 
  /// Returns a Stream that emits Maps with:
  /// - `isFromNotification` (bool): Always true for stream events
  /// - `payload` (String): The notification payload as a JSON string
  /// 
  /// Example:
  /// ```dart
  /// screenLaunchByNotfication.getNotificationStream().listen((event) {
  ///   final payload = jsonDecode(event['payload']);
  ///   // Navigate to notification screen
  ///   Navigator.pushNamed(context, '/notification', arguments: payload);
  /// });
  /// ```
  Stream<Map<String, dynamic>> getNotificationStream() {
    final platform = ScreenLaunchByNotficationPlatform.instance;
    if (platform is MethodChannelScreenLaunchByNotfication) {
      return platform.getNotificationStream();
    }
    // Return empty stream if platform doesn't support events
    return const Stream.empty();
  }
}
