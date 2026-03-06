import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/ad_service.dart';
import 'coin_animation_overlay.dart';

class DailyCheckInCard extends StatefulWidget {
  final String uid;
  final int currentCheckInDay;
  final Timestamp? lastCheckInDate;

  const DailyCheckInCard({
    super.key,
    required this.uid,
    required this.currentCheckInDay,
    this.lastCheckInDate,
  });

  @override
  State<DailyCheckInCard> createState() => _DailyCheckInCardState();
}

class _DailyCheckInCardState extends State<DailyCheckInCard> {
  bool _isLoading = false;
  final AdService _adService = AdService();
  bool _adReady = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _adService.loadRewardedAd(
      onLoaded: () {
        if (mounted) setState(() => _adReady = true);
      },
      onFailed: (error) {
        //
      }
    );
  }

  @override
  void dispose() {
    _adService.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    DateTime? lastDate;
    if (widget.lastCheckInDate != null) {
      lastDate = widget.lastCheckInDate!.toDate();
    }

    bool claimedToday = lastDate != null && _isSameDay(lastDate, now);
    
    // Calculate display logic
    int displayCurrentDay = widget.currentCheckInDay;
    bool streakBroken = false;

    if (!claimedToday && lastDate != null) {
        final yesterday = now.subtract(const Duration(days: 1));
        bool wasYesterday = _isSameDay(lastDate, yesterday);
        if (!wasYesterday) {
           streakBroken = true;
           displayCurrentDay = 1; // Visual reset
        }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Check-In Bonus',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '7-Day Streak', 
                    style: TextStyle(color: Colors.grey, fontSize: 12)
                  ),
                ],
              ),
              if (claimedToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text("Claimed", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Days Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (index) {
                final dayNum = index + 1;
                final rewards = [5, 10, 15, 20, 25, 30, 35];
                final reward = rewards[index];
                
                bool isCompleted = dayNum < displayCurrentDay;
                bool isCurrent = dayNum == displayCurrentDay;
                
                return _buildDayItem(dayNum, reward, isCompleted, isCurrent, claimedToday);
              }),
            ),
          ),
          
          const SizedBox(height: 20),

          // Footer Text / Button
          if (claimedToday)
             const Center(
               child: Text(
                 "Come back tomorrow to continue your streak!",
                 style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
               ),
             )
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: const Column(
                    children: [
                      Text("🔔 Watch full ad to unlock today’s bonus", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      Text("❌ Skipping ad = No reward", style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleAdAndClaim,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                    icon: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.play_circle_fill, size: 20),
                    label: _isLoading 
                      ? const Text("Processing...")
                      : Text("Watch Ad & Claim +${[5,10,15,20,25,30,35][displayCurrentDay-1]} Coins"),
                  ),
                ),
              ],
            ),
          
          if (displayCurrentDay == 7 && !claimedToday)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Center(
                child: Text("Day 7 gives highest reward 🔥", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayItem(int day, int coins, bool isCompleted, bool isCurrent, bool claimedToday) {
    Color bg;
    Color border;
    Color textColor;

    if (isCompleted) {
      bg = Colors.green.withOpacity(0.1);
      border = Colors.green;
      textColor = Colors.green;
    } else if (isCurrent) {
        if (claimedToday) {
            bg = Colors.grey.withOpacity(0.1);
            border = Colors.grey.withOpacity(0.3);
            textColor = Colors.grey;
        } else {
            bg = Colors.amber.withOpacity(0.2);
            border = Colors.amber;
            textColor = Colors.deepOrange;
        }
    } else {
      bg = Colors.grey.withOpacity(0.05);
      border = Colors.transparent;
      textColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text("Day $day", style: TextStyle(fontSize: 10, color: textColor)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : (isCurrent && !claimedToday ? Colors.amber : Colors.grey[300]),
              shape: BoxShape.circle,
            ),
            child: isCompleted 
               ? const Icon(Icons.check, color: Colors.white, size: 16)
               : const Icon(Icons.monetization_on, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 5),
          Text(
            "+$coins", 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.bold,
              color: textColor
            )
          ),
        ],
      ),
    );
  }

  Future<void> _handleAdAndClaim() async {
    // 1. Check if ad is ready
    if (!_adService.isAdReady && !_adService.isAdLoading) {
       _adService.loadRewardedAd();
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loading Ad... Please wait a moment.")));
       return;
    }

    setState(() => _isLoading = true);
    
    // 2. Show Ad
    _adService.showRewardedAd(
      onUserEarnedReward: () {
        // 3. User watched full ad -> Claim Reward
        _claimReward();
      },
      onAdNotReady: () {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ad not ready yet. Please try again in a few seconds.")));
      },
      onAdDismissed: () {
        // Allow retry if they skipped
        if (mounted) setState(() => _isLoading = false);
      }
    );
  }

  Future<void> _claimReward() async {
    try {
      final reward = await FirestoreService().claimDailyCheckIn(widget.uid);
      
      if (mounted) {
        CoinAnimationOverlay.show(context, reward);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Success! You claimed $reward coins!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
