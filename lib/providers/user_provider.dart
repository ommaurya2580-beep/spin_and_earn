import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/withdrawal_request_model.dart';

class UserProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<UserModel?>? _userSub;
  String? _uid;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Bind provider lifecycle to current auth user.
  /// Called from a ProxyProvider in `main.dart`.
  void bindAuthUser(String? uid) {
    if (_uid == uid) return;
    _uid = uid;

    _userSub?.cancel();
    _userSub = null;
    _user = null;
    _error = null;

    if (uid == null) {
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _userSub = _firestoreService.getUserStream(uid).listen(
      (user) {
        _user = user;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestoreService.updateUser(uid, updates);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addPoints(String uid, int points) async {
    try {
      await _firestoreService.updateUser(uid, {
        'points': FieldValue.increment(points),
        'totalEarnings': FieldValue.increment(points),
        'todayEarning': FieldValue.increment(points),
      });
    } catch (e) {
      print('Error adding points: $e');
      rethrow;
    }
  }

  Future<void> useReferralCode(String uid, String code) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_user == null || _user!.referralUsed) {
        throw Exception('Referral code already used');
      }

      await _firestoreService.applyReferralCodeAndReward(
        currentUid: uid,
        code: code,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> spinAndEarn({required int rewardPoints, int maxSpinsPerDay = 5}) async {
    final uid = _uid;
    if (uid == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.applySpinReward(
        uid: uid,
        rewardPoints: rewardPoints,
        maxSpinsPerDay: maxSpinsPerDay,
      );
      await _firestoreService.saveSpinHistory(uid, rewardPoints, rewardPoints);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> requestWithdrawal({
    required String upiId,
    required int amountRupees,
    required int pointsUsed,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = WithdrawalRequestModel(
        id: '',
        uid: uid,
        upiId: upiId,
        amount: amountRupees,
        pointsUsed: pointsUsed,
        requestedAt: DateTime.now(),
      );

      await _firestoreService.createWithdrawalAndDeductPoints(request: request);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
