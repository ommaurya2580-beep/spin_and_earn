import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/withdrawal_request_model.dart';
import '../models/referral_code_model.dart';
import 'dart:math';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User Operations
  Future<UserModel?> getUser(String uid) async {
    // Legacy escape hatch. Prefer real-time `getUserStream` everywhere in UI.
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) return UserModel.fromMap(doc.data()!);
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(uid).update(updates);
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!) : null);
  }

  /// Create user doc if missing and ensure referral code doc exists.
  /// One-time operation during sign-in only.
  Future<void> ensureUserInitialized({
    required UserModel newUser,
  }) async {
    final userRef = _firestore.collection('users').doc(newUser.uid);
    final referralRef =
        _firestore.collection('referralCodes').doc(newUser.myReferralCode);

    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        tx.set(userRef, newUser.toMap());
      }

      final referralSnap = await tx.get(referralRef);
      if (!referralSnap.exists) {
        final referral =
            ReferralCodeModel(code: newUser.myReferralCode, uid: newUser.uid);
        tx.set(referralRef, referral.toMap());
      }
    });
  }

  /// Lifecycle-safe daily bonus + lastLogin update.
  /// Transaction prevents duplicate bonus in race conditions.
  Future<void> applyLoginAndDailyBonus(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final lastLoginRaw = data['lastLoginDate'] as String?;
      final lastLogin =
          lastLoginRaw != null ? DateTime.tryParse(lastLoginRaw) : null;

      final isSameDay = lastLogin != null &&
          lastLogin.year == now.year &&
          lastLogin.month == now.month &&
          lastLogin.day == now.day;

      // Always write lastLoginDate (useful for analytics/streaks).
      tx.update(userRef, {'lastLoginDate': nowIso});

      if (isSameDay) return;

      // Random daily bonus between 1000–3000 points (₹1–₹3).
      final rand = Random();
      final bonus = (rand.nextInt(3) + 1) * 1000;
      tx.update(userRef, {
        'points': FieldValue.increment(bonus),
        'totalEarnings': FieldValue.increment(bonus),
      });
    });
  }

  // Generate unique referral code
  String generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String code;
    bool exists = true;

    // Keep generating until we find a unique code
    do {
      code = String.fromCharCodes(Iterable.generate(
          6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
      // Check if code exists (we'll check this in the calling function)
      exists = false; // Simplified for now - in production, check Firestore
    } while (exists);

    return code;
  }

  // Referral Code Operations
  Future<bool> checkReferralCodeExists(String code) async {
    try {
      final doc =
          await _firestore.collection('referralCodes').doc(code).get();
      return doc.exists;
    } catch (e) {
      print('Error checking referral code: $e');
      return false;
    }
  }

  Future<ReferralCodeModel?> getReferralCode(String code) async {
    try {
      final doc =
          await _firestore.collection('referralCodes').doc(code).get();
      if (doc.exists) {
        return ReferralCodeModel.fromMap(code, doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting referral code: $e');
      return null;
    }
  }

  Future<void> createReferralCode(String code, String uid) async {
    try {
      final referralCode = ReferralCodeModel(code: code, uid: uid);
      await _firestore
          .collection('referralCodes')
          .doc(code)
          .set(referralCode.toMap());
    } catch (e) {
      print('Error creating referral code: $e');
      rethrow;
    }
  }

  Future<void> useReferralCode(String code, String userId) async {
    try {
      final referralDoc =
          _firestore.collection('referralCodes').doc(code);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(referralDoc);
        if (!snapshot.exists) {
          throw Exception('Referral code does not exist');
        }

        final data = snapshot.data()!;
        final usedBy = List<String>.from(data['usedBy'] ?? []);
        
        if (usedBy.contains(userId)) {
          throw Exception('Referral code already used by this user');
        }

        usedBy.add(userId);
        transaction.update(referralDoc, {'usedBy': usedBy});
      });
    } catch (e) {
      print('Error using referral code: $e');
      rethrow;
    }
  }

  /// Apply referral code + reward both users atomically (race-safe).
  Future<void> applyReferralCodeAndReward({
    required String currentUid,
    required String code,
    int reward = 2000,
  }) async {
    final referralRef = _firestore.collection('referralCodes').doc(code);
    final currentUserRef = _firestore.collection('users').doc(currentUid);

    await _firestore.runTransaction((tx) async {
      final referralSnap = await tx.get(referralRef);
      if (!referralSnap.exists) {
        throw Exception('Invalid referral code');
      }

      final referralData = referralSnap.data() as Map<String, dynamic>;
      final referrerUid = referralData['uid'] as String?;
      if (referrerUid == null || referrerUid.isEmpty) {
        throw Exception('Invalid referral code');
      }
      if (referrerUid == currentUid) {
        throw Exception('Cannot use your own referral code');
      }

      final currentSnap = await tx.get(currentUserRef);
      if (!currentSnap.exists) {
        throw Exception('User not found');
      }
      final currentData = currentSnap.data() as Map<String, dynamic>;
      final referralUsed = (currentData['referralUsed'] as bool?) ?? false;
      if (referralUsed) {
        throw Exception('Referral code already used');
      }

      final usedBy = List<String>.from(referralData['usedBy'] ?? const []);
      if (usedBy.contains(currentUid)) {
        throw Exception('Referral code already used by this user');
      }

      usedBy.add(currentUid);
      tx.update(referralRef, {'usedBy': usedBy});

      // Reward current user + mark referral.
      tx.update(currentUserRef, {
        'points': FieldValue.increment(reward),
        'totalEarnings': FieldValue.increment(reward),
        'referralUsed': true,
        'referredBy': code,
      });

      // Reward referrer.
      final referrerRef = _firestore.collection('users').doc(referrerUid);
      tx.update(referrerRef, {
        'points': FieldValue.increment(reward),
        'totalEarnings': FieldValue.increment(reward),
      });
    });
  }

  // Withdrawal Operations
  Future<String> createWithdrawalRequest(
      WithdrawalRequestModel request) async {
    try {
      final docRef =
          await _firestore.collection('withdrawalRequests').add(request.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating withdrawal request: $e');
      rethrow;
    }
  }

  Stream<List<WithdrawalRequestModel>> getWithdrawalRequests(String uid) {
    return _firestore
        .collection('withdrawalRequests')
        .where('uid', isEqualTo: uid)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WithdrawalRequestModel.fromMap(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Create withdrawal request + deduct points atomically.
  Future<void> createWithdrawalAndDeductPoints({
    required WithdrawalRequestModel request,
  }) async {
    final userRef = _firestore.collection('users').doc(request.uid);
    final requestsRef = _firestore.collection('withdrawalRequests').doc();

    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('User not found');
      final data = userSnap.data() as Map<String, dynamic>;
      final currentPoints = (data['points'] as num?)?.toInt() ?? 0;
      if (currentPoints < request.pointsUsed) {
        throw Exception('Insufficient balance');
      }

      tx.set(requestsRef, request.toMap());
      tx.update(userRef, {'points': FieldValue.increment(-request.pointsUsed)});
    });
  }

  /// Spin reward with daily limit protection (race-safe).
  Future<void> applySpinReward({
    required String uid,
    required int rewardPoints,
    int maxSpinsPerDay = 5,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) throw Exception('User not found');
      final data = snap.data() as Map<String, dynamic>;

      final lastSpinRaw = data['lastSpinDate'] as String?;
      final lastSpin = lastSpinRaw != null ? DateTime.tryParse(lastSpinRaw) : null;
      final spinsToday = (data['spinsToday'] as num?)?.toInt() ?? 0;

      final isSameDay = lastSpin != null &&
          lastSpin.year == now.year &&
          lastSpin.month == now.month &&
          lastSpin.day == now.day;

      final effectiveSpinsToday = isSameDay ? spinsToday : 0;
      if (effectiveSpinsToday >= maxSpinsPerDay) {
        throw Exception('Daily limit reached');
      }

      tx.update(userRef, {
        'points': FieldValue.increment(rewardPoints),
        'totalEarnings': FieldValue.increment(rewardPoints),
        'todayEarning': FieldValue.increment(rewardPoints),
        'spinsToday': isSameDay ? FieldValue.increment(1) : 1,
        'lastSpinDate': nowIso,
      });
    });
  }

  // Spin History (Optional)
  Future<void> saveSpinHistory(String uid, int reward, int points) async {
    try {
      await _firestore.collection('users').doc(uid).collection('spinHistory').add({
        'reward': reward,
        'points': points,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving spin history: $e');
      // Don't throw - this is optional
    }
  }

  // Daily bonus operations
  Future<int> getDailyBonusStreak(String uid) async {
    try {
      final user = await getUser(uid);
      if (user == null || user.lastLoginDate == null) return 1;

      final now = DateTime.now();
      final lastLogin = user.lastLoginDate!;
      
      // Check if last login was today
      if (now.year == lastLogin.year &&
          now.month == lastLogin.month &&
          now.day == lastLogin.day) {
        // Already logged in today, return 0 to prevent duplicate bonus
        return 0;
      }

      // Check if last login was yesterday (streak continues)
      final yesterday = now.subtract(const Duration(days: 1));
      if (yesterday.year == lastLogin.year &&
          yesterday.month == lastLogin.month &&
          yesterday.day == lastLogin.day) {
        // Streak continues - we'll calculate based on a stored streak value
        // For simplicity, we'll use a basic calculation
        // In production, you might want to store streak in user document
        return 2; // Assume day 2 for now
      }

      // New streak
      return 1;
    } catch (e) {
      print('Error getting daily bonus streak: $e');
      return 1;
    }
  }
}
