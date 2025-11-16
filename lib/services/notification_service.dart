import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/main_conversation_screen.dart';
import '../screens/incoming_call_screen.dart';
import '../main.dart'; // for navigatorKey

/// Channel / notification ids
const String _incomingCallChannelId = 'memora_incoming_call_channel';
const String _incomingCallChannelName = 'Memora Incoming Calls';
const String _incomingCallChannelDescription =
    'High priority incoming-call style notifications for Memora';

const int _incomingCallNotificationId = 1001;

/// Android action ids
const String _answerActionId = 'ANSWER_ACTION';
const String _declineActionId = 'DECLINE_ACTION';

/// TOP-LEVEL background handler for FCM.
///
/// Must be a top-level or static function and annotated as entry point so
/// it is kept in AOT.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotificationService] TOP-LEVEL BG HANDLER START');
  debugPrint(
      '[NotificationService] [BG] messageId: ${message.messageId ?? "null"}');
  debugPrint(
      '[NotificationService] [BG] raw data: ${message.data.isEmpty ? "{}" : message.data.toString()}');
  debugPrint(
      '[NotificationService] [BG] notification: ${message.notification}');

  await Firebase.initializeApp();
  debugPrint('[NotificationService] [BG] Firebase.initializeApp() done');

  await NotificationService.instance._ensureLocalNotificationsInitialized();
  debugPrint(
      '[NotificationService] [BG] Local notifications plugin initialized');

  // Treat this as "background" presentation source
  await NotificationService.instance
      ._handleRemoteMessage(message, source: 'background');

  debugPrint('[NotificationService] TOP-LEVEL BG HANDLER END');
}

