import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'package:trafficpulse/components/message_screen.dart';
import 'package:uuid/uuid.dart';

class NotificationServices {
  //initialising firebase message plugin
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  
  //initialising firebase message plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  //function to initialise flutter local notification plugin to show notifications for android when app is active
  void initLocalNotifications(
      BuildContext context, RemoteMessage message) async {
    var androidInitializationSettings =
        const AndroidInitializationSettings('@mipmap/ic_launcher');
    var iosInitializationSettings = const DarwinInitializationSettings();

    var initializationSetting = InitializationSettings(
        android: androidInitializationSettings, iOS: iosInitializationSettings);

    await _flutterLocalNotificationsPlugin.initialize(initializationSetting,
        onDidReceiveNotificationResponse: (payload) {
      // handle interaction when app is active for android
      handleMessage(context, message);
    });
  }

  void firebaseInit(BuildContext context) {
    FirebaseMessaging.onMessage.listen((message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification!.android;

      if (kDebugMode) {
        print("notifications title:${notification!.title}");
        print("notifications body:${notification.body}");
        print('count:${android!.count}');
        print('data:${message.data.toString()}');
      }

      if (Platform.isIOS) {
        forgroundMessage();
      }

      if (Platform.isAndroid) {
        initLocalNotifications(context, message);
        showNotification(message);
      }
      
    });
  }

  void requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('user granted permission');
      }
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      if (kDebugMode) {
        print('user granted provisional permission');
      }
    } else {
      //appsetting.AppSettings.openNotificationSettings();
      if (kDebugMode) {
        print('user denied permission');
      }
    }
  }

  // Broadcast notification to all users
  Future<void> broadcastNotification(String title, String body) async {
    const String serverKey =
        '<YOUR_SERVER_KEY>'; // Replace with your Firebase Server Key.
    final Uri url = Uri.parse('https://fcm.googleapis.com/fcm/send');

    final Map<String, dynamic> notificationData = {
      "to": "/topics/all_users", // Targeting all users subscribed to this topic
      "notification": {
        "title": title,
        "body": body,
      },
      "priority": "high"
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(notificationData),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Notification sent successfully');
        }
      } else {
        if (kDebugMode) {
          print('Failed to send notification: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notification: $e');
      }
    }
  }

  //function to get device token on which we will send the notifications
  Future<String?> getDeviceToken() async {
    try {
      String? token = await messaging.getToken();
      if (token == null) {
        if (kDebugMode) print("Token retrieval failed.");
      } else {
        if (kDebugMode) print("Device Token: $token");
      }
      return token;
    } catch (e) {
      if (kDebugMode) print("Error getting device token: $e");
      return null;
    }
  }

  void isTokenRefresh() async {
    messaging.onTokenRefresh.listen((event) {
      event.toString();
      if (kDebugMode) {
        print('refresh');
      }
    });
  }

  //handle tap on notification when app is in background or terminated
  Future<void> setupInteractMessage(BuildContext context) async {
    // when app is terminated
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      handleMessage(context, initialMessage);
    }

    //when app ins background
    FirebaseMessaging.onMessageOpenedApp.listen((event) {
      handleMessage(context, event);
    });
  }

  void handleMessage(BuildContext context, RemoteMessage message) {
    if (message.data['type'] == 'msj') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MessageScreen(
                    id: message.data['id'],
                  )));
    }
  }

  Future forgroundMessage() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> saveDeviceToken(String userId) async {
    try {
      String? token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': token});

        // Schedule a daily notification after saving the token
        scheduleDailyNotification();
        if (kDebugMode) {
          print('FCM Token saved and daily notification scheduled.');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error saving FCM Token: $e');
    }
  }

Future<void> showNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  const androidDetails = AndroidNotificationDetails(
    'default_channel',
    'Default Channel',
    channelDescription: 'This is a test channel for notifications',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  await _flutterLocalNotificationsPlugin.show(
    message.hashCode,
    notification.title ?? "No Title",
    notification.body ?? "No Body",
    const NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails()),
  );
}


  Future<void> scheduleDailyNotification() async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Daily Reminder',
      'Open the app to catch more Pokémon!',
      _nextInstanceOf(8, 0), // 8:00 AM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Reminder',
          channelDescription: 'Reminder to use the app daily',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
  



}
void saveDeviceTokenWithRandomUserId(NotificationServices notificationServices) async {
  var uuid = const Uuid();
  String randomUserId = uuid.v4(); // Generate a random UUID

  // Save the token with the randomly generated user ID
  await notificationServices.saveDeviceToken(randomUserId);

  print('Random User ID assigned: $randomUserId');
}