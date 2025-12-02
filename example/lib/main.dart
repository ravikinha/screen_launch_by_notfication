import 'package:flutter/material.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/chat_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SwiftFlutterMaterial(
      materialApp: MaterialApp(
        title: 'Screen Launch by Notification',
        initialRoute: '/normalSplash',
        routes: {
          '/normalSplash': (context) => const SplashScreen(),
          '/notificationScreen': (context) => const NotificationScreen(),
          '/chatPage': (context) {
            // Get route arguments if passed
            final args = ModalRoute.of(context)?.settings.arguments;
            if (args is Map<String, dynamic>) {
              return ChatScreen(
                chatId: args['chatId']?.toString(),
                senderName: args['senderName']?.toString(),
              );
            }
            return const ChatScreen();
          },
          '/home': (context) => const HomeScreen(),
        },
      ),
      // Dynamic routing based on notification payload
      onNotificationLaunch: ({required isFromNotification, required payload}) {
        print('App launched from notification: $isFromNotification, payload: $payload');

        // Check for chat notification
        if (payload.containsKey('chatnotification')) {
          print('Routing to chat notification screen');
          return '/chatPage';
        }

        // Check for order notification
        if (payload.containsKey('orderId')) {
          print('Routing to order screen');
          return '/notificationScreen'; // You can create a dedicated order screen
        }

        // Default: route to notification screen when launched from notification
        if (isFromNotification) {
          print('Routing to notification screen');
          return '/notificationScreen';
        }

        // Return null to use initialRoute from MaterialApp
        print('Using default initialRoute');
        return null;
      },
    );
  }
}
