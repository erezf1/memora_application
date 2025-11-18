// lib/screens/incoming_call_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/user_profile_service.dart';
import 'main_conversation_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  static const String routeName = '/incoming_call';

  final String callerName;
  final String callId;
  final String initialMessage;

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
    debugPrint(
        '[IncomingCallScreen] initState callId=${widget.callId} caller=${widget.callerName}');
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await UserProfileService.loadProfile();
    setState(() {
      _userProfile = profile;
    });
  }

  Future<void> _declineCall() async {
    debugPrint(
        '[IncomingCallScreen] Decline tapped for callId=${widget.callId}');
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final phone = _userProfile?.phone;
      if (phone != null && phone.isNotEmpty) {
        try {
          await _apiService.declineCall(phone);
        } catch (e) {
          debugPrint('[IncomingCallScreen] declineCall error: $e');
        }
      }
      await NotificationService.cancelIncomingCallNotification();
      debugPrint('[IncomingCallScreen] Notification canceled (decline)');
      debugPrint('[IncomingCallScreen] Exiting app on decline');
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      SystemNavigator.pop();
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _answerCall() async {
    debugPrint(
        '[IncomingCallScreen] Answer tapped for callId=${widget.callId}');
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final phone = _userProfile?.phone;
      if (phone != null && phone.isNotEmpty) {
        try {
          await _apiService.answerCall(phone);
        } catch (e) {
          debugPrint('[IncomingCallScreen] answerCall error: $e');
        }
      }

      await NotificationService.cancelIncomingCallNotification();
      debugPrint('[IncomingCallScreen] Notification canceled (answer)');

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainConversationScreen(
            userPhone: _userProfile?.phone ?? '',
            initialMessage: widget.initialMessage,
          ),
        ),
        (route) => false,
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
              'Incoming call',
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
                    label: 'Decline',
                    icon: Icons.call_end,
                    color: Colors.red,
                    onPressed: _declineCall,
                  ),
                  _buildActionButton(
                    label: 'Answer',
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
