import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'screen_launch_by_notfication_platform_interface.dart';

/// An implementation of [ScreenLaunchByNotficationPlatform] that uses method channels.
class MethodChannelScreenLaunchByNotfication extends ScreenLaunchByNotficationPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('launch_channel');
  
  /// The event channel used to receive notification tap events when app is running.
  @visibleForTesting
  final eventChannel = const EventChannel('launch_channel_events');
  
  Stream<Map<String, dynamic>>? _notificationStream;

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
  
  /// Stream of notification tap events when app is already running.
  /// Emits a Map with 'isFromNotification' (bool) and 'payload' (String) keys.
  Stream<Map<String, dynamic>> getNotificationStream() {
    _notificationStream ??= eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return {
          'isFromNotification': event['isFromNotification'] ?? true,
          'payload': event['payload']?.toString() ?? '{}',
        };
      }
      return {
        'isFromNotification': true,
        'payload': '{}',
      };
    });
    return _notificationStream!;
  }
}
