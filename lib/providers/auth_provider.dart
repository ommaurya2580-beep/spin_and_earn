import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  
  User? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<User?>? _authSub;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authSub = _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final userCredential = await _authService.signInWithGoogle();
      if (userCredential == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final user = userCredential.user;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final now = DateTime.now();

      // One-time check at login only (UI must use real-time stream).
      final existingUser = await _firestoreService.getUser(user.uid);

      if (existingUser == null) {
        // Create new user
        String referralCode;
        bool codeExists = true;
        int attempts = 0;
        
        // Generate unique referral code
        do {
          referralCode = _firestoreService.generateReferralCode();
          codeExists = await _firestoreService.checkReferralCodeExists(referralCode);
          attempts++;
          if (attempts > 10) {
            // Fallback: use UID substring
            referralCode = user.uid.substring(0, 6).toUpperCase();
            break;
          }
        } while (codeExists);

        final newUser = UserModel(
          uid: user.uid,
          name: user.displayName ?? 'User',
          email: user.email ?? '',
          myReferralCode: referralCode,
          createdAt: now,
          lastLoginDate: now,
        );

        await _firestoreService.ensureUserInitialized(newUser: newUser);
      } else {
        // Existing user: apply lastLogin + daily bonus safely.
      }

      await _firestoreService.applyLoginAndDailyBonus(user.uid);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      await _authService.signOut();
      _user = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
