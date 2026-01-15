import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/ad_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AdService _adService = AdService();
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  final TextEditingController _referralCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Defer banner load so profile UI appears without waiting on ads.
    Future.microtask(_loadBannerAd);
  }

  void _loadBannerAd() {
    _bannerAd = _adService.createBannerAd(
      adSize: AdSize.banner,
      onAdLoaded: (ad) {
        setState(() {
          _isBannerAdReady = true;
        });
      },
      onAdFailedToLoad: (error) {
        print('Banner ad failed to load: $error');
        setState(() {
          _isBannerAdReady = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _showEditUPIDialog(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null) return;

    final upiController = TextEditingController(text: user.upiId);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit UPI ID'),
        content: TextField(
          controller: upiController,
          decoration: const InputDecoration(
            labelText: 'UPI ID',
            hintText: 'yourname@upi',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final upiId = upiController.text.trim();
              try {
                await userProvider.updateUserData(user.uid, {'upiId': upiId});
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('UPI ID updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReferralCodeDialog(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null || user.referralUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already used a referral code'),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Referral Code'),
        content: TextField(
          controller: _referralCodeController,
          decoration: const InputDecoration(
            labelText: 'Referral Code',
            hintText: 'Enter code',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _referralCodeController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = _referralCodeController.text.trim().toUpperCase();
              if (code.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a referral code')),
                );
                return;
              }

              if (code == user.myReferralCode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot use your own referral code'),
                  ),
                );
                return;
              }

              try {
                await userProvider.useReferralCode(user.uid, code);
                if (context.mounted) {
                  _referralCodeController.clear();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Referral code applied! You both earned 2000 points!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        final user = userProvider.user;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    await authProvider.signOut();
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const CircleAvatar(
                                radius: 50,
                                child: Icon(Icons.person, size: 50),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                user?.name ?? 'User',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user?.email ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // UPI ID Section
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.account_balance_wallet),
                          title: const Text('UPI ID'),
                          subtitle: Text(
                            user?.upiId.isEmpty ?? true
                                ? 'Not set'
                                : user!.upiId,
                          ),
                          trailing: const Icon(Icons.edit),
                          onTap: () => _showEditUPIDialog(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Referral Code Section
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.card_giftcard),
                              title: const Text('My Referral Code'),
                              subtitle: Text(
                                user?.myReferralCode ?? '',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  if (user?.myReferralCode != null) {
                                    // Copy to clipboard
                                    // You can use clipboard package if needed
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Referral code: ${user!.myReferralCode}',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            if (user?.referralUsed == false) ...[
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.add_circle_outline),
                                title: const Text('Enter Referral Code'),
                                subtitle: const Text(
                                  'Get 2000 bonus points when you use a referral code',
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () => _showReferralCodeDialog(context),
                              ),
                            ],
                            if (user?.referralUsed == true) ...[
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.check_circle),
                                title: const Text('Referral Code Used'),
                                subtitle: Text(
                                  'Referred by: ${user?.referredBy ?? 'N/A'}',
                                ),
                                enabled: false,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Stats Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Statistics',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildStatRow('Total Points', '${user?.points ?? 0}'),
                              _buildStatRow(
                                'Total Earnings',
                                '₹${((user?.totalEarnings ?? 0) / 1000).toStringAsFixed(2)}',
                              ),
                              _buildStatRow(
                                'Today\'s Earnings',
                                '₹${((user?.todayEarning ?? 0) / 1000).toStringAsFixed(2)}',
                              ),
                              _buildStatRow(
                                'Spins Today',
                                '${user?.spinsToday ?? 0}/5',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Banner Ad
              if (_isBannerAdReady && _bannerAd != null)
                Container(
                  alignment: Alignment.center,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
