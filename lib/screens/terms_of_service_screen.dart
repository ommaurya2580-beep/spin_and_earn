import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last Updated: January 2026',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            _buildSection(
              '1. Acceptance of Terms',
              'By accessing or using the "Spin & Earn" app, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.',
            ),
            _buildSection(
              '2. Description of Service',
              'Spin & Earn provides a platform where users can earn virtual coins by spinning a wheel, often requiring the viewing of advertisements. These coins can be redeemed for rewards subject to our withdrawal policies.',
            ),
            _buildSection(
              '3. Eligibility',
              'You must be at least 18 years old to use this Service. By using the app, you represent and warrant that you meet this eligibility requirement.',
            ),
            _buildSection(
              '4. User Accounts',
              'You may only create one account per person. You are responsible for maintaining the confidentiality of your account login information.',
            ),
            _buildSection(
              '5. Rewards & Withdrawals',
              '• Rewards are virtual coins with no real-world value outside of our platform.\n'
                  '• Withdrawals are subject to a minimum balance requirement.\n'
                  '• We reserve the right to delay or cancel withdrawals if suspicious activity is detected.\n'
                  '• The conversion rate of coins to currency is subject to change.',
            ),
            _buildSection(
              '6. Prohibited Activities',
              'You agree not to:\n'
                  '• Use automation, bots, or emulators to simulate spins or ad views.\n'
                  '• Create multiple accounts to abuse the referral system.\n'
                  '• Attempt to hack, reverse engineer, or disrupt the Service.\n'
                  '• Engage in fraudulent activity.',
            ),
            _buildSection(
              '7. Termination',
              'We may terminate or suspend your account immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.',
            ),
            _buildSection(
              '8. Changes to Terms',
              'We reserve the right to modify or replace these Terms at any time. Your continued use of the Service after any such changes constitutes your acceptance of the new Terms.',
            ),
            _buildSection(
              '9. Contact Information',
              'For any questions regarding these Terms, please contact us through the app support channel.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
