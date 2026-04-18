import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _pendingProfileName;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      try {
        if (user != null) {
          await _fetchUserProfile(user);
        } else {
          _currentUser = null;
        }
      } catch (e, st) {
        debugPrint('AuthService authStateChanges: $e\n$st');
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  Future<void> _fetchUserProfile(User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      _currentUser = UserModel.fromMap(doc.data()!);
      return;
    }

    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      // Email/password accounts normally always have email; keep auth and router state consistent.
      await _auth.signOut();
      _currentUser = null;
      return;
    }

    _currentUser = UserModel(
      uid: user.uid,
      email: email,
      name: _pendingProfileName,
      role: 'customer',
    );
    await _firestore.collection('users').doc(user.uid).set(_currentUser!.toMap());
    _pendingProfileName = null;
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password, {required String name}) async {
    _pendingProfileName = name.trim();
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (_) {
      _pendingProfileName = null;
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updateProfileName(String name) async {
    final user = _currentUser;
    if (user == null) return;

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-display-name',
        message: 'Name cannot be empty.',
      );
    }

    await _firestore.collection('users').doc(user.uid).update({
      'name': trimmed,
    });

    _currentUser = UserModel(
      uid: user.uid,
      email: user.email,
      name: trimmed,
      role: user.role,
    );
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final firebaseUser = _auth.currentUser;
    final email = firebaseUser?.email ?? _currentUser?.email;
    if (firebaseUser == null || email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'Sign in again before changing your password.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await firebaseUser.reauthenticateWithCredential(credential);
    await firebaseUser.updatePassword(newPassword);
  }
}
