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

  Future<void> logOut() async {
    try {
      await GoogleSignIn().signOut(); // Sign out from GoogleSignIn
      await FirebaseAuth.instance.signOut(); // Sign out from FirebaseAuth
    } catch (e) {
      e.log();
    }
  }

  Future<LoginState> loginWithGoogle() async {
    try {
      // Create an instance of GoogleSignIn with the specified scopes
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId:
            '141321526342-v3pp5gdojfb9f2meeclha0lj0jv7qh16.apps.googleusercontent.com',
        scopes: ['email'],
      );

      final signInAccount = await googleSignIn.signIn();

      if (signInAccount == null) {
        log('Google Login: User cancelled sign in');
        return LoginState.idle;
      }

      final googleAuth = await signInAccount.authentication;
      log('Google Auth Tokens: idToken=${googleAuth.idToken != null}, accessToken=${googleAuth.accessToken != null}');

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        log('Google Login Error: Both tokens are null');
        return LoginState.error;
      }

      // Create OAuth credentials using the access token and ID token
      final oAuthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
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
