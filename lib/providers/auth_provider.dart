import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  User? get user => _auth.currentUser;

  Future<bool> signInWithGoogle() async {
    try {
      isLoading = true;
      notifyListeners();

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user!;
      final ref = _firestore.collection("users").doc(user.uid);

      final snap = await ref.get();

      if (!snap.exists) {
        final code = _generateCode();
        await ref.set({
          "uid": user.uid,
          "name": user.displayName ?? "",
          "email": user.email ?? "",
          "points": 0,
          "totalEarnings": 0,
          "todayEarning": 0,
          "spinsToday": 0,
          "lastSpinDate": null,
          "referredBy": null,
          "myReferralCode": code,
          "upiId": "",
          "lastLoginDate": Timestamp.now(),
        });

        await _firestore
            .collection("referralCodes")
            .doc(code)
            .set({"uid": user.uid});
      }

      return true;
    } catch (e) {
      debugPrint(e.toString());
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _generateCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
