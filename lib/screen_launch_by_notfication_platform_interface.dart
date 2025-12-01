import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'screen_launch_by_notfication_method_channel.dart';

abstract class ScreenLaunchByNotficationPlatform extends PlatformInterface {
  /// Constructs a ScreenLaunchByNotficationPlatform.
  ScreenLaunchByNotficationPlatform() : super(token: _token);

  static final Object _token = Object();

  static ScreenLaunchByNotficationPlatform _instance = MethodChannelScreenLaunchByNotfication();

  /// The default instance of [ScreenLaunchByNotficationPlatform] to use.
  ///
  /// Defaults to [MethodChannelScreenLaunchByNotfication].
  static ScreenLaunchByNotficationPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ScreenLaunchByNotficationPlatform] when
  /// they register themselves.
  static set instance(ScreenLaunchByNotficationPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Checks if the app was launched from a notification tap.
  /// Returns a Map with 'isFromNotification' (bool) and 'payload' (String) keys.
  Future<Map<String, dynamic>> isFromNotification() {
    throw UnimplementedError('isFromNotification() has not been implemented.');
  }

  /// Stores notification payload in native storage for later retrieval.
  /// This is useful when sending notifications before the app is closed.
  Future<bool> storeNotificationPayload(String payload) {
    throw UnimplementedError('storeNotificationPayload() has not been implemented.');
  }
}
