import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
              '1. Information We Collect',
              'We collect the following information to provide and improve our services:\n\n'
                  '• Personal Information: Name, Email Address (via Google Sign-In).\n'
                  '• User ID (UID): A unique identifier for your account.\n'
                  '• Device Information: Device model, OS version (for ads and analytics).\n'
                  '• Usage Data: Spin history, coins balance, withdrawal requests.',
            ),
            _buildSection(
              '2. How We Use Information',
              'We use your data for:\n\n'
                  '• Authentication: To securely log you in.\n'
                  '• Service Delivery: To track your rewards and process withdrawals.\n'
                  '• Fraud Prevention: To detect and prevent cheating or abuse.\n'
                  '• Communication: To respond to support requests.',
            ),
            _buildSection(
              '3. Ads & Third-Party Services',
              'We use Google AdMob to display advertisements. AdMob may collect data to show personalized ads. We also use Firebase for authentication and database services. These third parties have their own privacy policies.',
            ),
            _buildSection(
              '4. Data Security',
              'We implement security measures to protect your data. However, no method of transmission over the internet is 100% secure. We strive to use commercially acceptable means to protect your personal information.',
            ),
            _buildSection(
              '5. Data Retention',
              'We retain your personal information only for as long as is necessary for the purposes set out in this Privacy Policy.',
            ),
            _buildSection(
              '6. User Rights',
              'You have the right to access, update, or delete your personal information. You can request account deletion by contacting support.',
            ),
            _buildSection(
              '7. Children\'s Privacy',
              'Our service does not address anyone under the age of 18. We do not knowingly collect personally identifiable information from anyone under the age of 18.',
            ),
            _buildSection(
              '8. Changes to Policy',
              'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.',
            ),
            _buildSection(
              '9. Contact Us',
              'If you have any questions about this Privacy Policy, please contact us via the Help & Support section in the app.',
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
