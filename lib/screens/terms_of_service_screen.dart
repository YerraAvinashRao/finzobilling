import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Terms of Service',
              'Last updated: ${DateTime.now().year}',
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              '1. Acceptance of Terms',
              '''By using FinzoBilling, you agree to these Terms of Service. If you don't agree, please don't use the app.

These terms apply to all users of the application.''',
            ),
            
            _buildSection(
              '2. Use of Service',
              '''You agree to:

• Use the app for lawful business purposes only
• Provide accurate business information
• Maintain the security of your account
• Comply with all applicable GST and tax laws
• Not misuse or attempt to hack the service
• Not share your account credentials''',
            ),
            
            _buildSection(
              '3. Account Responsibilities',
              '''You are responsible for:

• All activity under your account
• Keeping your password secure
• Accuracy of data you enter
• Compliance with tax regulations
• Backing up your important data
• Notifying us of unauthorized access''',
            ),
            
            _buildSection(
              '4. Service Availability',
              '''We strive to provide 99.9% uptime, but:

• Service may be interrupted for maintenance
• We don't guarantee uninterrupted access
• Features may change with updates
• We may suspend accounts violating terms
• Emergency maintenance may occur''',
            ),
            
            _buildSection(
              '5. Data and Content',
              '''Your data remains yours:

• You own all data you create
• We don't claim rights to your business data
• You can export your data anytime
• You're responsible for data accuracy
• You grant us license to store and process your data''',
            ),
            
            _buildSection(
              '6. Intellectual Property',
              '''FinzoBilling and its features are protected:

• App design and code are our property
• You can't copy or redistribute the app
• Our trademarks are protected
• You get a license to use, not own
• Third-party libraries have their own licenses''',
            ),
            
            _buildSection(
              '7. Limitations of Liability',
              '''We are not liable for:

• Errors in GST calculations (verify yourself)
• Lost business due to app downtime
• Data loss (backup your data!)
• Indirect or consequential damages
• Third-party service failures
• Tax penalties due to app usage

Maximum liability: Amount you paid for the service.''',
            ),
            
            _buildSection(
              '8. GST Compliance Disclaimer',
              '''Important:

• FinzoBilling helps with GST compliance
• YOU are responsible for correct tax filing
• Always verify reports before submission
• Consult a tax professional if unsure
• We don't provide tax advice
• Check all calculations independently''',
            ),
            
            _buildSection(
              '9. Pricing and Payments',
              '''Current version is free, but:

• We may introduce paid features
• Pricing will be clearly communicated
• 30-day notice before charging
• You can cancel before charges apply
• Refund policy will be provided''',
            ),
            
            _buildSection(
              '10. Account Termination',
              '''We may terminate accounts that:

• Violate these terms
• Engage in illegal activities
• Abuse the service
• Remain inactive for 2 years

You can delete your account anytime in Settings.''',
            ),
            
            _buildSection(
              '11. Updates and Changes',
              '''We may update:

• These terms (with notice)
• App features and functionality
• Pricing structure
• Service offerings

Continued use means acceptance of changes.''',
            ),
            
            _buildSection(
              '12. Support and Contact',
              '''For support:

Email: support@finzobilling.com
Response time: Within 48 hours
Available: Monday-Saturday, 9 AM - 6 PM IST''',
            ),
            
            _buildSection(
              '13. Governing Law',
              '''These terms are governed by Indian law. Any disputes will be resolved in courts of [Your City], India.''',
            ),
            
            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'By using FinzoBilling, you agree to these Terms of Service and our Privacy Policy.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
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
