import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/ad_service.dart';

class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen>
    with SingleTickerProviderStateMixin {
  final AdService _adService = AdService();
  final List<int> _rewards = [10, 25, 50, 100];
  bool _isSpinning = false;
  double _rotation = 0;
  int? _selectedReward;
  late AnimationController _animationController;
  static const int _maxSpinsPerDay = 5;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    // Defer heavy ad load to next microtask to avoid jank on first frame.
    Future.microtask(() => _adService.loadRewardedAd());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _canSpinToday(UserProvider userProvider) {
    final user = userProvider.user;
    if (user == null) return false;

    final now = DateTime.now();
    final lastSpinDate = user.lastSpinDate;

    // Check if it's a new day
    if (lastSpinDate == null ||
        lastSpinDate.year != now.year ||
        lastSpinDate.month != now.month ||
        lastSpinDate.day != now.day) {
      return true; // New day, can spin
    }

    // Same day - check spin count
    return user.spinsToday < _maxSpinsPerDay;
  }

  int _getRemainingSpins(UserProvider userProvider) {
    final user = userProvider.user;
    if (user == null) return 0;

    final now = DateTime.now();
    final lastSpinDate = user.lastSpinDate;

    if (lastSpinDate == null ||
        lastSpinDate.year != now.year ||
        lastSpinDate.month != now.month ||
        lastSpinDate.day != now.day) {
      return _maxSpinsPerDay; // New day
    }

    return _maxSpinsPerDay - user.spinsToday;
  }

  Future<void> _spinWheel(UserProvider userProvider) async {
    if (_isSpinning || !_canSpinToday(userProvider)) return;

    setState(() {
      _isSpinning = true;
      _selectedReward = null;
    });

    // Show rewarded ad
    final adShown = await _adService.showRewardedAd(
      onRewarded: (rewardAmount, rewardType) async {
        // Generate random reward
        final random = Random();
        final reward = _rewards[random.nextInt(_rewards.length)];

        // Animate wheel
        final spins = 3 + random.nextDouble() * 2; // 3-5 full rotations
        final targetRotation = _rotation + (spins * 2 * pi) +
            (2 * pi / _rewards.length * _rewards.indexOf(reward));

        _animationController.reset();
        final animation = Tween<double>(
          begin: _rotation,
          end: targetRotation,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.decelerate,
        ));

        animation.addListener(() {
          setState(() {
            _rotation = animation.value;
          });
        });

        await _animationController.forward();

        setState(() {
          _selectedReward = reward;
        });

        try {
          await userProvider.spinAndEarn(
            rewardPoints: reward,
            maxSpinsPerDay: _maxSpinsPerDay,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
        }

        setState(() {
          _isSpinning = false;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Congratulations! You won $reward points!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );

    if (!adShown) {
      setState(() {
        _isSpinning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad not ready. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.user;
        final canSpin = _canSpinToday(userProvider);
        final remainingSpins = _getRemainingSpins(userProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Spin & Earn'),
            actions: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${user?.points ?? 0}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Remaining spins info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 8),
                          Text(
                            'Spins remaining today: $remainingSpins/$_maxSpinsPerDay',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Spin Wheel
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: _rotation,
                          child: CustomPaint(
                            size: const Size(300, 300),
                            painter: SpinWheelPainter(_rewards, _selectedReward),
                          ),
                        ),
                        // Center pointer
                        Positioned(
                          top: 0,
                          child: Container(
                            width: 20,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Spin Button
                  ElevatedButton.icon(
                    onPressed: canSpin && !_isSpinning
                        ? () => _spinWheel(userProvider)
                        : null,
                    icon: _isSpinning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.casino),
                    label: Text(
                      _isSpinning
                          ? 'Spinning...'
                          : canSpin
                              ? 'Watch Ad & Spin'
                              : 'Daily limit reached',
                      style: const TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  if (_selectedReward != null) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'You won $_selectedReward points!',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SpinWheelPainter extends CustomPainter {
  final List<int> rewards;
  final int? selectedReward;

  SpinWheelPainter(this.rewards, this.selectedReward);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = 2 * pi / rewards.length;

    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
    ];

    for (int i = 0; i < rewards.length; i++) {
      final paint = Paint()
        ..color = selectedReward == rewards[i]
            ? colors[i].withOpacity(0.8)
            : colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweepAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw text
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${rewards[i]}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      final angle = i * sweepAngle + sweepAngle / 2;
      final textOffset = Offset(
        center.dx + (radius * 0.6) * cos(angle) - textPainter.width / 2,
        center.dy + (radius * 0.6) * sin(angle) - textPainter.height / 2,
      );

      canvas.save();
      canvas.translate(textOffset.dx, textOffset.dy);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(SpinWheelPainter oldDelegate) {
    return oldDelegate.selectedReward != selectedReward;
  }
}
