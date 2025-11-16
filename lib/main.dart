// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Import the new SplashScreen which will be the app's entry point.
import 'screens/splash_screen.dart';

import 'services/notification_service.dart';

// This global key is essential for the NotificationService to navigate or show dialogs from the background.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// --- UPDATE: This top-level function now delegates all work to our NotificationService ---
// Firebase requires the background handler to be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // We must initialize Firebase in this background isolate before using any Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Delegate the actual processing to our service's static method, as designed in our architecture.
  await NotificationService.processBackgroundMessage(message);
}

void main() async {
  // Ensure the Flutter engine is ready before doing any async work.
  print("[Flow] main(): Flutter engine binding initialized.");
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for the main app instance.
  print("[Flow] main(): Initializing Firebase...");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("[Flow] main(): Firebase initialized.");

  // Set the background messaging handler that Firebase will call when the app is not in the foreground.
  print("[Flow] main(): Setting background messaging handler.");
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    print("[Flow] MyApp.initState(): Initializing NotificationService...");
    // Initialize the NotificationService early to handle background events.
    NotificationService().initialize();
    print("[Flow] MyApp.initState(): NotificationService initialized.");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Assign the global key to the MaterialApp.
      navigatorKey: navigatorKey,
      title: 'Memora',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // The app's home is now the simple SplashScreen.
      home: const SplashScreen(),
    );
  }
}
