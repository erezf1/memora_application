// lib/screens/incoming_call_screen.dart

import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'main_conversation_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  static const String routeName = '/incoming_call';

  final String callerName;
  final String callId;
  final String initialMessage; // text the assistant should speak

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callId,
    required this.initialMessage,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final ApiService _apiService = ApiService();
  UserProfile? _userProfile;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await UserProfileService.loadProfile();
    setState(() {
      _userProfile = profile;
    });
  }

  Future<void> _declineCall() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final phone = _userProfile?.phone;

      if (phone != null && phone.isNotEmpty) {
        // TODO: implement /voice/call-declined endpoint in ApiService if needed
        // await _apiService.callDeclined(phone);
        print(
            '[IncomingCall] Declined call for user_phone=$phone, callId=${widget.callId}');
      } else {
        print(
            '[IncomingCall] Declined call but user profile/phone is missing.');
      }

      await NotificationService.cancelIncomingCallNotification();
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _answerCall() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final phone = _userProfile?.phone;

      if (phone != null && phone.isNotEmpty) {
        // TODO: implement /voice/call-answered endpoint in ApiService if needed
        // await _apiService.callAnswered(phone);
        print(
            '[IncomingCall] Answered call for user_phone=$phone, callId=${widget.callId}');
      } else {
        print(
            '[IncomingCall] Answered call but user profile/phone is missing.');
      }

      await NotificationService.cancelIncomingCallNotification();

      if (!mounted) return;

      // Navigate to the main conversation screen, as in your app flow.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainConversationScreen(
            userPhone: _userProfile?.phone ?? '',
            initialMessage: widget.initialMessage,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              'שיחה נכנסת', // Incoming call
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.callerName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Memora',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white54,
              ),
            ),
            const Spacer(),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    label: 'דחייה', // Decline
                    icon: Icons.call_end,
                    color: Colors.red,
                    onPressed: _declineCall,
                  ),
                  _buildActionButton(
                    label: 'מענה', // Answer
                    icon: Icons.call,
                    color: Colors.green,
                    onPressed: _answerCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        FloatingActionButton(
          heroTag: label,
          onPressed: onPressed,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
