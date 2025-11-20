import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Privacy Policy for FinzoBilling',
              'Last updated: ${DateTime.now().year}',
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              '1. Information We Collect',
              '''We collect and store the following information:

• Business Details: Company name, GSTIN, address, and contact information
• Invoice Data: All invoice details including client information and amounts
• Product Information: Product details, prices, and inventory
• Client Details: Client names, contact info, and GSTIN
• Payment Records: Payment amounts, methods, and dates
• Expense Data: Business expense records
• User Account: Email address and authentication data''',
            ),
            
            _buildSection(
              '2. How We Use Your Information',
              '''Your data is used to:

• Provide billing and invoicing services
• Generate GST-compliant reports
• Store and sync your data across devices
• Provide customer support
• Improve app functionality
• Send important updates and notifications''',
            ),
            
            _buildSection(
              '3. Data Storage and Security',
              '''• All data is securely stored in Google Firebase
• We use industry-standard encryption
• Your data is private and not shared with third parties
• Only you can access your business data
• We implement regular security updates''',
            ),
            
            _buildSection(
              '4. Data Retention',
              '''• Your data is retained as long as your account is active
• You can export or delete your data anytime
• Deleted data is permanently removed within 30 days
• Backup copies are retained for 90 days''',
            ),
            
            _buildSection(
              '5. Your Rights',
              '''You have the right to:

• Access your data at any time
• Export all your data (Backup feature)
• Request data deletion
• Update or correct your information
• Opt-out of non-essential communications''',
            ),
            
            _buildSection(
              '6. Third-Party Services',
              '''We use the following third-party services:

• Firebase (Google): Data storage and authentication
• Firebase Analytics: Usage statistics (anonymous)
• Firebase Crashlytics: Error reporting
• Google Cloud: PDF generation and storage

These services have their own privacy policies.''',
            ),
            
            _buildSection(
              '7. Data Sharing',
              '''We DO NOT:

• Sell your data to anyone
• Share your business information
• Use your data for advertising
• Access your data without permission

We ONLY share data when:

• Required by law
• You explicitly request it
• Emergency security situations''',
            ),
            
            _buildSection(
              '8. Children\'s Privacy',
              '''FinzoBilling is not intended for users under 18 years of age. We do not knowingly collect data from children.''',
            ),
            
            _buildSection(
              '9. Changes to Privacy Policy',
              '''We may update this policy from time to time. Changes will be notified through the app. Continued use after changes means you accept the new policy.''',
            ),
            
            _buildSection(
              '10. Contact Us',
              '''For privacy concerns or questions:

Email: support@finzobilling.com
Address: [Your Business Address]

We respond to all requests within 48 hours.''',
            ),
            
            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.security, size: 48, color: Colors.blue.shade700),
                  const SizedBox(height: 12),
                  Text(
                    'Your Privacy Matters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We take your privacy seriously and are committed to protecting your business data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade800,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
