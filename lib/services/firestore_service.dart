import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../models/withdrawal_request_model.dart';
import '../utils/device_util.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<void> createUserIfNotExists(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    
    // Store Device ID for tracking
    final deviceId = await DeviceUtil.getDeviceId();

    if (!snap.exists) {
      String loginMethod = 'email';
      // Infer login method from provider data
      for (var p in user.providerData) {
        if (p.providerId == 'google.com') {
          loginMethod = 'google';
        } else if (p.providerId == 'phone') {
          loginMethod = 'phone';
        }
      }

      await ref.set({
        'uid': user.uid,
        'email': user.email,
        'mobileNumber': user.phoneNumber, // Store phone number
        'loginMethod': loginMethod, // Store login method
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'balance': 50, // Initial bonus
        'todayEarning': 0,
        'totalEarnings': 0,
        'totalLoss': 0,
        'spinsToday': 0,
        'lastSpinDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'myReferralCode': _generateCode(),
        'deviceId': deviceId, // Track device
      });
    } else {
        // Update device ID if missing (for legacy users)
        if (deviceId != null) {
            await ref.update({'deviceId': deviceId});
        }
    }
  }

  /// 🛠️ One-Time Repair Method for Historical Wallet Corruption
  /// Fixes missing or corrupted balances caused by the previous overwrite bug.
  Future<void> repairCorruptedWallet(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      
      final num balance = data['balance'] ?? 0;
      final int todayEarning = data['todayEarning'] ?? 0;
      final int totalEarnings = data['totalEarnings'] ?? 0;
      
      Map<String, dynamic> updates = {};

      // 1. Repair Balance (If todayEarning is greater than balance, balance was overwritten)
      if (todayEarning > balance) {
        updates['balance'] = todayEarning; 
      }

      // 2. Repair Total Earnings (If todayEarning is greater than totalEarnings)
      if (todayEarning > totalEarnings) {
         updates['totalEarnings'] = todayEarning;
      }
      
      // 3. Ensure daily fields exist
      if (!data.containsKey('spinsToday')) updates['spinsToday'] = 0;
      if (!data.containsKey('totalLoss')) updates['totalLoss'] = 0;

      if (updates.isNotEmpty) {
        transaction.update(userRef, updates);
      }
    });
  }

  /// Claims the Daily Check-In Bonus (7-Day Streak)
  /// Returns the amount of coins awarded, or throws an error if already claimed.
  Future<int> claimDailyCheckIn(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    
    // Coins for each day: Day 1..7 (Index 0..6)
    const rewards = [5, 10, 15, 20, 25, 30, 35];

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) throw Exception("User not found!");

      final data = snapshot.data() as Map<String, dynamic>;
      
      // Get current check-in state
      final int currentDay = data['currentCheckInDay'] ?? 1; // 1-based (1..7)
      final rawDate = data['lastCheckInDate'];
      
      DateTime? lastDate;
      if (rawDate is Timestamp) {
        lastDate = rawDate.toDate();
      } else if (rawDate is String) {
        lastDate = DateTime.tryParse(rawDate);
      }

      final now = DateTime.now();

      // Check if already claimed today
      if (lastDate != null && _isSameDay(lastDate, now)) {
        throw Exception("Already claimed for today!");
      }

      int dayToClaim = currentDay;

      // Check for streak reset
      // If last check-in was NOT yesterday (and not today, which we handled), reset to Day 1.
      // We allow "today" as "continued" only if it was claimed yesterday.
      // If lastDate is null, it's Day 1.
      if (lastDate != null) {
        final yesterday = now.subtract(const Duration(days: 1));
        final isYesterday = _isSameDay(lastDate, yesterday);
        
        if (!isYesterday) {
          // Missed a day (or more), reset to Day 1
          dayToClaim = 1;
        }
      } else {
        dayToClaim = 1; // First time ever
      }
      
      // Safety clamp
      if (dayToClaim < 1 || dayToClaim > 7) dayToClaim = 1;

      final reward = rewards[dayToClaim - 1];
      
      // Prepare next day state
      int nextDay = dayToClaim + 1;
      if (nextDay > 7) nextDay = 1; // Loop back after Day 7

      transaction.update(userRef, {
        'balance': FieldValue.increment(reward),
        'todayEarning': FieldValue.increment(reward), // Assuming points contribute to earnings
        'currentCheckInDay': nextDay, // Store the NEXT day for tomorrow
        'lastCheckInDate': Timestamp.now(),
      });

      // 📜 Add to Coin History
      _addHistoryInTransaction(transaction, uid, 'Daily Check-in', reward);
      
      return reward;
    });
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  /// Generated determenistic spin reward locally.
  int generateSpinReward(Map<String, dynamic> data) {
    const List<int> wheelPrizes = [0, 50, 100, 200, 500, 10, 20, 1000];

    final rawDate = data['lastSpinDate'];
    DateTime? lastDate;
    if (rawDate is Timestamp) {
      lastDate = rawDate.toDate();
    } else if (rawDate is String) {
      lastDate = DateTime.tryParse(rawDate);
    }
    
    final now = DateTime.now();
    bool isNewDay = lastDate == null || !_isSameDay(lastDate, now);

    int spinsToday = data['spinsToday'] ?? 0;
    int todayEarning = data['todayEarning'] ?? 0;
    int dailyEarnTarget = data['dailyEarnTarget'] ?? 0;

    if (isNewDay) {
      spinsToday = 0;
      todayEarning = 0;
      dailyEarnTarget = 1000 + Random().nextInt(501); 
    } else {
      if (spinsToday >= 10) return 0; // limit reached
      if (dailyEarnTarget < 1000 || dailyEarnTarget > 1500) {
         dailyEarnTarget = 1000 + Random().nextInt(501);
      }
    }

    int reward = 0;
    final int currentSpinIndex = spinsToday + 1; // 1 to 10
    final int remainingCoins = dailyEarnTarget - todayEarning;
    
    if (currentSpinIndex >= 10) {
      int bestMatch = 0;
      int minDiff = 99999;
      
      for (int p in wheelPrizes) {
          int diff = (remainingCoins - p).abs();
          if (diff < minDiff) {
              minDiff = diff;
              bestMatch = p;
          }
      }
      if (todayEarning + bestMatch > 1500) {
         bestMatch = 0;
         for (int p in wheelPrizes) {
             if (todayEarning + p <= 1500 && p > bestMatch) {
                 bestMatch = p;
             }
         }
      }
      reward = bestMatch;
    } else {
      List<int> weightedOptions = [];
      bool needsCatchup = (todayEarning < (dailyEarnTarget * (spinsToday / 10.0)));
      
      if (currentSpinIndex <= 2) {
           weightedOptions = [0, 10, 10, 20, 20, 50]; 
      } else if (currentSpinIndex <= 7) {
           if (needsCatchup) {
               weightedOptions = [50, 100, 100, 200];
           } else {
               weightedOptions = [10, 20, 50, 50, 100];
           }
      } else {
           if (remainingCoins > 500) {
               weightedOptions = [200, 500, 1000];
           } else if (remainingCoins > 200) {
               weightedOptions = [100, 200, 500];
           } else {
               weightedOptions = [50, 100, 200];
           }
      }

      reward = weightedOptions[Random().nextInt(weightedOptions.length)];

      if (todayEarning + reward > 1500) {
           reward = 0;
           for (int p in wheelPrizes) {
               if (p != 0 && todayEarning + p <= 1500) {
                   reward = p; 
                   break; 
               }
           }
      }
    }
    return reward;
  }

  /// Process a Spin: Validates limit (10/day) and persists exact rewarded amount.
  Future<void> processSpin(String uid, int rewardAmount) async {
    // ✅ Auth guard: reject if caller != authenticated user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != uid) {
      throw Exception('Unauthorized: You must be logged in to spin.');
    }

    final userRef = _db.collection('users').doc(uid);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) throw Exception("User not found!");

      final data = snapshot.data() as Map<String, dynamic>;
      
      // 1. Get Current State & Reset Logic
      final rawDate = data['lastSpinDate'];
      DateTime? lastDate;
      if (rawDate is Timestamp) {
        lastDate = rawDate.toDate();
      } else if (rawDate is String) {
        lastDate = DateTime.tryParse(rawDate);
      }
      
      final now = DateTime.now();
      bool isNewDay = lastDate == null || !_isSameDay(lastDate, now);

      int spinsToday = data['spinsToday'] ?? 0;
      int todayEarning = data['todayEarning'] ?? 0;
      int dailyEarnTarget = data['dailyEarnTarget'] ?? 0;

      if (isNewDay) {
        spinsToday = 0;
        todayEarning = 0;
        // Keep or generate base target
        if (dailyEarnTarget < 1000 || dailyEarnTarget > 1500) {
           dailyEarnTarget = 1000 + Random().nextInt(501); 
        }
      } else {
        if (spinsToday >= 10) {
          throw Exception("Daily spin limit reached! Come back tomorrow.");
        }
        if (dailyEarnTarget < 1000 || dailyEarnTarget > 1500) {
           dailyEarnTarget = 1000 + Random().nextInt(501);
        }
      }
      // Update State
      final int newSpins = spinsToday + 1;
      
      // Calculate the exact value for todayEarning to strictly use set math since Increment stacks with the old day's stale DB value if not cleared first.
      // But balance and totalEarnings must ALWAYS use Increment to avoid overwrites.
      final int newTodayEarning = isNewDay ? rewardAmount : todayEarning + rewardAmount;

      transaction.update(userRef, {
        if (rewardAmount > 0) 'balance': FieldValue.increment(rewardAmount),
        if (rewardAmount > 0) 'totalEarnings': FieldValue.increment(rewardAmount),
        if (rewardAmount >= 0) 'todayEarning': newTodayEarning,
        'spinsToday': newSpins,
        'dailyEarnTarget': dailyEarnTarget,
        'lastSpinDate': FieldValue.serverTimestamp(),
      });

      // 📜 Add to History directly inside processSpin
      if (rewardAmount > 0) {
        _addHistoryInTransaction(transaction, uid, 'Spin Reward', rewardAmount);
      } else {
         _addHistoryInTransaction(transaction, uid, 'Spin (No Reward)', 0);
      }
    });
  }

  /// Safe withdrawal using Transaction to prevent negative balance
  Future<String> requestWithdrawal(WithdrawalRequest request) async {
    try {
      final userRef = _db.collection('users').doc(request.userId);
      final withdrawRef = _db.collection('withdraw_requests').doc();

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) throw Exception("User does not exist!");

        final currentBalance = snapshot.data()?['balance'] ?? 0;
        if (currentBalance < request.coins) {
          throw Exception("Insufficient balance!");
        }

        // Deduct points
        transaction.update(userRef, {
          'balance': FieldValue.increment(-request.coins),
        });

        // Create withdrawal request with proper ID
        final requestMap = request.toMap();
        requestMap['id'] = withdrawRef.id;
        
        transaction.set(withdrawRef, requestMap);

        // 📜 Add to History
        _addHistoryInTransaction(transaction, request.userId, 'Withdrawal', -request.coins);
      });

      return "Success";
    } catch (e) {
      return e.toString();
    }
  }

  /// Apply Referral Code Logic with Fraud Protection
  Future<String> applyReferralCode(String currentUid, String code) async {
    try {
      final userRef = _db.collection('users').doc(currentUid);
      
      // 1. Get Device ID
      final deviceId = await DeviceUtil.getDeviceId();
      if (deviceId == null) {
          return "Could not verify device. Please try again.";
      }

      // 2. Validate Code
      final querySnapshot = await _db.collection('users')
          .where('myReferralCode', isEqualTo: code)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return "Invalid Referral Code";
      }

      final referrerDoc = querySnapshot.docs.first;
      final referrerUid = referrerDoc.id;

      if (referrerUid == currentUid) {
        return "You cannot use your own code!";
      }

      // 3. Run Transaction
      return await _db.runTransaction((transaction) async {
        // Check Device Claim (O(1) lookup)
        final deviceRef = _db.collection('referral_claims').doc(deviceId);
        final deviceSnap = await transaction.get(deviceRef);
        
        if (deviceSnap.exists) {
             throw Exception("Referral bonus already claimed on this device.");
        }

        final userSnap = await transaction.get(userRef);
        
        if (userSnap.data()?['referredBy'] != null) {
          throw Exception("You have already used a referral code!");
        }

        // 4. Update Current User
        transaction.update(userRef, {
          'referredBy': code,
          'balance': FieldValue.increment(200), // Bonus for new user
          'referralClaimedAt': FieldValue.serverTimestamp(),
        });

        // 5. Update Referrer
        final referrerRef = _db.collection('users').doc(referrerUid);
        transaction.update(referrerRef, {
          'balance': FieldValue.increment(200), // Bonus for referrer
        });

        // 6. Mark Device as Claimed
        transaction.set(deviceRef, {
            'claimed': true,
            'userId': currentUid,
            'claimedAt': FieldValue.serverTimestamp(),
        });

        // 📜 Add to History
        _addHistoryInTransaction(transaction, currentUid, 'Referral Bonus', 200);
        _addHistoryInTransaction(transaction, referrerUid, 'Referral Reward', 200);
        
        return "Success";
      });
    } catch (e) {
      if (e.toString().contains("already used") || e.toString().contains("already claimed")) { 
          return e.toString().replaceAll("Exception: ", "");
      }
      return "Error: $e";
    }
  }

  void _addHistoryInTransaction(Transaction transaction, String uid, String type, int coins) {
      final newRef = _db.collection('coin_history').doc();
      transaction.set(newRef, {
        'userId': uid,
        'type': type,
        'coins': coins,
        'createdAt': Timestamp.now(),
      });
  }

  String _generateCode() {
    const chars = 'ABCDEFGH123456789';
    return List.generate(
      6,
      (index) => chars[Random().nextInt(chars.length)],
    ).join();
  }
}
