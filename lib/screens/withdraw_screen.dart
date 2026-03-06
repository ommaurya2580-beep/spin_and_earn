import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../models/withdrawal_request_model.dart';
import '../config/ad_config.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _detailsController = TextEditingController();
  
  String _paymentMethod = 'UPI'; // UPI or Mobile
  bool _isLoading = false;
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  final int _minWithdrawCoins = 10000;
  final double _conversionRate = 1000; // 1000 coins = 1 Rupee

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Ad failed to load: $error');
        },
      ),
    )..load();
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;
    
    final int coinsToWithdraw = int.parse(_amountController.text);
    
    // Check min limit
    if (coinsToWithdraw < _minWithdrawCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minimum withdrawal is $_minWithdrawCoins coins')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final request = WithdrawalRequest(
      id: '', // Firestore will generate this in service
      userId: user.uid,
      userName: user.displayName ?? 'User',
      coins: coinsToWithdraw,
      amountInRupees: coinsToWithdraw / _conversionRate,
      upiId: _paymentMethod == 'UPI' ? _detailsController.text : null,
      mobileNumber: _paymentMethod == 'Mobile' ? _detailsController.text : null,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    final result = await FirestoreService().requestWithdrawal(request);

    setState(() => _isLoading = false);

    if (mounted) {
      if (result == 'Success') {
        _amountController.clear();
        _detailsController.clear();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text('Request Submitted'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text('Your withdrawal request has been received successfully.'),
                 SizedBox(height: 10),
                 Text(
                   'Withdrawals are processed within 24–72 hours.',
                   style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                 ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              )
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $result')),
        );
      }
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _amountController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw Money')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text('Conversion Rate', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 5),
                            Text(
                              '$_conversionRate Coins = ₹1',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const Divider(color: Colors.white24, height: 30),
                            const Text('Minimum Withdrawal', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 5),
                             Text(
                              '$_minWithdrawCoins Coins',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
    
                      const SizedBox(height: 30),
    
                      // Input Fields
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        items: ['UPI', 'Mobile'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (val) => setState(() => _paymentMethod = val!),
                        decoration: const InputDecoration(
                          labelText: 'Select Payment Method',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      TextFormField(
                        controller: _detailsController,
                        decoration: InputDecoration(
                          labelText: _paymentMethod == 'UPI' ? 'Enter UPI ID' : 'Enter Mobile Number',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(_paymentMethod == 'UPI' ? Icons.account_balance_wallet : Icons.phone),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (_paymentMethod == 'Mobile' && val.length != 10) return 'Invalid Mobile Number';
                          if (_paymentMethod == 'UPI' && !val.contains('@')) return 'Invalid UPI ID';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
    
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Enter Coins to Withdraw',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monetization_on, color: Colors.amber),
                          suffixText: 'Coins',
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          final n = int.tryParse(val);
                          if (n == null) return 'Invalid number';
                          if (n < _minWithdrawCoins) return 'Min $_minWithdrawCoins required';
                          return null;
                        },
                      ),
    
                      const SizedBox(height: 40),
    
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitWithdrawal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('SUBMIT REQUEST', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                const Text("Withdrawal History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                // History List
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('withdraw_requests')
                      .where('userId', isEqualTo: user.uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      // Log specific error for debugging and index creation
                      print("Firestore Query Error: ${snapshot.error}");
                      // Show graceful user-facing message
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "Unable to load history",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No withdrawals yet."));
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final request = WithdrawalRequest.fromMap(data, docs[index].id);
                        
                        Color statusColor;
                        switch (request.status.toLowerCase()) {
                          case 'approved': statusColor = Colors.green; break;
                          case 'rejected': statusColor = Colors.red; break;
                          default: statusColor = Colors.orange;
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple.withOpacity(0.1),
                              child: const Text('₹', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                            ),
                            title: Text('₹${request.amountInRupees.toStringAsFixed(1)}'),
                            subtitle: Text('${request.coins} Coins • ${_formatDate(request.createdAt)}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                request.status.toUpperCase(),
                                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 60), // Space for Ad
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
