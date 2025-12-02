import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  Map<String, dynamic> _payload = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayload();
  }

  Future<void> _loadPayload() async {
    try {
      final screenLaunchByNotfication = ScreenLaunchByNotfication();
      final result = await screenLaunchByNotfication.isFromNotification();
      final payloadString = result['payload'] ?? '{}';
      
      setState(() {
        try {
          _payload = jsonDecode(payloadString) as Map<String, dynamic>;
        } catch (e) {
          _payload = {'raw': payloadString};
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _payload = {};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Screen'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Icon(
                  Icons.notifications_active,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Opened from Notification!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'This screen was opened directly because you tapped a notification. The splash screen was bypassed.',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_payload.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notification Payload:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._payload.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key}: ',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.value.toString(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed("/home");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Go to Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

