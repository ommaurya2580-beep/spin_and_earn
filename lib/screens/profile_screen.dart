import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/animated_balance_text.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import '../widgets/coin_animation_overlay.dart';
import '../widgets/daily_check_in_card.dart';
import '../config/ad_config.dart';
// Imports removed

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ... existing code ...
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  final TextEditingController _referralController = TextEditingController();
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _initAd();
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

  Future<void> _applyReferral(String uid) async {
    final code = _referralController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isApplying = true);
    
    final result = await FirestoreService().applyReferralCode(uid, code);
    
    setState(() => _isApplying = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: result == "Success" ? Colors.green : Colors.red,
        ),
      );
      if (result == "Success") {
        CoinAnimationOverlay.show(context, 200); // 200 is the referral bonus
        _referralController.clear();
      }
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _referralController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('My Profile'), elevation: 0, centerTitle: true),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          // ✅ Error state: prevents infinite spinner on Firestore permission-denied
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_off, size: 56, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not load profile.\nPlease check your connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
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

          // ✅ Changed 'points' to 'balance' for atomic FieldValue.increment sync
          final balance = (data['balance'] ?? data['points']) ?? 0;
          final earnings = balance / 1000;
          final spinsToday = data['spinsToday'] ?? 0;
          final myReferralCode = data['myReferralCode'] ?? '---';
          final referredBy = data['referredBy'];

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 1. Profile Header
                      _buildHeader(user, data),
                      
                      const SizedBox(height: 20),

                      // 2. Statistics
                      _buildStatsRow(balance, earnings, spinsToday),

                      const SizedBox(height: 20),

                      // 3. Referral Section
                      _buildReferralSection(myReferralCode, referredBy, user.uid),

                      const SizedBox(height: 20),

                      // 4. Daily Check-in Section
                      DailyCheckInCard(
                        uid: user.uid,
                        currentCheckInDay: data['currentCheckInDay'] ?? 1,
                        lastCheckInDate: data['lastCheckInDate'],
                      ),

                      const SizedBox(height: 20),
                      
                      // 5. Menu Options
                      _buildMenuOptions(),
                    ],
                  ),
                ),
              ),

              // Banner Ad
              if (_isAdLoaded && _bannerAd != null)
                SizedBox(
                  height: _bannerAd!.size.height.toDouble(),
                  width: _bannerAd!.size.width.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          );
        },
      ),
    );
  }

  // ... _buildHeader, _buildStatsRow, _buildStatCard, _buildReferralSection ...

  Widget _buildHeader(User user, Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
      decoration: const BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 46,
              backgroundImage: user.photoURL != null 
                  ? NetworkImage(user.photoURL!) 
                  : const AssetImage('assets/images/app_logo.png') as ImageProvider,
              child: null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            user.displayName ?? 'Player',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            // ✅ Null-safe: phone-auth users have no email; fall back to phoneNumber
            user.email ?? user.phoneNumber ?? '',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Gold Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int points, double earnings, int spins) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard('Coins', points, '', Icons.monetization_on, Colors.orange),
          const SizedBox(width: 10),
          _buildStatCard('Earnings', earnings, '₹', Icons.account_balance_wallet, Colors.green),
          const SizedBox(width: 10),
          _buildStatCard('Spins', spins, '', Icons.refresh, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, num value, String prefix, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            AnimatedBalanceText(
              targetValue: value,
              prefix: prefix,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralSection(String myCode, String? referredBy, String uid) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Refer & Earn', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Get 200 coins for every friend you refer!', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 15),
          
          // My Code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YOUR CODE', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    Text(myCode, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: myCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                  },
                  icon: const Icon(Icons.copy, color: Colors.white),
                )
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // Apply Code
          if (referredBy == null)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _referralController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter Friend\'s Code',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isApplying ? null : () => _applyReferral(uid),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber, 
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(15),
                  ),
                  child: _isApplying 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.check, color: Colors.black),
                )
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent),
                  const SizedBox(width: 10),
                  Text('Referred by: $referredBy', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildListTile(
            Icons.privacy_tip, 
            'Privacy Policy',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
          ),
          _buildListTile(
            Icons.description, 
            'Terms of Service',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())),
          ),
          _buildListTile(Icons.support_agent, 'Help & Support', () => _showSupportDialog()),
          _buildListTile(Icons.star, 'Rate Us', () {}),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _confirmLogout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              elevation: 0,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Need Help?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Contact us at:'),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ommaurya2580@gmail.com',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.deepPurple),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: 'ommaurya2580@gmail.com'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Email copied!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().logout();
              if (mounted) {
                context.read<UserProvider>().clear();
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
