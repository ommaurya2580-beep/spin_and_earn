import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../providers/user_provider.dart';
import '../services/ad_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AdService _adService = AdService();
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  static const int _pointsPerRupee = 1000;
  static const int _minWithdrawal = 100;

  @override
  void initState() {
    super.initState();
    // Defer banner load so first frame paints quickly.
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
    super.dispose();
  }

  double _getBalance(int points) {
    return points / _pointsPerRupee;
  }

  int _getPointsForRupees(double rupees) {
    return (rupees * _pointsPerRupee).toInt();
  }

  Future<void> _showWithdrawalDialog(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null) return;

    final balance = _getBalance(user.points);
    if (balance < _minWithdrawal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum withdrawal is ₹$_minWithdrawal. You have ₹${balance.toStringAsFixed(2)}',
          ),
        ),
      );
      return;
    }

    final upiController = TextEditingController(text: user.upiId);
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Money'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: upiController,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'yourname@upi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                hintText: 'Minimum: $_minWithdrawal',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Text(
              'Available balance: ₹${balance.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final upiId = upiController.text.trim();
              final amountText = amountController.text.trim();

              if (upiId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter UPI ID')),
                );
                return;
              }

              if (amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter amount')),
                );
                return;
              }

              final amount = double.tryParse(amountText);
              if (amount == null || amount < _minWithdrawal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Minimum withdrawal is ₹$_minWithdrawal'),
                  ),
                );
                return;
              }

              if (amount > balance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Insufficient balance')),
                );
                return;
              }

              final pointsUsed = _getPointsForRupees(amount);

              try {
                await userProvider.requestWithdrawal(
                  upiId: upiId,
                  amountRupees: amount.toInt(),
                  pointsUsed: pointsUsed,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Withdrawal request submitted successfully!'),
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
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.user;
        final points = user?.points ?? 0;
        final balance = _getBalance(points);
        final totalEarnings = _getBalance(user?.totalEarnings ?? 0);
        final todayEarning = _getBalance(user?.todayEarning ?? 0);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Wallet'),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Balance Card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Text(
                                'Available Balance',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₹${balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '${points.toString()} points',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Stats
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Total Earnings',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${totalEarnings.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Today\'s Earnings',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${todayEarning.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Withdraw Button
                      ElevatedButton.icon(
                        onPressed: balance >= _minWithdrawal
                            ? () => _showWithdrawalDialog(context)
                            : null,
                        icon: const Icon(Icons.account_balance_wallet),
                        label: Text(
                          'Withdraw (Min: ₹$_minWithdrawal)',
                          style: const TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Conversion: 1000 points = ₹1',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
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
}
