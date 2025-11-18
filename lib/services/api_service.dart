// lib/services/api_service.dart

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';

class ApiService {
  // === CONFIGURATION ===
  static const String _baseUrl = 'http://memora.aigents.co.il';
  static const Duration _timeoutDuration = Duration(seconds: 20);

  // === PRIVATE HELPER METHOD ===
  static http.Response _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      throw Exception(
        'API Error: Status ${response.statusCode}, Body: ${response.body}',
      );
    }
  }

  // === PUBLIC API METHODS ===

  Future<Map<String, dynamic>> registerUser(
      UserProfile profile, String fcmToken) async {
    final url = Uri.parse('$_baseUrl/register-user');
    final requestBody = profile.toJson();
    requestBody['fcm_token'] = fcmToken;
    if (requestBody.containsKey('phone')) {
      requestBody['user_phone'] = requestBody['phone'];
      requestBody.remove('phone');
    }

    print('Sending POST request to: $url');
    print('With body: ${json.encode(requestBody)}');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: json.encode(requestBody),
          )
          .timeout(_timeoutDuration);

      final handledResponse = _handleResponse(response);
      return json.decode(utf8.decode(handledResponse.bodyBytes));
    } catch (e) {
      print('Error during user registration: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyUser(
      UserProfile profile, String fcmToken) async {
    final url = Uri.parse('$_baseUrl/initiate-session');
    final requestBody = profile.toJson();
    requestBody['fcm_token'] = fcmToken;
    if (requestBody.containsKey('phone')) {
      requestBody['user_phone'] = requestBody['phone'];
      requestBody.remove('phone');
    }

    print('Sending POST request to: $url');
    print('With body: ${json.encode(requestBody)}');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: json.encode(requestBody),
          )
          .timeout(_timeoutDuration);

      final handledResponse = _handleResponse(response);
      return json.decode(utf8.decode(handledResponse.bodyBytes));
    } catch (e) {
      print('Error during user verification: $e');
      rethrow;
    }
  }

  Future<String> sendMessage(String userPhone, String message) async {
    final url = Uri.parse('$_baseUrl/voice/process');
    print('Sending POST request to: $url');
    // --- NEW: Log the content of the message being sent ---
    print('Sending message content: $message');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: json.encode({
              'user_id': userPhone,
              'message': message,
              'audio_data': null,
            }),
          )
          .timeout(_timeoutDuration);

      final handledResponse = _handleResponse(response);
      String reply = utf8.decode(handledResponse.bodyBytes);

      // --- NEW: Log the content of the reply received from the backend ---
      print('Received reply content: $reply');

      if (reply.startsWith('"') && reply.endsWith('"')) {
        reply = reply.substring(1, reply.length - 1);
      }

      if (reply.isNotEmpty) {
        return reply;
      } else {
        throw Exception(
            'API Error: Received an empty response from /voice/process.');
      }
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // --- NEW DISCONNECT METHOD ---
  Future<void> disconnect(String userPhone) async {
    final url = Uri.parse('$_baseUrl/disconnect');
    print('Sending POST request to: $url');

    try {
      // We don't need to wait long for this. If it fails, the app still closes.
      await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: json.encode({'user_phone': userPhone}),
          )
          .timeout(const Duration(seconds: 5));

      print('Disconnect message sent successfully for $userPhone.');
    } catch (e) {
      // We log the error but don't rethrow it, so the app can still close
      // even if the disconnect message fails to send (e.g., no network).
      print('Could not send disconnect message: $e');
    }
  }

  // --- NEW METHOD 1: answerCall ---
  /// Informs the backend that the user has answered a proactive "call".
  Future<Map<String, dynamic>> answerCall(String userPhone) async {
    final url = Uri.parse('$_baseUrl/voice/call-answered');
    final body = {'user_id': userPhone};
    print('Sending POST request to: $url with body: ${json.encode(body)}');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      final handledResponse = _handleResponse(response);
      print('Successfully sent call-answered (protocol endpoint 4).');
      // Decode and return the JSON body from the response.
      return json.decode(utf8.decode(handledResponse.bodyBytes));
    } catch (e) {
      print('Failed to send voice/call-answered: $e');
      rethrow; // Rethrow to let the UI know the call failed
    }
  }

  // --- NEW METHOD 2: declineCall ---
  /// Informs the backend that the user has declined a proactive "call".
  Future<void> declineCall(String userPhone) async {
    final url = Uri.parse('$_baseUrl/voice/call-declined');
    final body = {'user_id': userPhone};
    print('Sending POST request to: $url with body: ${json.encode(body)}');

    try {
      await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      print('Successfully sent call-declined (protocol endpoint 5).');
    } catch (e) {
      // We don't rethrow here, as the UI should close even if the decline message fails.
      print('Failed to send voice/call-declined: $e');
    }
  }
}
