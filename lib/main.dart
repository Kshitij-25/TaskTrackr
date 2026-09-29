import 'dart:developer' as devtools show log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/todo_app.dart';
import 'data/backend/notification_service.dart';
import 'firebase_options.dart';
import 'presentation/providers/theme_provider.dart';

extension Log on Object {
  void log() => devtools.log(toString());
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Each step is isolated: on iOS the native SDK may already have created the
  // default app from GoogleService-Info.plist, so initializeApp throws
  // duplicate-app — that must not skip persistence or notifications.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') debugPrint('Firebase init error: $e');
  }

  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firestore settings error: $e');
  }

  final prefs = await SharedPreferences.getInstance();

  // Don't block first frame on the permission prompt.
  await NotificationService().initialize().then((_) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }).catchError((Object e) {
    debugPrint('Notification init error: $e');
  });

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const TodoApp(),
  ));
}
