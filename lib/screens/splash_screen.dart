// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../services/api_service.dart';
import 'main_conversation_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print("[Flow] SplashScreen.initState(): Starting.");
    _determineInitialRoute();
  }

  /// A generic function to check and print the status of all relevant permissions.
  Future<void> _checkAllPermissions() async {
    print("--- [Generic Permission Check] Starting ---");

    final permissions = [
      Permission.microphone,
      Permission.notification,
      Permission.location,
      Permission.systemAlertWindow, // "Display over other apps"
    ];

    for (var permission in permissions) {
      final status = await permission.status;
      // The permission name is long, so we split it to get the last part.
      print(
          "[Generic Permission Check] ${permission.toString().split('.').last}: $status");
    }
    print("--- [Generic Permission Check] Finished ---");
  }

  Future<void> _determineInitialRoute() async {
    print("[Flow] SplashScreen: Determining initial route...");
    // Give the splash screen a moment to be visible
    await Future.delayed(const Duration(seconds: 1));

    print("[Flow] SplashScreen: Loading user profile...");
    final userProfile = await UserProfileService.loadProfile();

    // Run our generic permission check for debugging purposes.
    await _checkAllPermissions();

    // If no profile exists or status is not 'active', go to registration flow.
    if (userProfile == null || userProfile.status != 'active') {
      print(
          "[Flow] SplashScreen: No active profile found. Navigating to WelcomeScreen.");
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      }
      return;
    }

    print(
        "[Flow] SplashScreen: Active profile found. Verifying user with backend...");
    // If profile exists, verify the user and go to the main screen.
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final verificationData =
          await ApiService().verifyUser(userProfile, fcmToken!);
      if (mounted) {
        print(
            "[Flow] SplashScreen: User verified. Navigating to MainConversationScreen.");
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => MainConversationScreen(
                userPhone: userProfile.phone,
                initialMessage:
                    verificationData['message'] ?? 'Welcome back!')));
      }
    } catch (e) {
      // If verification fails, delete the stale profile and go to registration.
      print(
          "[Flow] SplashScreen: User verification failed ($e). Deleting stale profile and navigating to WelcomeScreen.");
      await UserProfileService.deleteProfile();
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
