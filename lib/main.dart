// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'services/notification_service.dart';

/// Global navigator key so NotificationService can navigate from
/// notification taps (e.g., to an incoming-call screen).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register background message handler BEFORE Firebase.initializeApp().
  FirebaseMessaging.onBackgroundMessage(
    NotificationService.firebaseMessagingBackgroundHandler,
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize local notifications + FCM listeners.
  await NotificationService.initialize();

  runApp(const MemoraApp());
}

class MemoraApp extends StatelessWidget {
  const MemoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Memora',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Your current entry screen
      home: const SplashScreen(),

      // Define the routes for navigation.
      routes: {
        '/incoming_call': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          final callerName = args?['callerName'] as String? ?? 'Unknown';
          final callId = args?['callId'] as String? ?? '';
          return IncomingCallScreen(
            callerName: callerName,
            callId: callId,
          );
        },
      },
    );
  }
}
