import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotifications {
  PushNotifications._();

  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<String>? _tokenSub;

  static Future<void> start() async {
    if (kIsWeb) return;
    await FirebaseMessaging.instance.requestPermission();
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return;
      unawaited(_registerCurrentToken(user.uid));
    });
    _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      unawaited(_saveToken(uid, token));
    });
  }

  static Future<void> _registerCurrentToken(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _saveToken(uid, token);
  }

  static Future<void> _saveToken(String uid, String token) async {
    final id = sha256.convert(utf8.encode(token)).toString();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(id)
        .set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
