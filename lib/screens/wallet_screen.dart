import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'withdraw_screen.dart';
import '../models/withdrawal_request_model.dart';
import '../widgets/animated_balance_text.dart';
import '../config/ad_config.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  Stream<DocumentSnapshot>? _userStream;
  Stream<QuerySnapshot>? _withdrawStatsStream;
  Stream<QuerySnapshot>? _coinHistoryStream;

  @override
  void initState() {
    super.initState();
    _initAd();

    // Ensure stream is initialized in initState(), NOT inside build()
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final String uid = user.uid;
      _userStream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
      _withdrawStatsStream = FirebaseFirestore.instance
          .collection('withdraw_requests')
          .where('userId', isEqualTo: uid)
          .snapshots();
      _coinHistoryStream = FirebaseFirestore.instance
          .collection('coin_history')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots();
    }
  }

  Future<void> _initAd() async {
    _bannerAd = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to user provider OR stream from Firestore
    // For real-time updates, it is best to stream the document if not already doing so in provider.
    final user = context.watch<UserProvider>().user;
    
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('My Wallet'), elevation: 0),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          // ✅ Error state: show user-friendly message instead of infinite spinner
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load wallet data.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          // ✅ Loading state
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          
          // 3. Extract balance safely
          final num balance = data['balance'] ?? 0;
          final double rupees = balance / 1000;
          
          // Earnings Logic
          final int totalEarnings = data['totalEarnings'] ?? 0;
          final double totalEarningsRupees = totalEarnings / 1000;
          
          // 🛡️ Safe Date Parsing
          DateTime? lastSpinDate;
          final rawDate = data['lastSpinDate'];
          if (rawDate is Timestamp) {
            lastSpinDate = rawDate.toDate();
          } else if (rawDate is String) {
            lastSpinDate = DateTime.tryParse(rawDate);
          }
          final bool isToday = lastSpinDate != null && _isSameDay(lastSpinDate, DateTime.now());
          final int todayCoins = isToday ? (data['todayEarning'] ?? 0) : 0;
          final double todayRupees = todayCoins / 1000;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 80), // Space for Ad
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Balance Card
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 8))
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 10),
                          AnimatedBalanceText(
                            targetValue: balance,
                            suffix: ' Coins',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          AnimatedBalanceText(
                            targetValue: rupees,
                            prefix: '≈ ₹',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.deepPurple,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const WithdrawScreen()),
                                );
                              },
                              icon: const Icon(Icons.account_balance_wallet),
                              label: const Text('WITHDRAW FUNDS'),
                            ),
                          )
                        ],
                      ),
                    ),

                    // 2. Wallet Stats Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: const Text('Wallet Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Row 1: Today's Earnings
                          Row(
                            children: [
                              _buildStatCard(
                                "Today's Earnings",
                                "$todayCoins Coins",
                                "₹${todayRupees.toStringAsFixed(2)}",
                                [const Color(0xFF11998e), const Color(0xFF38ef7d)],
                                Icons.calendar_today,
                              ),
                            ],
                          ),
                          // Row 2: Total Earnings
                          Row(
                            children: [
                              _buildStatCard(
                                "Total Earnings",
                                "$totalEarnings Coins",
                                "₹${totalEarningsRupees.toStringAsFixed(2)}",
                                [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
                                Icons.emoji_events,
                              ),
                            ],
                          ),
                          
                          // Row 3: Withdrawal Stats (Requires separate stream)
                          StreamBuilder<QuerySnapshot>(
                             stream: _withdrawStatsStream,
                             builder: (context, statsSnapshot) {
                               double withdrawn = 0;
                               double pending = 0;

                               if (statsSnapshot.hasData) {
                                 for (var doc in statsSnapshot.data!.docs) {
                                   final d = doc.data() as Map<String, dynamic>;
                                   final status = (d['status'] ?? '').toString().toLowerCase();
                                   final amount = (d['amountInRupees'] ?? 0).toDouble();
                                   
                                   if (status == 'approved' || status == 'completed') {
                                     withdrawn += amount;
                                   } else if (status == 'pending') {
                                     pending += amount;
                                   }
                                 }
                               }

                               return Row(
                                 children: [
                                   _buildStatCard(
                                     "Withdrawn",
                                     "₹${withdrawn.toStringAsFixed(0)}",
                                     "Completed",
                                     [const Color(0xFFf12711), const Color(0xFFf5af19)], 
                                     Icons.check_circle_outline,
                                   ),
                                   _buildStatCard(
                                     "Pending",
                                     "₹${pending.toStringAsFixed(0)}",
                                     "In Process",
                                     [const Color(0xFFDA22FF), const Color(0xFF9733EE)],
                                     Icons.hourglass_empty,
                                   ),
                                 ],
                               );
                             }
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const SizedBox(height: 20),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Coin History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    // 3. Coin History (Replaces old Transaction History)
                    StreamBuilder<QuerySnapshot>(
                      stream: _coinHistoryStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint("Firestore Query Error: ${snapshot.error}");
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Column(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
                                const SizedBox(height: 8),
                                const Text(
                                  'Could not load coin history.\nThis may require a Firestore index.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(30),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history, size: 60, color: Colors.grey.shade300),
                                  const SizedBox(height: 10),
                                  const Text('No coin history yet', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final coins = data['coins'] as int? ?? 0;
                            final type = data['type'] as String? ?? 'Unknown';
                            
                            // Safe Date Parsing
                            DateTime createdAt = DateTime.now();
                            final rawDate = data['createdAt'];
                            if (rawDate is Timestamp) {
                              createdAt = rawDate.toDate();
                            } else if (rawDate is String) {
                              createdAt = DateTime.tryParse(rawDate) ?? DateTime.now();
                            }

                            final isPositive = coins > 0;
                            final color = isPositive ? Colors.green : Colors.red;
                            final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withOpacity(0.1),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  '${createdAt.day}/${createdAt.month}/${createdAt.year} • ${_formatTime(createdAt)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: Text(
                                  '${isPositive ? '+' : ''}$coins',
                                  style: TextStyle(
                                    color: color, 
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 16
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

                  // Ad at Bottom
          if (_isAdLoaded && _bannerAd != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      );
  }
      ),
    );
  }

  // Helper widget for Stats Card
  Widget _buildStatCard(String title, String value, String subValue, List<Color> colors, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.8), size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(subValue, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatTime(DateTime date) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}
