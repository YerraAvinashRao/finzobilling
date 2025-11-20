import 'package:flutter/material.dart';
import 'package:finzobilling/gstr3b_screen.dart';
import 'package:finzobilling/gstr_report_screen.dart';
import 'package:finzobilling/screens/gstr1_screen.dart';
import 'package:finzobilling/screens/hsn_summary_screen.dart';
import 'package:finzobilling/screens/gst_dashboard_screen.dart';
import 'package:finzobilling/screens/gstr1a_screen.dart';

// Premium colors
const Color appleBackground = Color(0xFFF2F2F7);
const Color appleCard = Color(0xFFFFFFFF);
const Color appleAccent = Color(0xFF007AFF);

class GSTReportsHubScreen extends StatelessWidget {
  const GSTReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appleBackground,
      appBar: AppBar(
        title: const Text(
          'GST Reports',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Header Card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo, Colors.indigo.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🇮🇳 GST Compliance Center',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Generate accurate GST returns for filing',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // GST Dashboard
            _buildReportCard(
              context,
              icon: Icons.dashboard_rounded,
              title: 'GST Dashboard',
              description: 'Overview of all GST activities',
              color: Colors.blue,
              screen: const GSTDashboardScreen(),
            ),

            const SizedBox(height: 12),

            // GSTR-3B (Most Critical!)
            _buildReportCard(
              context,
              icon: Icons.payment_rounded,
              title: 'GSTR-3B - Monthly Return',
              description: '⚠️ FILE BY 20TH! Tax payment summary',
              color: Colors.red,
              screen: const GSTR3BScreen(),
              isCritical: true,
            ),

            const SizedBox(height: 12),

            // GSTR-1
            _buildReportCard(
              context,
              icon: Icons.trending_up_rounded,
              title: 'GSTR-1 - Sales Return',
              description: 'Outward supplies (B2B, B2C) details',
              color: Colors.green,
              screen: const GSTR1Screen(),
            ),

            const SizedBox(height: 12),

            // GSTR-2A
            _buildReportCard(
              context,
              icon: Icons.trending_down_rounded,
              title: 'GSTR-2A - Purchase ITC',
              description: 'Input tax credit from suppliers',
              color: Colors.orange,
              screen: const GSTRReportScreen(),
            ),

            // GSTR-1A
            _buildReportCard(
              context,
              icon: Icons.edit_document,
              title: 'GSTR-1A - Amendments',
              description: 'Fix errors after filing GSTR-1',
              color: Colors.purple,
              screen: const GSTR1AScreen(),
            ),

            const SizedBox(height: 12),

            // HSN Summary
            _buildReportCard(
              context,
              icon: Icons.category_rounded,
              title: 'HSN Summary',
              description: 'Product-wise tax breakdown',
              color: Colors.purple,
              screen: HSNSummaryReportScreen(),
            ),

            const SizedBox(height: 24),

            // Important Dates Card
            Container(
              decoration: BoxDecoration(
                color: appleCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.3), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.amber.shade700,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Important GST Dates',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDateRow('GSTR-1', '11th of next month', false),
                    _buildDateRow('GSTR-3B', '20th of next month', true),
                    _buildDateRow('GSTR-9', '31st December (Annual)', false),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Late Fee: ₹50/day (CGST) + ₹50/day (SGST)\nInterest: 18% p.a. on delayed payment',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Widget screen,
    bool isCritical = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isCritical ? Colors.red.withOpacity(0.15) : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: isCritical
              ? BorderSide(color: Colors.red.shade300, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [color.withOpacity(0.08), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isCritical) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'URGENT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(String report, String date, bool isCritical) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.shade50 : appleBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCritical ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isCritical ? Colors.red : Colors.amber.shade700,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              report,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isCritical ? Colors.red.shade900 : Colors.black87,
              ),
            ),
          ),
          Text(
            date,
            style: TextStyle(
              color: isCritical ? Colors.red.shade700 : Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