/// TOP-LEVEL background tap handler for local notifications.
///
/// This is required by flutter_local_notifications for
/// onDidReceiveBackgroundNotificationResponse.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Just delegate to the instance method
  NotificationService.instance.handleNotificationResponse(response);
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('[NotificationService] initialize() called');

    await _ensureLocalNotificationsInitialized();

    // Attach foreground listeners
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        debugPrint(
            '[NotificationService] onMessage (foreground FCM) received: ${message.messageId}');
        await _handleRemoteMessage(message, source: 'foreground');
      },
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) async {
        debugPrint(
            '[NotificationService] onMessageOpenedApp (tap from system tray) for messageId=${message.messageId}');
        await _handleRemoteMessage(message, source: 'opened_app');
      },
    );

    // Handle the case where the app was launched from a terminated state
    // by tapping on a notification.
    final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMsg != null) {
      debugPrint(
          '[NotificationService] getInitialMessage() returned a message. Handling as opened_app.');
      await _handleRemoteMessage(initialMsg, source: 'opened_app');
    } else {
      debugPrint(
          '[NotificationService] getInitialMessage() returned null (no launch-from-notification)');
    }

    _initialized = true;
  }

  Future<void> _ensureLocalNotificationsInitialized() async {
    // Android initialization
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInitSettings);

    await _localNotificationsPlugin.initialize(
      initSettings,
      // Foreground / already-running case: we can use an instance method.
      onDidReceiveNotificationResponse: handleNotificationResponse,
      // Background tap: MUST be top-level or static.
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    debugPrint('[NotificationService] Local notifications plugin initialized');

    // Create the incoming-call notification channel.
    const AndroidNotificationChannel incomingCallChannel =
        AndroidNotificationChannel(
      _incomingCallChannelId,
      _incomingCallChannelName,
      description: _incomingCallChannelDescription,
      importance: Importance.max,
      playSound: true,
      showBadge: true,
    );

    final androidPlugin =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(incomingCallChannel);
  }

  // ---------------------------------------------------------------------------
  // Handling incoming FCM
  // ---------------------------------------------------------------------------

  Future<void> _handleRemoteMessage(RemoteMessage message,
      {required String source}) async {
    debugPrint('[NotificationService] _handleRemoteMessage() from $source');

    final data = message.data;
    final notification = message.notification;

    debugPrint('[NotificationService]   data: $data');
    debugPrint('[NotificationService]   notification: $notification');

    // Extract common fields
    final String? type = data['type'] as String?;
    final String title =
        data['caller_name'] as String? ?? notification?.title ?? 'Memora';
    final String body = data['description'] as String? ??
        notification?.body ??
        'You have a new message from Memora.';
    final String? callerName = data['caller_name'] as String? ?? title;
    final String? callId = data['call_id'] as String?;
    final String? userPhone = data['user_phone'] as String?;

    debugPrint(
        '[NotificationService]   computed title="$title" body="$body" type="$type" callerName="$callerName" callId="$callId" userPhone="$userPhone"');

    final bool isIncomingCall = type == 'incoming_call' && callId != null;
    debugPrint('[NotificationService]   isIncomingCall=$isIncomingCall');

    if (isIncomingCall) {
      debugPrint(
          '[NotificationService]   Showing INCOMING CALL notification: callerName="$callerName", callId="$callId"');
      await _showIncomingCallNotification(
        callerName: callerName ?? 'Memora',
        callId: callId,
        initialMessage: body,
        userPhone: userPhone,
        presentationSource: source,
      );
    } else {
      // Fallback for generic notifications if you add them in the future
      await _showSimpleNotification(title: title, body: body, data: data);
    }
  }

  // ---------------------------------------------------------------------------
  // Showing notifications
  // ---------------------------------------------------------------------------

  Future<void> _showIncomingCallNotification({
    required String callerName,
    required String callId,
    required String initialMessage,
    required String? userPhone,
    required String presentationSource,
  }) async {
    debugPrint(
        '[NotificationService] _showIncomingCallNotification(): callerName="$callerName", callId="$callId", initialMessage="$initialMessage", userPhone="$userPhone"');

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _incomingCallChannelId,
      _incomingCallChannelName,
      channelDescription: _incomingCallChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      fullScreenIntent:
          true, // important for lockscreen / heads-up call-like UI
      ongoing: true,
      autoCancel: false,
      playSound: true,
      ticker: 'Memora incoming call',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _answerActionId,
          'Answer',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _declineActionId,
          'Decline',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final payload = jsonEncode({
      'type': 'incoming_call',
      'callerName': callerName,
      'callId': callId,
      'initialMessage': initialMessage,
      'userPhone': userPhone,
      // how the message was presented (foreground / background / opened_app)
      'presentationSource': presentationSource,
    });

    await _localNotificationsPlugin.show(
      _incomingCallNotificationId,
      callerName,
      initialMessage,
      details,
      payload: payload,
    );

    debugPrint(
        '[NotificationService] _showIncomingCallNotification(): show() completed');
  }

  Future<void> _showSimpleNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'memora_default_channel',
      'Memora Notifications',
      channelDescription: 'General notifications from Memora',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final payload = jsonEncode({
      'type': 'generic',
      'title': title,
      'body': body,
      if (data != null) 'data': data,
    });

    await _localNotificationsPlugin.show(
      0,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ---------------------------------------------------------------------------
  // Notification response handling
  // ---------------------------------------------------------------------------

  /// Called for **foreground / active** notifications,
  /// and also via [notificationTapBackground] when the app is brought back
  /// from the background by tapping on a notification.
  void handleNotificationResponse(NotificationResponse response) {
    debugPrint('[NotificationService] handleNotificationResponse() called');
    debugPrint('[NotificationService]   actionId: ${response.actionId}');
    debugPrint('[NotificationService]   input: ${response.input}');
    debugPrint(
        '[NotificationService]   payload: ${response.payload ?? "null"}');

    if (response.payload == null) {
      return;
    }

    final Map<String, dynamic> data =
        jsonDecode(response.payload!) as Map<String, dynamic>;
    final String? type = data['type'] as String?;
    debugPrint('[NotificationService]   decoded type="$type" data=$data');

    if (type == 'incoming_call') {
      _handleIncomingCallNotificationResponse(response, data);
    } else {
      // generic notifications, if any, could be handled here
    }
  }

  void _handleIncomingCallNotificationResponse(
    NotificationResponse response,
    Map<String, dynamic> data,
  ) {
    final String? callerName = data['callerName'] as String?;
    final String? callId = data['callId'] as String?;
    final String? initialMessage = data['initialMessage'] as String?;
    final String? userPhone = data['userPhone'] as String?;
    final String? presentationSource = data['presentationSource'] as String?;
    final String actionId = response.actionId ?? '';

    if (callId == null) {
      debugPrint(
          '[NotificationService]   Incoming call payload missing callId. Ignoring.');
      return;
    }

    final cameFromBackground = presentationSource == 'background';

    if (actionId == _declineActionId) {
      // User explicitly declined the call
      debugPrint(
          '[NotificationService]   DECLINE action. Staying where we are.');
      cancelIncomingCallNotification();
      // Optionally notify server later.
      return;
    }

    // ANSWER or body tap
    debugPrint(
        '[NotificationService]   ANSWER (or body tap). presentationSource="$presentationSource"');

    final String safeInitialMessage =
        initialMessage ?? 'Hello, how can I help?';

    if (cameFromBackground) {
      // PHONE LOCKED / APP IN BACKGROUND CASE
      // → open IncomingCallScreen first, and let it handle answerCall + navigation
      debugPrint(
          '[NotificationService]   Navigating to IncomingCallScreen with callerName="$callerName", callId="$callId"');
      cancelIncomingCallNotification();

      _navigateToIncomingCallScreen(
        callerName: callerName ?? 'Memora',
        callId: callId,
        initialMessage: safeInitialMessage,
      );
    } else {
      // PHONE IN USE (FOREGROUND / OPENED_APP)
      // → go directly to MainConversationScreen with the text on top.
      debugPrint(
          '[NotificationService]   Navigating directly to MainConversationScreen with userPhone="$userPhone", callId="$callId"');

      cancelIncomingCallNotification();

      if (userPhone == null || userPhone.isEmpty) {
        debugPrint(
            '[NotificationService]   No userPhone in payload; cannot navigate to MainConversationScreen.');
        return;
      }

      _navigateToMainConversationScreen(
        userPhone: userPhone,
        initialMessage: safeInitialMessage,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  void _navigateToIncomingCallScreen({
    required String callerName,
    required String callId,
    required String initialMessage,
  }) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint(
          '[NotificationService] navigatorKey.currentState is null, cannot navigate to IncomingCallScreen.');
      return;
    }

    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callerName: callerName,
          callId: callId,
          initialMessage: initialMessage,
        ),
      ),
      (route) => false,
    );
  }

  void _navigateToMainConversationScreen({
    required String userPhone,
    required String initialMessage,
  }) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint(
          '[NotificationService] navigatorKey.currentState is null, cannot navigate to MainConversationScreen.');
      return;
    }

    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainConversationScreen(
          userPhone: userPhone,
          initialMessage: initialMessage,
        ),
      ),
      (route) => false,
    );
  }

  // ---------------------------------------------------------------------------
  // Public util
  // ---------------------------------------------------------------------------

  static Future<void> cancelIncomingCallNotification() async {
    await instance._localNotificationsPlugin
        .cancel(_incomingCallNotificationId);
  }
}
