// lib/screens/welcome_screen.dart

import 'package:flutter/material.dart';
import 'registration_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // This is your existing function to handle permissions and navigation.
  Future<void> _continue(BuildContext context) async {
    print(
        "[Flow] WelcomeScreen: 'Continue' pressed. Requesting standard permissions...");
    // Request all necessary permissions at once.
    await [
      Permission.notification,
      Permission.microphone,
      Permission.location,
    ].request();
    print(
        "[Flow] WelcomeScreen: Standard permissions requested. Navigating to RegistrationScreen.");

    // Navigate to the RegistrationScreen.
    // We use pushReplacement to prevent the user from navigating back to the welcome screen.
    Navigator.pushReplacement(
      context,
      // --- FIX #1: Removed the 'const' keyword ---
      // RegistrationScreen is a StatefulWidget and does not have a const constructor.
      MaterialPageRoute(builder: (_) => RegistrationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Your logo from the assets folder.
              Image.asset('assets/images/logo.png', height: 150, width: 150),

              const SizedBox(height: 20),

              const Text(
                "קַבָּלַת פָּנִים!", // "Welcome!" in Hebrew
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),

              const SizedBox(height: 10),

              const Text(
                "נדריך אותך צעד אחר צעד.", // "We will guide you step by step."
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),

              const SizedBox(height: 40),

              const Text(
                "כדי להשתמש בעוזר, אנו זקוקים לגישה ל:", // "To use the assistant, we need access to:"
                style: TextStyle(fontSize: 18, color: Colors.black),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Re-using your infoRow helper widget.
              infoRow(Icons.mic,
                  "מיקרופון לפקודות קוליות"), // "Microphone for voice commands"
              infoRow(Icons.location_on,
                  "מיקום לשירותים שימושיים"), // "Location for useful services"
              infoRow(Icons.notifications,
                  "התראות שיסייעו לך"), // "Notifications to help you"

              const Spacer(), // This pushes the button to the bottom.

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => _continue(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    // --- FIX #2: Corrected the typo in the class name ---
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "לְהַמשִׁיך", // "Continue"
                    style: TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for displaying permission information rows.
  Widget infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blue, size: 28),
          const SizedBox(width: 15),
          // Use Expanded to make sure text wraps gracefully on smaller screens.
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}
