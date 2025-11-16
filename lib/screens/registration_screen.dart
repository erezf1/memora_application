import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import 'main_conversation_screen.dart';
import '../services/user_profile_service.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedGender = 'male';
  String _selectedLanguage = 'en';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Full Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: InputDecoration(labelText: 'Gender'),
                  items: ['male', 'female', 'other'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedGender = newValue!;
                    });
                  },
                ),
                DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  decoration: InputDecoration(labelText: 'Language'),
                  items: ['en', 'he'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedLanguage = newValue!;
                    });
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _register,
                  child: Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _register() async {
    print("[Flow] RegistrationScreen: 'Register' pressed.");
    if (_formKey.currentState!.validate()) {
      // Get FCM token
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        print('Failed to get FCM token');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Could not get notification token. Please try again.')),
        );
        return;
      }

      print(
          "[Flow] RegistrationScreen: Got FCM Token. Preparing user profile...");
      // Normalize phone number
      String normalizedPhone = '972' + _phoneController.text.substring(1);

      // Create user profile with 'registering' status
      UserProfile userProfile = UserProfile(
        name: _nameController.text,
        gender: _selectedGender,
        phone: normalizedPhone,
        language: _selectedLanguage,
        status: 'registering',
      );
      print(
          "[Flow] RegistrationScreen: Saving 'registering' profile locally...");
      await UserProfileService.saveProfile(userProfile);

      // Log the data being sent
      final userData = {
        ...userProfile.toJson(),
        'fcm_token': fcmToken,
      };
      print('Attempting to register user with data: ${jsonEncode(userData)}');

      try {
        print("[Flow] RegistrationScreen: Calling backend registerUser API...");
        final registrationData =
            await ApiService().registerUser(userProfile, fcmToken);

        // Update profile to 'active'
        final activeProfile = userProfile.copyWith(status: 'active');
        print(
            "[Flow] RegistrationScreen: Backend registration successful. Saving 'active' profile locally...");
        await UserProfileService.saveProfile(activeProfile);

        print('Registration successful!');

        final String initialMessage = registrationData['initial_message'] ??
            "Welcome! How can I help you?";

        print('[Flow] Preparing to navigate to MainConversationScreen...');
        // Use `mounted` check to ensure the widget is still in the tree before navigating.
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => MainConversationScreen(
                  userPhone: normalizedPhone, initialMessage: initialMessage)),
        );
        print('[Flow] Navigation command sent.');
      } catch (e) {
        print('Registration failed with error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    }
  }
}
