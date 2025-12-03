import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSending = false;

  Future<void> _sendTestNotification(String type) async {
    setState(() {
      _isSending = true;
    });

    try {
      Map<String, dynamic> payload;
      String title;
      String body;

      switch (type) {
        case 'chat':
          payload = {
            'title': 'New Chat Message',
            'body': 'You have a new message from John',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'type': 'chat',
            'chatnotification': true,
            'chatId': '12345',
            'senderName': 'John Doe',
            'message': 'Hey, how are you?',
          };
          title = 'New Chat Message';
          body = 'You have a new message from John';
          break;
        case 'order':
          payload = {
            'title': 'Order Update',
            'body': 'Your order #12345 has been shipped',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'type': 'order',
            'orderId': '12345',
            'status': 'shipped',
          };
          title = 'Order Update';
          body = 'Your order #12345 has been shipped';
          break;
        default:
          payload = {
            'title': 'Test Notification',
            'body': 'This is a test notification payload',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'type': 'test',
          };
          title = 'Test Notification';
          body = 'Tap to open app from notification';
      }

      await NotificationService.sendNotification(
        title: title,
        body: body,
        payload: payload,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${type.toUpperCase()} notification sent! Close the app and tap the notification to test.',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home, size: 100, color: Colors.green),
                const SizedBox(height: 20),
                const Text(
                  'Welcome Home!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Test different notification types',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                // Chat Notification Button
                ElevatedButton.icon(
                  onPressed: _isSending ? null : () => _sendTestNotification('chat'),
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.chat),
                  label: const Text('Send Chat Notification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // Order Notification Button
                ElevatedButton.icon(
                  onPressed: _isSending ? null : () => _sendTestNotification('order'),
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.shopping_bag),
                  label: const Text('Send Order Notification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // General Notification Button
                ElevatedButton.icon(
                  onPressed: _isSending ? null : () => _sendTestNotification('general'),
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.notifications_active),
                  label: const Text('Send General Notification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                const Text(
                  'Test Deep Links',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Use these commands to test deep links:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                // Deep Link Testing Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Android Commands:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCommandText('adb shell am start -a android.intent.action.VIEW -d "notificationapp://product/123"'),
                      const SizedBox(height: 4),
                      _buildCommandText('adb shell am start -a android.intent.action.VIEW -d "notificationapp://product?id=456"'),
                      const SizedBox(height: 12),
                      const Text(
                        'iOS Commands:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCommandText('xcrun simctl openurl booted "notificationapp://product/123"'),
                      const SizedBox(height: 4),
                      _buildCommandText('xcrun simctl openurl booted "notificationapp://product?id=456"'),
                      const SizedBox(height: 12),
                      const Text(
                        'Or test in Safari:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCommandText('Type: notificationapp://product/123'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Tap any button to send a test notification. Close the app and tap the notification to see dynamic routing in action.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCommandText(String command) {
    return SelectableText(
      command,
      style: const TextStyle(
        fontSize: 11,
        fontFamily: 'monospace',
        color: Colors.black87,
      ),
    );
  }
}

