import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String? senderName;

  const ChatScreen({super.key, this.chatId, this.senderName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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

    final chatId = widget.chatId ?? _payload['chatId']?.toString() ?? 'Unknown';
    final senderName = widget.senderName ?? _payload['senderName']?.toString() ?? 'Unknown';
    final message = _payload['message']?.toString() ?? 'No message';

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat: $senderName'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacementNamed("/home"),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
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
                  Icons.chat_bubble_outline,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                Text(
                  'Chat with $senderName',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Chat ID: $chatId',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
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
                        'Latest Message:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
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
                          'Full Payload:',
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
                    foregroundColor: Colors.teal,
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

