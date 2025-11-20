// lib/screens/amend_invoice_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:finzobilling/services/amendment_helper.dart';
import 'package:finzobilling/create_invoice_screen.dart';

// Premium colors
const Color appleBackground = Color(0xFFF2F2F7);
const Color appleCard = Color(0xFFFFFFFF);
const Color appleAccent = Color(0xFF007AFF);

class AmendInvoiceScreen extends StatefulWidget {
  final String invoiceId;
  final Map<String, dynamic> originalInvoice;

  const AmendInvoiceScreen({
    super.key,
    required this.invoiceId,
    required this.originalInvoice,
  });

  @override
  State<AmendInvoiceScreen> createState() => _AmendInvoiceScreenState();
}

class _AmendInvoiceScreenState extends State<AmendInvoiceScreen> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _amendmentHistory = [];

  @override
  void initState() {
    super.initState();
    _loadAmendmentHistory();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadAmendmentHistory() async {
    final history = await AmendmentHelper.getAmendmentHistory(widget.invoiceId);
    if (mounted) {
      setState(() => _amendmentHistory = history);
    }
  }

  Future<bool> _willNeedGSTR1A() async {
    final invoiceDate = (widget.originalInvoice['invoiceDate'] as Timestamp).toDate();
    return await AmendmentHelper.isGSTR1Filed(invoiceDate);
  }

  Future<void> _proceedToEdit() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please provide a reason for amendment'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Navigate to CreateInvoiceScreen with EDITABLE data
    final editedData = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateInvoiceScreen(
          editMode: true,
          invoiceData: widget.originalInvoice,
          isAmendment: true,
        ),
      ),
    );

    // If user saved edited data, create amendment
    if (editedData != null && mounted) {
      setState(() => _isLoading = true);

      try {
        await AmendmentHelper.createAmendment(
          originalInvoiceId: widget.invoiceId,
          originalData: widget.originalInvoice,
          amendedData: editedData,
          amendmentReason: _reasonController.text.trim(),
        );

        if (mounted) {
          Navigator.pop(context, true);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Amendment created successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Amendment cancelled'),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final canAmend = AmendmentHelper.canAmend(widget.originalInvoice);

    return Scaffold(
      backgroundColor: appleBackground,
      appBar: AppBar(
        title: const Text(
          'Amend Invoice',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original Invoice Card (Premium)
            Container(
              decoration: BoxDecoration(
                color: appleCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Colors.blue, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Original Invoice',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('Invoice Number', widget.originalInvoice['invoiceNumber'], Icons.tag_rounded),
                    _buildInfoRow(
                      'Date',
                      DateFormat('dd/MM/yyyy').format(
                        (widget.originalInvoice['invoiceDate'] as Timestamp).toDate(),
                      ),
                      Icons.calendar_today_rounded,
                    ),
                    _buildInfoRow('Client', widget.originalInvoice['clientName'] ?? 'N/A', Icons.person_rounded),
                    _buildInfoRow('Amount', currency.format(widget.originalInvoice['totalAmount']), Icons.currency_rupee_rounded),
                    
                    if (widget.originalInvoice['isAmended'] == true)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade100, Colors.orange.shade50],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_rounded, color: Colors.orange, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This invoice has already been amended',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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

            // Amendment History (Premium)
            if (_amendmentHistory.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history_rounded, color: Colors.purple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Amendment History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._amendmentHistory.map((amendment) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: appleCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_document, color: Colors.blue, size: 20),
                    ),
                    title: Text(
                      amendment['amendmentType'] ?? 'Amendment',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Date: ${DateFormat('dd/MM/yyyy HH:mm').format((amendment['amendmentDate'] as Timestamp).toDate())}\n'
                        'Reason: ${amendment['amendmentReason']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5),
                      ),
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // Reason Input (Premium)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Amendment Reason *',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: appleCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _reasonController,
                maxLines: 4,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g., Wrong amount entered, Client name correction, Tax rate error, etc.',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: appleCard,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // GSTR-1A Detection Alert (Premium)
            FutureBuilder<bool>(
              future: _willNeedGSTR1A(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple.shade400, Colors.purple.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.info_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🔔 GSTR-1 Already Filed!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'This amendment will require GSTR-1A filing',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Warning Card (Premium)
            Container(
              decoration: BoxDecoration(
                color: appleCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.3), width: 2),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Important Notes',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: appleBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• Original invoice will be marked as "Amended"', style: TextStyle(fontSize: 13, height: 1.6)),
                        Text('• You will edit the invoice to fix errors', style: TextStyle(fontSize: 13, height: 1.6)),
                        Text('• A new corrected invoice will be created', style: TextStyle(fontSize: 13, height: 1.6)),
                        Text('• Amendment must be reported in next GSTR-1', style: TextStyle(fontSize: 13, height: 1.6)),
                        Text('• Keep proper documentation for audit', style: TextStyle(fontSize: 13, height: 1.6)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Proceed Button (Premium)
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: canAmend ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ] : [],
              ),
              child: ElevatedButton.icon(
                onPressed: canAmend && !_isLoading ? _proceedToEdit : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.edit_rounded, size: 22),
                label: Text(
                  _isLoading ? 'Creating Amendment...' : 'Proceed to Edit Invoice',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAmend ? Colors.orange : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            if (!canAmend)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This invoice cannot be amended (already amended or too old)',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
