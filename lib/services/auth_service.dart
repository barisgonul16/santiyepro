import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'storage_service.dart';
import 'dart:convert';


import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart' as official;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart' as gsas;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final official.GoogleSignIn _googleSignIn = official.GoogleSignIn(
    scopes: ['email'],
    clientId: Platform.isWindows ? '739991426228-ve86hr43nqfa35pnvv4k8hpcsfu43peg.apps.googleusercontent.com' : null,
  );

  // Windows için statik instance (çünkü paket tekrar ilklendirmeyi sevmiyor)
  static gsas.GoogleSignIn? _gsasInstance;
  gsas.GoogleSignIn get _googleSignInWindows {
    _gsasInstance ??= gsas.GoogleSignIn(
      params: gsas.GoogleSignInParams(
        clientId: '739991426228-ve86hr43nqfa35pnvv4k8hpcsfu43peg.apps.googleusercontent.com',
        clientSecret: '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',
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
      print("Sign in error: $e");
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
      print("Register error: $e");
      return null;
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    print("LOG: signInWithGoogle started");
    String? accessToken;
    String? idToken;

    try {
      if (Platform.isWindows) {
        print("LOG: Windows platform detected, forcing fresh session...");
        try {
          // Önemli: Eski/Süresi dolmuş tokenları temizlemek için önce çıkış yapıyoruz
          try {
            print("LOG: Clearing cache...");
            await _googleSignInWindows.signOut();
          } catch (_) {}

          print("LOG: googleSignInWindows.signIn() - BROWSER SHOULD OPEN...");
          final response = await _googleSignInWindows.signIn().timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception("Tarayıcı açma süreci zaman aşımına uğradı.");
            },
          );
          
          if (response == null) {
            print("LOG: User cancelled sign-in");
            return null;
          }
          accessToken = response.accessToken;
          idToken = response.idToken;
          print("LOG: Tokens received successfully");

          // --- TEŞHİS: TOKEN AYRIŞTIRMA ---
          try {
            final parts = idToken!.split('.');
            if (parts.length > 1) {
              final payload = parts[1];
              final String decoded = utf8.decode(base64Url.decode(base64Url.normalize(payload)));
              print("---------------------------------------");
              print("LOG: ID TOKEN İÇERİĞİ (KONTROL EDİN):");
              print(decoded);
              print("---------------------------------------");
            }
          } catch (e) {
            print("LOG: Token ayrıştırma hatası: $e");
          }
        } catch (e) {
          print("LOG: Windows sign-in error: $e");
          rethrow;
        }
      } else {
        print("LOG: Platform is not Windows, using official GoogleSignIn");
        final official.GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final official.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        accessToken = googleAuth.accessToken;
        idToken = googleAuth.idToken;
      }

      if (idToken == null) {
        print("LOG: Error - idToken is null");
        return null;
      }

      print("LOG: Diagnostic - Firebase Project: ${_auth.app.options.projectId}");
      print("LOG: Diagnostic - API Key: ${_auth.app.options.apiKey}");

      print("LOG: Final signing in to Firebase...");
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      print("LOG: Firebase sign-in successful: ${result.user?.email}");
      return result.user;
    } catch (e, stack) {
      print("LOG: Final sign-in error: $e");
      print("LOG: Stacktrace: $stack");
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      if (Platform.isWindows) {
        // For Windows, the gsas.GoogleSignIn instance is local to signInWithGoogle,
        // so we can't directly sign out from it here.
        // A new instance would be needed if sign-out is required specifically for gsas.
        // For now, we rely on Firebase signOut to clear auth state.
        print("LOG: Windows platform, no direct gsas.GoogleSignIn signOut from here.");
      } else {
        // Initialize GoogleSignIn locally for sign out if it was used
        final official.GoogleSignIn googleSignIn = official.GoogleSignIn(scopes: ['email']);
        if (await googleSignIn.isSignedIn()) {
          try {
            await googleSignIn.signOut();
            print("LOG: official.GoogleSignIn signed out.");
          } catch (e) {
            print("Google sign out error: $e");
          }
        }
      }
    } catch (e) {
        print("Google sign out error: $e");
    }

    // Clear local data on sign out
    try {
      await StorageService().clearLocalData();
    } catch (e) {
      print("Clear local data error: $e");
    }

    try {
      await _auth.signOut();
      print("LOG: Firebase signed out.");
    } catch (e) {
      print("Firebase sign out error: $e");
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
      print("Update name error: $e");
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
      print("Update extra info error: $e");
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
      print("Get user data error: $e");
      return null;
    }
  }

  // Update Password
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      return true;
    } catch (e) {
      print("Update password error: $e");
      return false;
    }
  }

  // Update Email
  Future<bool> updateEmail(String newEmail) async {
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
      return true;
    } catch (e) {
      print("Update email error: $e");
      return false;
    }
  }

  // Şifre Sıfırlama E-postası Gönder
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
