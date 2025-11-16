// lib/screens/main_conversation_screen.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler
import 'package:flutter/services.dart'; // Required for closing the app
// --- FIX APPLIED HERE: Added a line break to correctly import the ApiService ---
import 'splash_screen.dart';
import '../services/api_service.dart';

class MainConversationScreen extends StatefulWidget {
  final String initialMessage;
  final String userPhone;

  const MainConversationScreen({
    super.key,
    required this.userPhone,
    required this.initialMessage,
  });

  @override
  State<MainConversationScreen> createState() => _MainConversationScreenState();
}

class _MainConversationScreenState extends State<MainConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ApiService _apiService = ApiService();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // --- NEW: Log to confirm this screen was created ---
    print("[Flow] MainConversationScreen initState called.");

    // --- NEW: Check for the overlay permission here ---
    _checkAndRequestOverlayPermission();

    if (widget.initialMessage.isNotEmpty) {
      _addMessage('assistant', widget.initialMessage);
    }
  }

  // --- NEW: Function to handle the overlay permission ---
  Future<void> _checkAndRequestOverlayPermission() async {
    print("[Permission] Checking System Alert Window permission...");
    final status = await Permission.systemAlertWindow.status;
    print("[Permission] Current System Alert Window status: $status");

    if (status.isGranted) {
      print("[Permission] System Alert Window permission is granted.");
      return;
    }

    // If not granted, request it. This will open the app settings screen for the user.
    print(
        "[Permission] System Alert Window permission not granted. Requesting...");
    // We don't await this to avoid blocking the UI, but it will open settings.
    await Permission.systemAlertWindow.request();
  }

  void _addMessage(String sender, String text) {
    setState(() {
      _messages.insert(0, {'sender': sender, 'text': text});
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _isLoading) {
      return;
    }

    final String messageText = _messageController.text;
    _addMessage('user', messageText);
    _messageController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      final String reply =
          await _apiService.sendMessage(widget.userPhone, messageText);
      _addMessage('assistant', reply);
    } catch (e) {
      _addMessage('assistant', 'Sorry, I ran into an error. Please try again.');
      print('Error sending message: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- HANG UP BUTTON FUNCTIONALITY - UPDATED ---
  Future<void> _hangUp() async {
    // 1. First, inform the backend that the user is disconnecting.
    // We use widget.userPhone to identify the user.
    await _apiService.disconnect(widget.userPhone);

    // --- FIX: Use a MethodChannel to reliably move the app to the background ---
    // This is more compatible than SystemNavigator.sendToBackground().
    const platform = MethodChannel('com.example.memora_application/native');
    await platform.invokeMethod('sendToBackground');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Memora', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.redAccent, size: 28),
            onPressed: _hangUp,
            tooltip: 'Close App',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(8.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message['sender'] == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(message['text']!),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(),
            _buildTextComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blue),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
