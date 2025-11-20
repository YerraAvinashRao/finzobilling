// GSTR-1A Data Generator and JSON Exporter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GSTR1AGenerator {
  /// Generate GSTR-1A data for a specific month
  static Future<Map<String, dynamic>> generateGSTR1A({
    required DateTime month,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    // Get business GSTIN
    final businessDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('business_settings')
        .doc('details')
        .get();
    
    final gstin = businessDoc.data()?['gstin'] ?? '';

    // ✅ Fetch invoices that need GSTR-1A
    // These are invoices created/amended AFTER GSTR-1 was filed for this period
    final amendmentsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('invoices')
        .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where('needsGSTR1A', isEqualTo: true) // ✅ Flag we'll add
        .get();

    // Categorize amendments
    List<Map<String, dynamic>> b2bAmendments = [];
    List<Map<String, dynamic>> b2cLargeAmendments = [];
    List<Map<String, dynamic>> b2cSmallAmendments = [];

    double totalAmendmentValue = 0;
    double totalCGST = 0;
    double totalSGST = 0;
    double totalIGST = 0;

    for (var doc in amendmentsSnapshot.docs) {
      final data = doc.data();
      final clientGstin = data['clientGstin'] ?? '';
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
      final cgst = (data['cgst'] as num?)?.toDouble() ?? 0;
      final sgst = (data['sgst'] as num?)?.toDouble() ?? 0;
      final igst = (data['igst'] as num?)?.toDouble() ?? 0;

      final amendment = {
        'invoiceNumber': data['invoiceNumber'] ?? '',
        'invoiceDate': (data['invoiceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        'clientName': data['clientName'] ?? 'Unknown',
        'clientGstin': clientGstin,
        'taxableValue': (data['taxableValue'] as num?)?.toDouble() ?? 0,
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'totalAmount': totalAmount,
        'amendmentType': data['amendmentOf'] != null ? 'AMENDED' : 'NEW',
        'originalInvoice': data['amendmentOf'] ?? '',
      };

      totalAmendmentValue += totalAmount;
      totalCGST += cgst;
      totalSGST += sgst;
      totalIGST += igst;

      // Categorize
      if (clientGstin.isNotEmpty && clientGstin.length == 15) {
        b2bAmendments.add(amendment);
      } else if (totalAmount > 250000) {
        b2cLargeAmendments.add(amendment);
      } else {
        b2cSmallAmendments.add(amendment);
      }
    }

    return {
      'gstin': gstin,
      'period': DateFormat('MMM yyyy').format(month),
      'periodCode': DateFormat('MMyyyy').format(month),
      'b2b': {
        'amendments': b2bAmendments,
        'count': b2bAmendments.length,
      },
      'b2cLarge': {
        'amendments': b2cLargeAmendments,
        'count': b2cLargeAmendments.length,
      },
      'b2cSmall': {
        'amendments': b2cSmallAmendments,
        'count': b2cSmallAmendments.length,
      },
      'summary': {
        'totalAmendments': amendmentsSnapshot.docs.length,
        'totalValue': totalAmendmentValue,
        'totalCGST': totalCGST,
        'totalSGST': totalSGST,
        'totalIGST': totalIGST,
        'totalTax': totalCGST + totalSGST + totalIGST,
      },
    };
  }

  /// Export GSTR-1A as JSON for GST Portal
  static Map<String, dynamic> exportAsJSON(Map<String, dynamic> reportData) {
    final b2bAmendments = (reportData['b2b']['amendments'] as List<dynamic>?) ?? [];
    final b2cLargeAmendments = (reportData['b2cLarge']['amendments'] as List<dynamic>?) ?? [];
    final b2cSmallAmendments = (reportData['b2cSmall']['amendments'] as List<dynamic>?) ?? [];

    return {
      'gstin': reportData['gstin'],
      'fp': reportData['periodCode'],
      'b2b': b2bAmendments.map((inv) => {
        'ctin': inv['clientGstin'],
        'inv': [{
          'inum': inv['invoiceNumber'],
          'idt': DateFormat('dd-MM-yyyy').format(inv['invoiceDate']),
          'val': inv['totalAmount'],
          'pos': '19', // Gujarat - get from business settings
          'rchrg': 'N',
          'inv_typ': 'R',
          'itms': [{
            'num': 1,
            'itm_det': {
              'txval': inv['taxableValue'],
              'rt': _getTaxRate(inv),
              'iamt': inv['igst'],
              'camt': inv['cgst'],
              'samt': inv['sgst'],
              'csamt': 0,
            }
          }]
        }]
      }).toList(),
      'b2cl': b2cLargeAmendments.map((inv) => {
        'pos': '19',
        'inv': [{
          'inum': inv['invoiceNumber'],
          'idt': DateFormat('dd-MM-yyyy').format(inv['invoiceDate']),
          'val': inv['totalAmount'],
          'itms': [{
            'num': 1,
            'itm_det': {
              'txval': inv['taxableValue'],
              'rt': _getTaxRate(inv),
              'iamt': inv['igst'],
              'csamt': 0,
            }
          }]
        }]
      }).toList(),
      'b2cs': b2cSmallAmendments.isEmpty ? [] : [{
        'sply_ty': 'INTRA',
        'pos': '19',
        'typ': 'OE',
        'txval': b2cSmallAmendments.fold(0.0, (sum, inv) => sum + (inv['taxableValue'] as double)),
        'rt': 18, // Aggregate tax rate
        'iamt': 0,
        'camt': b2cSmallAmendments.fold(0.0, (sum, inv) => sum + (inv['cgst'] as double)),
        'samt': b2cSmallAmendments.fold(0.0, (sum, inv) => sum + (inv['sgst'] as double)),
        'csamt': 0,
      }],
    };
  }

  static double _getTaxRate(Map<String, dynamic> invoice) {
    final taxableValue = invoice['taxableValue'] as double;
    if (taxableValue == 0) return 0;
    
    final totalTax = (invoice['cgst'] as double) + 
                     (invoice['sgst'] as double) + 
                     (invoice['igst'] as double);
    
    return (totalTax / taxableValue) * 100;
  }

  /// Mark invoice as needing GSTR-1A
  static Future<void> markForGSTR1A(String invoiceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('invoices')
        .doc(invoiceId)
        .update({
      'needsGSTR1A': true,
      'markedForGSTR1AOn': Timestamp.now(),
    });
  }

  /// Clear GSTR-1A flag after successful export
  static Future<void> clearGSTR1AFlags(DateTime month) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final invoices = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('invoices')
        .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where('needsGSTR1A', isEqualTo: true)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in invoices.docs) {
      batch.update(doc.reference, {
        'needsGSTR1A': false,
        'includedInGSTR1A': true,
        'gstr1aExportedOn': Timestamp.now(),
      });
    }
    await batch.commit();
  }
}
