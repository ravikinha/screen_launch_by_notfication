import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'screen_launch_by_notfication_platform_interface.dart';

/// An implementation of [ScreenLaunchByNotficationPlatform] that uses method channels.
class MethodChannelScreenLaunchByNotfication extends ScreenLaunchByNotficationPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('launch_channel');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<Map<String, dynamic>> isFromNotification() async {
    final response = await methodChannel.invokeMethod<Map<Object?, Object?>>('isFromNotification') ?? {};
    
    return {
      'isFromNotification': response['isFromNotification'] ?? false,
      'payload': response['payload']?.toString() ?? '{}',
    };
  }

  @override
  Future<bool> storeNotificationPayload(String payload) async {
    final result = await methodChannel.invokeMethod<bool>('storeNotificationPayload', payload);
    return result ?? false;
  }
}
