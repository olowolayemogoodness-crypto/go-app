import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthError implements Exception {
  final String message;
  AuthError(this.message);
  @override
  String toString() => message;
}

/// Sign-in with GitHub or Google through Firebase Auth (same code on web, Android, iOS).
class AuthService {
  /// True when the user chose "try without an account" (anonymous session).
  static final ValueNotifier<bool> guest = ValueNotifier(false);

  static Future<void> _with(AuthProvider provider) async {
    final auth = FirebaseAuth.instance;
    try {
      if (kIsWeb) {
        await auth.signInWithPopup(provider);
      } else {
        await auth.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request' ||
          e.code == 'canceled' ||
          e.code == 'web-context-canceled') {
        return; // The user backed out; not an error.
      }
      if (e.code == 'operation-not-allowed') {
        throw AuthError('This sign-in method is not turned on yet in Firebase.');
      }
      throw AuthError(e.message ?? 'Sign-in failed. Please try again.');
    } catch (_) {
      throw AuthError('Sign-in failed. Check your connection and try again.');
    }
  }

  static Future<void> signInWithGitHub() {
    final p = GithubAuthProvider()..addScope('read:user');
    return _with(p);
  }

  static Future<void> signInWithGoogle() => _with(GoogleAuthProvider());

  static Future<void> continueAsGuest() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      guest.value = true;
    } on FirebaseAuthException catch (e) {
      throw AuthError(e.message ?? 'Could not start a guest session.');
    }
  }

  static Future<void> signOut() async {
    guest.value = false;
    await FirebaseAuth.instance.signOut();
  }
}
