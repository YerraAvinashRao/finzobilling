  // lib/pnl_report_screen.dart

  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/material.dart';
  import 'package:intl/intl.dart';

  enum ReportPeriod { thisMonth, lastMonth, thisQuarter }

  class PnlReportScreen extends StatefulWidget {
    const PnlReportScreen({super.key});

    @override
    State<PnlReportScreen> createState() => _PnlReportScreenState();
  }

  class _PnlReportScreenState extends State<PnlReportScreen> {
    ReportPeriod _selectedPeriod = ReportPeriod.thisMonth;
    bool _isLoading = false;
    
    double _revenue = 0.0;
    double _cogs = 0.0;
    double _grossProfit = 0.0;
    double _expenses = 0.0;
    double _netProfit = 0.0;

    @override
    void initState() {
      super.initState();
      _generateReport();
    }

    Future<void> _generateReport() async {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if(mounted) setState(() => _isLoading = false);
        return;
      }

      // Determine Date Range
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      switch (_selectedPeriod) {
        case ReportPeriod.thisMonth:
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 1);
          break;
        case ReportPeriod.lastMonth:
          startDate = DateTime(now.year, now.month - 1, 1);
          endDate = DateTime(now.year, now.month, 1);
          break;
        case ReportPeriod.thisQuarter:
          int quarter = (now.month - 1) ~/ 3 + 1;
          startDate = DateTime(now.year, (quarter - 1) * 3 + 1, 1);
          endDate = DateTime(now.year, quarter * 3 + 1, 1);
          break;
      }
      
      // *** THE FIX IS HERE: Get a reference to the user's document first ***
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      try {
        final results = await Future.wait([
          // Query the 'invoices' subcollection
          userDocRef.collection('invoices').where('status', isEqualTo: 'Paid').where('createdAt', isGreaterThanOrEqualTo: startDate).where('createdAt', isLessThan: endDate).get(),
          // Query the 'purchases' subcollection
          userDocRef.collection('purchases').get(), // Get all for average cost
          // Query the 'expenses' subcollection
          userDocRef.collection('expenses').where('date', isGreaterThanOrEqualTo: startDate).where('date', isLessThan: endDate).get(),
        ]);

        final paidInvoices = results[0].docs;
        final allPurchases = results[1].docs;
        final periodExpenses = results[2].docs;

        // --- CALCULATIONS ---

        // 1. Revenue
        final double revenue = paidInvoices.fold(0.0, (sum, doc) => sum + ((doc.data()['totalAmount'] as num?)?.toDouble() ?? 0.0));

        // 2. Cost of Goods Sold (COGS) - Using Average Cost Method
        final Map<String, List<double>> purchasePrices = {};
        for (var purchase in allPurchases) {
          final items = (purchase.data()['lineItems'] as List<dynamic>?) ?? [];
          for (var item in items) {
            final name = item['productName'] as String;
            final cost = (item['costPrice'] as num?)?.toDouble() ?? 0.0;
            purchasePrices.putIfAbsent(name, () => []).add(cost);
          }
        }
        final Map<String, double> averageCosts = purchasePrices.map((key, value) {
          final avg = value.isEmpty ? 0.0 : value.reduce((a, b) => a + b) / value.length;
          return MapEntry(key, avg);
        });

        double cogs = 0.0;
        for (var invoice in paidInvoices) {
          final items = (invoice.data()['lineItems'] as List<dynamic>?) ?? [];
          for (var item in items) {
            final name = item['productName'] as String;
            final qty = (item['quantity'] as num?)?.toInt() ?? 0;
            cogs += (averageCosts[name] ?? 0.0) * qty;
          }
        }

        // 3. Expenses
        final double expenses = periodExpenses.fold(0.0, (sum, doc) => sum + ((doc.data()['amount'] as num?)?.toDouble() ?? 0.0));
        
        if (mounted) {
          setState(() {
            _revenue = revenue;
            _cogs = cogs;
            _grossProfit = revenue - cogs;
            _expenses = expenses;
            _netProfit = _grossProfit - expenses;
            _isLoading = false;
          });
        }
      } catch(e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate report: $e')));
        }
      }
    }

    @override
    Widget build(BuildContext context) {
      final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
      
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profit & Loss'),
        ),
        body: Column(
          children: [
            // Date Filter
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Theme.of(context).cardColor,
              child: SegmentedButton<ReportPeriod>(
                segments: const [
                  ButtonSegment(value: ReportPeriod.thisMonth, label: Text('This Month')),
                  ButtonSegment(value: ReportPeriod.lastMonth, label: Text('Last Month')),
                  ButtonSegment(value: ReportPeriod.thisQuarter, label: Text('This Quarter')),
                ],
                selected: {_selectedPeriod},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedPeriod = newSelection.first;
                    _generateReport();
                  });
                },
              ),
            ),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildPnlRow('Revenue', _revenue, isPositive: true),
                        _buildPnlRow('Cost of Goods Sold', _cogs, isNegative: true),
                        const Divider(),
                        _buildPnlRow('Gross Profit', _grossProfit, isTotal: true),
                        const SizedBox(height: 24),
                        _buildPnlRow('Operating Expenses', _expenses, isNegative: true),
                        const Divider(),
                        _buildPnlRow('Net Profit', _netProfit, isTotal: true, isFinal: true),
                      ],
                    ),
            ),
          ],
        ),
      );
    }

    Widget _buildPnlRow(String title, double value, {bool isPositive = false, bool isNegative = false, bool isTotal = false, bool isFinal = false}) {
      final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
      Color valueColor = Theme.of(context).colorScheme.onSurface;
      if(isPositive || (isTotal && value >= 0)) valueColor = Colors.green;
      if(isNegative || (isTotal && value < 0)) valueColor = Colors.red;

      return Padding(
        padding: EdgeInsets.symmetric(vertical: isFinal ? 12 : 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: isTotal ? 18 : 16, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
            Text(
              currencyFormat.format(value),
              style: TextStyle(fontSize: isTotal ? 18 : 16, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: valueColor),
            ),
          ],
        ),
      );
    }
  }