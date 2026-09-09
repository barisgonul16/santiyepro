import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';
import 'storage_service.dart';
import 'dart:convert';


import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart' as official;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart' as gsas;
import 'app_log.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final official.GoogleSignIn _googleSignIn = official.GoogleSignIn(
    scopes: ['email'],
    clientId: Platform.isWindows && AppConfig.googleClientId.isNotEmpty
        ? AppConfig.googleClientId
        : null,
  );

  // Windows için statik instance (çünkü paket tekrar ilklendirmeyi sevmiyor)
  static gsas.GoogleSignIn? _gsasInstance;
  gsas.GoogleSignIn get _googleSignInWindows {
    _gsasInstance ??= gsas.GoogleSignIn(
      params: gsas.GoogleSignInParams(
        clientId: AppConfig.googleClientId,
        clientSecret: AppConfig.googleClientSecret,
        redirectPort: 8890,
        scopes: ['email', 'profile'],
      ),
    );
    return _gsasInstance!;
  }

  // Auth change user stream
  Stream<User?> get user {
    return _auth.authStateChanges();
  }

  // Sign in with email & password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      appLog("Sign in error: $e");
      return null;
    }
  }

  // Register with email & password + Details
  Future<User?> registerWithEmailDetail(String email, String password, String name, DateTime? birthDate) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      if (user != null) {
        // Update display name in Firebase Auth
        await user.updateDisplayName(name);
        
        // Save extra data to Firestore
        await _db.collection('users').doc(user.uid).set({
          'name': name,
          'birthDate': birthDate?.toIso8601String(),
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return user;
    } catch (e) {
      appLog("Register error: $e");
      return null;
    }
  }  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    appLog("LOG: signInWithGoogle started");
    String? accessToken;
    String? idToken;

    try {
      if (Platform.isWindows) {
        appLog("LOG: Windows platform detected, forcing fresh session...");
        try {
          // Önemli: Eski/Süresi dolmuş tokenları temizlemek için önce çıkış yapıyoruz
          try {
            appLog("LOG: Clearing cache...");
            await _googleSignInWindows.signOut();
          } catch (_) {}

          appLog("LOG: googleSignInWindows.signIn() - BROWSER SHOULD OPEN...");
          final response = await _googleSignInWindows.signIn().timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception("Tarayıcı açma süreci zaman aşımına uğradı.");
            },
          );
          
          if (response == null) {
            appLog("LOG: User cancelled sign-in");
            return null;
          }
          accessToken = response.accessToken;
          idToken = response.idToken;
          appLog("LOG: Tokens received successfully");

          // Not: ID token içeriğini çözüp loglayan teşhis bloğu kaldırıldı —
          // kullanıcının e-postası ve kimlik bilgileri log'a yazılıyordu.
        } catch (e) {
          appLog("LOG: Windows sign-in error: $e");
          rethrow;
        }
      } else {
        appLog("LOG: Platform is not Windows, using official GoogleSignIn");
        final official.GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final official.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        accessToken = googleAuth.accessToken;
        idToken = googleAuth.idToken;
      }

      if (idToken == null) {
        appLog("LOG: Error - idToken is null");
        return null;
      }

      appLog("LOG: Final signing in to Firebase...");
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      appLog("LOG: Firebase sign-in successful: ${result.user?.email}");
      return result.user;
    } catch (e, stack) {
      appLog("LOG: Final sign-in error: $e");
      appLog("LOG: Stacktrace: $stack");
      rethrow;
    }
  }

  // Sign in with Google Silently
  Future<User?> signInWithGoogleSilently() async {
    appLog("LOG: signInWithGoogleSilently started");
    String? accessToken;
    String? idToken;

    try {
      if (Platform.isWindows) {
        appLog("LOG: Windows platform detected, attempting silent sign-in...");
        dynamic response;
        try {
          response = await _googleSignInWindows.signInOffline();
        } catch (e) {
          appLog("LOG: Windows signInOffline error: $e");
        }

        if (response == null) {
          appLog("LOG: No cached credentials found for Windows");
          return null;
        }

        accessToken = response.accessToken;
        idToken = response.idToken;
      } else {
        appLog("LOG: Mobile/Web platform, trying official signInSilently");
        final official.GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
        if (googleUser == null) return null;

        final official.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        accessToken = googleAuth.accessToken;
        idToken = googleAuth.idToken;
      }

      if (idToken == null) {
        appLog("LOG: Silent sign-in failed: idToken is null");
        return null;
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      appLog("LOG: Firebase silent sign-in successful: ${result.user?.email}");
      return result.user;
    } catch (e) {
      appLog("LOG: Silent sign-in error: $e");
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      if (Platform.isWindows) {
        try {
          await _googleSignInWindows.signOut();
          appLog("LOG: googleSignInWindows signed out.");
        } catch (e) {
          appLog("googleSignInWindows sign out error: $e");
        }
      } else {
        // Initialize GoogleSignIn locally for sign out if it was used
        final official.GoogleSignIn googleSignIn = official.GoogleSignIn(scopes: ['email']);
        if (await googleSignIn.isSignedIn()) {
          try {
            await googleSignIn.signOut();
            appLog("LOG: official.GoogleSignIn signed out.");
          } catch (e) {
            appLog("Google sign out error: $e");
          }
        }
      }
    } catch (e) {
      appLog("Google sign out error: $e");
    }

    // Clear local data on sign out
    try {
      await StorageService().clearLocalData();
    } catch (e) {
      appLog("Clear local data error: $e");
    }

    try {
      await _auth.signOut();
      appLog("LOG: Firebase signed out.");
    } catch (e) {
      appLog("Firebase sign out error: $e");
    }
  }

  // Update Display Name
  Future<bool> updateDisplayName(String name) async {
    try {
      await _auth.currentUser?.updateDisplayName(name);
      // Also update in Firestore
      final user = _auth.currentUser;
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'name': name,
        }, SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      appLog("Update name error: $e");
      return false;
    }
  }

  // Update Extra Info (Birth Date)
  Future<bool> updateExtraInfo(DateTime birthDate) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'birthDate': birthDate.toIso8601String(),
        }, SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      appLog("Update extra info error: $e");
      return false;
    }
  }

  // Get User Data from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      appLog("Get user data error: $e");
      return null;
    }
  }

  // Update Password
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      return true;
    } catch (e) {
      appLog("Update password error: $e");
      return false;
    }
  }

  // Update Email
  Future<bool> updateEmail(String newEmail) async {
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
      return true;
    } catch (e) {
      appLog("Update email error: $e");
      return false;
    }
  }

  // Şifre Sıfırlama E-postası Gönder
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
