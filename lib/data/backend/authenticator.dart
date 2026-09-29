import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tasktrackr/main.dart';

import '../models/login_state.dart';

class Authenticator {
  const Authenticator();

  // Getter to retrieve the current user from FirebaseAuth
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Getter to retrieve the current user's ID
  String? get userId => currentUser?.uid;

  // Getter to check if a user is already logged in
  bool get isAlreadyLoggedIn => userId != null;

  // Getter to retrieve the display name of the current user, or an empty string if not available
  String get displayName => currentUser?.displayName ?? '';

  // Getter to retrieve the email of the current user, or null if not available
  String? get email => currentUser?.email;

  static const _serverClientId =
      '141321526342-v3pp5gdojfb9f2meeclha0lj0jv7qh16.apps.googleusercontent.com';

  // google_sign_in 7 is a singleton that must be initialised exactly once.
  static Future<void>? _gsiInit;
  Future<void> _ensureGoogleSignIn() => _gsiInit ??=
      GoogleSignIn.instance.initialize(serverClientId: _serverClientId);

  Future<void> logOut() async {
    try {
      await _ensureGoogleSignIn();
      await GoogleSignIn.instance.signOut(); // Sign out from GoogleSignIn
      await FirebaseAuth.instance.signOut(); // Sign out from FirebaseAuth
    } catch (e) {
      e.log();
    }
  }

  Future<LoginState> loginWithGoogle() async {
    try {
      await _ensureGoogleSignIn();

      final GoogleSignInAccount signInAccount;
      try {
        signInAccount =
            await GoogleSignIn.instance.authenticate(scopeHint: ['email']);
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          log('Google Login: User cancelled sign in');
          return LoginState.idle;
        }
        rethrow;
      }

      final googleAuth = signInAccount.authentication;
      log('Google Auth Tokens: idToken=${googleAuth.idToken != null}');

      if (googleAuth.idToken == null) {
        log('Google Login Error: idToken is null');
        return LoginState.error;
      }

      // Firebase only needs the ID token; v7 no longer returns an access
      // token from sign-in (that moved to the authorization client).
      final oAuthCredential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oAuthCredential);
      final user = userCredential.user;

      if (user != null) {
        log('Google Login Success: ${user.uid}');
        // Wait for Firestore to store user info before proceeding
        // This prevents race conditions where the home screen tries to fetch data
        // before the user document exists, which can trigger permission errors
        // if security rules depend on the user document.
        try {
          await _storeUserInFirestore(user);
        } catch (e) {
          log('Firestore storage error (continuing anyway): $e');
        }
        return LoginState.success;
      }
      return LoginState.error;
    } on FirebaseAuthException catch (e) {
      log('Firebase Auth Exception: ${e.code} - ${e.message}');
      return LoginState.error;
    } catch (e) {
      log('Detailed Login Error: $e');
      if (e.toString().contains('12500') || e.toString().contains('10')) {
        log('TIP: Error 10 or 12500 usually means your SHA-1 is missing in Firebase Console for Android.');
      }
      return LoginState.error;
    }
  }

  Future<void> _storeUserInFirestore(User user) async {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userSnapshot = await userDoc.get();

      if (!userSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      log('Error storing user in Firestore: $e');
      rethrow;
    }
  }

  Future<void> updateDisplayName(String newName) async {
    try {
      // Update FirebaseAuth
      await currentUser?.updateDisplayName(newName);

      // Update Firestore
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'displayName': newName});
      }
    } catch (e) {
      log('Error updating display name: $e');
      rethrow;
    }
  }

  /// Permanently deletes the account and everything stored for it:
  /// tasks, XP/habit sync data, profile and profile photo, then the Firebase
  /// Auth user. Required by Google Play for apps that let users sign up.
  ///
  /// Asks Google to confirm the account first, because Firebase only deletes
  /// users who signed in recently. Returns false if the user cancels that.
  Future<bool> deleteAccount() async {
    final user = currentUser;
    if (user == null) return false;
    final uid = user.uid;

    // 1. Fresh sign-in so user.delete() won't fail with requires-recent-login.
    await _ensureGoogleSignIn();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(scopeHint: ['email']);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: account.authentication.idToken),
    );

    // 2. Data. Tasks go in batches (Firestore caps a batch at 500 writes).
    final db = FirebaseFirestore.instance;
    final tasks =
        await db.collection('tasks').where('userId', isEqualTo: uid).get();
    for (var i = 0; i < tasks.docs.length; i += 400) {
      final batch = db.batch();
      for (final doc in tasks.docs.skip(i).take(400)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    final userDoc = db.collection('users').doc(uid);
    final momentum = await userDoc.collection('momentum').get();
    for (final doc in momentum.docs) {
      await doc.reference.delete();
    }
    await userDoc.delete();
    try {
      await FirebaseStorage.instance.ref('user_profiles/$uid.jpg').delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }

    // 3. The auth user itself, then drop the Google session.
    await user.delete();
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}
    return true;
  }

  Future<String> uploadProfilePicture(File file) async {
    try {
      if (userId == null) throw Exception('User not logged in');

      // Upload to Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_profiles')
          .child('$userId.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Update FirebaseAuth
      await currentUser?.updatePhotoURL(downloadUrl);

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'photoURL': downloadUrl});

      return downloadUrl;
    } catch (e) {
      log('Error uploading profile picture: $e');
      rethrow;
    }
  }

  Future<void> updateNotificationSettings(Map<String, dynamic> settings) async {
    try {
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'notificationSettings': settings});
      }
    } catch (e) {
      log('Error updating notification settings: $e');
      rethrow;
    }
  }
}
