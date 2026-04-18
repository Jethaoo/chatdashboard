import 'package:firebase_auth/firebase_auth.dart';

/// Maps [FirebaseAuthException] codes to short, user-facing copy.
String messageForAuthException(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address does not look valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email. Try signing in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this project.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      case 'invalid-display-name':
        return 'Enter a valid display name.';
      case 'requires-recent-login':
        return 'Please sign in again before making this change.';
      default:
        break;
    }
  }
  return 'Something went wrong. Please try again.';
}
