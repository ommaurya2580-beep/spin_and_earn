import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class UserProvider extends ChangeNotifier {
  User? user;

  UserProvider() {
    // Initialize with current user if already logged in
    user = FirebaseAuth.instance.currentUser;
    // Listen for auth changes (logout, token expiration, etc.)
    FirebaseAuth.instance.authStateChanges().listen((User? u) {
      user = u;
      notifyListeners();
      if (u != null) {
        FirestoreService().createUserIfNotExists(u);
      }
    });
  }

  void setUser(User? u) {
    user = u;
    notifyListeners();
  }

  Future<void> handleLogin(User u) async {
    user = u;
    await FirestoreService().createUserIfNotExists(u);
    notifyListeners();
  }

  void clear() {
    user = null;
    notifyListeners();
  }
}
