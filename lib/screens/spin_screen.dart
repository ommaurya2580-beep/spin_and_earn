import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/coin_animation_overlay.dart';
import '../widgets/animated_balance_text.dart';
import '../config/ad_config.dart'; // Prod config

class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> {
  // 📢 AdMob Logic
  RewardedAd? _rewardedAd;
  bool _isAdLoading = true;
  bool _adLoadFailed = false; // NEW: tracks ad failure so button shows Retry
  final String _adUnitId = AdConfig.rewardedAdUnitId;

  // 🎡 Wheel Logic - BehaviorSubject used to persist selection across rebuilds
  final BehaviorSubject<int> _selectedController = BehaviorSubject<int>();
  final List<int> _prizes = [0, 50, 100, 200, 500, 10, 20, 1000];
  bool _isSpinning = false;
  bool _canSpin = false;

  // 📊 Single Firestore stream subscription (replaces two duplicate StreamBuilders)
  Stream<DocumentSnapshot>? _userStream;

  // 🎉 UI Effects
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 1500));
    _initAd();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
    }
  }

  Future<void> _initAd() async {
    // Safe initialization
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    if (!mounted) return;
    setState(() {
      _isAdLoading = true;
      _adLoadFailed = false; // Reset failure state on each attempt
    });

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          // ✅ Set the full-screen callback ONCE here – no override in show()
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (mounted) setState(() => _rewardedAd = null);
              // Preload the next ad immediately for smooth UX
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (mounted) {
                setState(() {
                  _rewardedAd = null;
                  _adLoadFailed = true;
                  _isAdLoading = false;
                });
              }
              _loadRewardedAd();
            },
          );
          if (mounted) {
            setState(() {
              _rewardedAd = ad;
              _isAdLoading = false;
              _adLoadFailed = false;
            });
          }
        },
        onAdFailedToLoad: (error) {
          if (mounted) {
            setState(() {
              _isAdLoading = false;
              _adLoadFailed = true; // ✅ Show Retry button instead of disabled button
            });
          }
        },
      ),
    );
  }

  void _watchAdToSpin() {
    if (_rewardedAd == null) {
      // Ad not ready – trigger load and inform user
      if (!_isAdLoading) _loadRewardedAd();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad is loading… please wait a moment.')),
        );
      }
      return;
    }

    // ✅ Do NOT override fullScreenContentCallback here – it was set in _loadRewardedAd.
    // Only use onUserEarnedReward to know when the reward is granted.
    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      if (mounted) {
        setState(() => _canSpin = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad completed! Tap "SPIN NOW" to win!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
    // Note: _rewardedAd reference is cleared inside onAdDismissedFullScreenContent
    // (set in _loadRewardedAd) to avoid double-dispose.
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  void _spinWheel() async {
    if (!_canSpin || _isSpinning) return;

    final user = context.read<UserProvider>().user;
    // ✅ Auth guard: never attempt Firestore write without a valid user
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
      return;
    }

    setState(() {
      _isSpinning = true;
      _canSpin = false; // Consume the spin entitlement immediately
    });

    try {
      // 1. 🌐 Pre-calculate reward using Deterministic server logic locally (no DB write yet)
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userSnap.data() as Map<String, dynamic>? ?? {};
      final int rewardAmount = FirestoreService().generateSpinReward(data);
      
      // 2. 🎯 Find Index of Reward on Wheel
      int targetIndex = _prizes.indexOf(rewardAmount);
      if (targetIndex == -1) {
        targetIndex = Random().nextInt(_prizes.length); 
      }
      
      // Be deterministic: Spin to the exact item
      _selectedController.add(targetIndex);

      // 3. ⏳ Wait for Animation (5 seconds)
      if (mounted) {
        Future.delayed(const Duration(seconds: 5), () async {
          if (mounted) {
             
             // 4. 🌐 Wait for Animation to finish, THEN save to Firestore 
             try {
                await FirestoreService().processSpin(user.uid, rewardAmount);
             } catch (e) {
                if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception:', '')}"), backgroundColor: Colors.red),
                    );
                    setState(() => _isSpinning = false);
                }
                return;
             }

             setState(() => _isSpinning = false);
             
             // 5. 🎉 Show Result
             if (rewardAmount > 0) {
               _confettiController.play(); 
               CoinAnimationOverlay.show(context, rewardAmount);
               if (mounted) _showWinDialog(rewardAmount);
             } else {
                 if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Better luck next time!')),
                     );
                 }
             }
          }
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
           _isSpinning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception:', '')}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showWinDialog(int points) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.deepPurple.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 50),
            SizedBox(height: 10),
            Text('CONGRATULATIONS!', 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'You won $points Coins!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('CLAIM REWARD'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _selectedController.close();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 🌌 Background (Static)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Color(0xFF2A004E), Color(0xFF0F001C)],
              ),
            ),
          ),

          // 🎡 Main Content — ✅ Single StreamBuilder for ALL data (no duplicate reads)
          Center(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _userStream,
              builder: (context, snapshot) {
                // Parse user data once for the whole screen
                final Object? rawSnapshotData = snapshot.hasData ? snapshot.data!.data() : null;
                final data = (rawSnapshotData as Map<String, dynamic>?) ?? {};

                // ✅ Safe extraction using Map keys to avoid throwing errors on missing fields
                final num balance = (data['balance'] ?? data['points']) ?? 0;
                final int dbSpins = data['spinsToday'] ?? 0;
                final int dbTodayEarned = data['todayEarning'] ?? 0;

                // 🛡️ Safe Date Parsing
                DateTime? lastDate;
                final rawDate = data['lastSpinDate'];
                if (rawDate is Timestamp) {
                  lastDate = rawDate.toDate();
                } else if (rawDate is String) {
                  lastDate = DateTime.tryParse(rawDate);
                }

                int spinsToday = 0;
                int todayEarned = 0;
                if (lastDate != null) {
                  final now = DateTime.now();
                  if (lastDate.year == now.year &&
                      lastDate.month == now.month &&
                      lastDate.day == now.day) {
                    spinsToday = dbSpins;
                    todayEarned = dbTodayEarned;
                  }
                }
                final bool isLimitReached = spinsToday >= 10;

                return SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ------------------------------------------------
                      // 📊 TOP SECTION: Balance & Stats
                      // ------------------------------------------------

                      // 💰 Balance Card
                      Container(
                        margin: const EdgeInsets.only(top: 60, bottom: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white10),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                            const SizedBox(width: 8),
                            AnimatedBalanceText(
                              targetValue: balance,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                      // Header
                      const Text(
                        'SPIN & WIN',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber,
                          letterSpacing: 2,
                          shadows: [Shadow(color: Colors.orangeAccent, blurRadius: 10)],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Stats Row (Spins + Earned)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              'Daily Spins: $spinsToday / 10',
                              style: TextStyle(
                                color: isLimitReached ? Colors.redAccent : Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amber.withOpacity(0.5)),
                            ),
                            child: Text(
                              'Today: $todayEarned',
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // ------------------------------------------------
                      // 🎡 MIDDLE SECTION: The Wheel (STATIC - No Rebuilds)
                      // ------------------------------------------------
                      RepaintBoundary(
                        child: SizedBox(
                          height: 320,
                          width: 320,
                          child: Stack(
                            children: [
                              Center(
                                child: Container(
                                  height: 310,
                                  width: 310,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.purpleAccent.withOpacity(0.5),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              FortuneWheel(
                                selected: _selectedController.stream,
                                animateFirst: false,
                                indicators: const <FortuneIndicator>[
                                  FortuneIndicator(
                                    alignment: Alignment.topCenter,
                                    child: TriangleIndicator(color: Colors.amber),
                                  ),
                                ],
                                items: [
                                  for (var prize in _prizes)
                                    FortuneItem(
                                      style: FortuneItemStyle(
                                        color: _prizes.indexOf(prize) % 2 == 0
                                            ? const Color(0xFF673AB7)
                                            : const Color(0xFFE91E63),
                                        borderColor: Colors.white24,
                                        borderWidth: 2,
                                      ),
                                      child: Text(
                                        prize == 0 ? '😢' : '$prize',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1))],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Center(
                                child: Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5)],
                                  ),
                                  child: const Center(child: Icon(Icons.star, color: Colors.brown)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      // ------------------------------------------------
                      // 🔘 BOTTOM SECTION: Action Buttons
                      // ------------------------------------------------
                      if (isLimitReached)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: const Text(
                            'Daily Limit Reached!\nCome back tomorrow for more spins.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        )
                      else if (_canSpin)
                        SizedBox(
                          width: 200,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isSpinning ? null : _spinWheel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.brown,
                              elevation: 10,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Text(
                              _isSpinning ? 'SPINNING...' : 'SPIN NOW!',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            // ✅ Ad button: shows loading / ready / retry states
                            if (_isAdLoading)
                              Container(
                                width: 240,
                                height: 55,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                                    SizedBox(width: 10),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Please wait...', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.2)),
                                        Text('Ad is loading', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14, height: 1.2)),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            else
                              SizedBox(
                                width: 240,
                                height: 55,
                                child: ElevatedButton.icon(
                                  onPressed: _adLoadFailed
                                          ? _loadRewardedAd // ✅ Retry on failure
                                          : _rewardedAd != null
                                              ? _watchAdToSpin
                                              : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _adLoadFailed ? Colors.orangeAccent : Colors.white,
                                    foregroundColor: Colors.deepPurple,
                                    elevation: 5,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                  icon: Icon(
                                    _adLoadFailed
                                        ? Icons.refresh
                                        : Icons.play_circle_fill,
                                    size: 28,
                                    color: Colors.deepPurple,
                                  ),
                                  label: Text(
                                    _adLoadFailed
                                        ? 'AD FAILED – TAP TO RETRY'
                                        : 'WATCH AD TO SPIN',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),

                            // ⚠️ Instruction UI
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              margin: const EdgeInsets.symmetric(horizontal: 30),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    '⚠️ Watch the full ad without skipping to unlock spin reward',
                                    style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInstructionItem('❌ Ad skipped = No spin'),
                                  _buildInstructionItem('❌ Ad incomplete = No coins'),
                                  _buildInstructionItem('✅ Ad completed = Spin + reward'),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 🎉 Confetti Overlay (Sibling to StreamBuilder)
          Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 20,
              gravity: 0.3, // Slow fall
              emissionFrequency: 0.05,
              minBlastForce: 5,
              maxBlastForce: 20,
              colors: const [
                Colors.amber, 
                Colors.deepPurple, 
                Colors.white,
                Color(0xFFFFD700) // Gold
              ],
            ),
          ),
        ],
      ),
    );
  }
}
