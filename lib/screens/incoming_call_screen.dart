// lib/screens/incoming_call_screen.dart

import 'package:flutter/material.dart';
import 'package:memora_application/models/user_profile.dart';
import 'package:memora_application/services/user_profile_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'main_conversation_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callId;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _isProcessing = false;

  Future<UserProfile?> _getProfile() async {
    return await UserProfileService.loadProfile();
  }

  Future<void> _answerCall() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    await NotificationService.cancelIncomingCallNotification();

    final profile = await _getProfile();
    if (profile == null || !mounted) {
      // If no profile, can't answer. Just close the screen.
      Navigator.of(context).pop();
      return;
    }

    try {
      await ApiService().answerCall(profile.phone, widget.callId);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MainConversationScreen(
              userPhone: profile.phone,
              initialMessage: 'Hello, how can I help you?',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error answering call: $e');
      if (mounted) Navigator.of(context).pop(); // Close screen on error
    }
  }

  Future<void> _declineCall() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    await NotificationService.cancelIncomingCallNotification();

    final profile = await _getProfile();
    if (profile != null) {
      // We don't wait for this, just fire and forget.
      ApiService().declineCall(profile.phone, widget.callId);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.callerName,
                style: const TextStyle(fontSize: 28, color: Colors.white)),
            const SizedBox(height: 10),
            const Text('Incoming Call...',
                style: TextStyle(fontSize: 18, color: Colors.white70)),
            const SizedBox(height: 100),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  onPressed: _declineCall,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
                FloatingActionButton(
                  onPressed: _answerCall,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.call, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
