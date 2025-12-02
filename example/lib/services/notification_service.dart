import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final ScreenLaunchByNotfication _screenLaunch =
      ScreenLaunchByNotfication();

  /// Initialize notification service
  static Future<void> initialize() async {
    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions (Android 13+)
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request permissions (iOS)
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    // This is called when a notification is tapped (after Flutter has started)
    // The payload is in response.payload
    // Store it in native code for consistency using the plugin
    if (response.payload != null && response.payload!.isNotEmpty) {
      _screenLaunch.storeNotificationPayload(response.payload!);
    }
  }

  /// Send a notification with payload
  static Future<void> sendNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    // Create notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_notification_channel',
      'Test Notifications',
      channelDescription: 'Channel for test notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
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

    // Convert payload to JSON string
    final payloadString = jsonEncode(payload);

    // Store notification payload using the plugin before sending
    await _screenLaunch.storeNotificationPayload(payloadString);

    // Show notification with payload
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: payloadString,
    );
  }
}

