import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GSTRExportHelper {
  static Future<Map<String, dynamic>> generateGSTR2AData({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    // Fetch all purchases in date range
    final purchasesSnapshot = await userDocRef
        .collection('purchases')
        .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate))
        .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(toDate))
        .orderBy('invoiceDate')
        .get();

    List<Map<String, dynamic>> gstr2aEntries = [];
    double totalTaxableValue = 0;
    double totalCGST = 0;
    double totalSGST = 0;
    double totalIGST = 0;
    double totalITC = 0;

    for (var doc in purchasesSnapshot.docs) {
      final data = doc.data();
      
      final supplierGstin = data['supplierGstin'] ?? '';
      final invoiceNumber = data['invoiceNumber'] ?? '';
      final invoiceDate = (data['invoiceDate'] as Timestamp).toDate();
      final reverseCharge = data['reverseCharge'] as bool? ?? false;
      final itcEligible = data['itcEligible'] as bool? ?? true;
      final lineItems = (data['lineItems'] as List?) ?? [];

      double purchaseTaxableValue = 0;
      double purchaseCGST = 0;
      double purchaseSGST = 0;
      double purchaseIGST = 0;

      for (var item in lineItems) {
        final itemData = item as Map<String, dynamic>;
        final taxableValue = (itemData['totalCostValue'] as num?)?.toDouble() ?? 0;
        final cgst = (itemData['cgst'] as num?)?.toDouble() ?? 0;
        final sgst = (itemData['sgst'] as num?)?.toDouble() ?? 0;
        final igst = (itemData['igst'] as num?)?.toDouble() ?? 0;

        purchaseTaxableValue += taxableValue;
        purchaseCGST += (taxableValue * cgst / 100);
        purchaseSGST += (taxableValue * sgst / 100);
        purchaseIGST += (taxableValue * igst / 100);
      }

      totalTaxableValue += purchaseTaxableValue;
      totalCGST += purchaseCGST;
      totalSGST += purchaseSGST;
      totalIGST += purchaseIGST;

      if (itcEligible && !reverseCharge) {
        totalITC += (purchaseCGST + purchaseSGST + purchaseIGST);
      }

      gstr2aEntries.add({
        'supplierGstin': supplierGstin,
        'supplierName': data['supplierName'] ?? '',
        'invoiceNumber': invoiceNumber,
        'invoiceDate': DateFormat('dd/MM/yyyy').format(invoiceDate),
        'taxableValue': purchaseTaxableValue.toStringAsFixed(2),
        'cgst': purchaseCGST.toStringAsFixed(2),
        'sgst': purchaseSGST.toStringAsFixed(2),
        'igst': purchaseIGST.toStringAsFixed(2),
        'totalTax': (purchaseCGST + purchaseSGST + purchaseIGST).toStringAsFixed(2),
        'reverseCharge': reverseCharge ? 'Y' : 'N',
        'itcEligible': itcEligible ? 'Y' : 'N',
        'placeOfSupply': data['placeOfSupply'] ?? '',
      });
    }

    return {
      'period': '${DateFormat('MMM yyyy').format(fromDate)} - ${DateFormat('MMM yyyy').format(toDate)}',
      'totalRecords': gstr2aEntries.length,
      'totalTaxableValue': totalTaxableValue.toStringAsFixed(2),
      'totalCGST': totalCGST.toStringAsFixed(2),
      'totalSGST': totalSGST.toStringAsFixed(2),
      'totalIGST': totalIGST.toStringAsFixed(2),
      'totalITC': totalITC.toStringAsFixed(2),
      'entries': gstr2aEntries,
    };
  }

  static Future<String> exportToCSV({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final data = await generateGSTR2AData(fromDate: fromDate, toDate: toDate);
    final entries = data['entries'] as List<Map<String, dynamic>>;

    // CSV Header
    String csv = 'Supplier GSTIN,Supplier Name,Invoice Number,Invoice Date,'
        'Taxable Value,CGST,SGST,IGST,Total Tax,Reverse Charge,ITC Eligible,Place of Supply\n';

    // CSV Rows
    for (var entry in entries) {
      csv += '${entry['supplierGstin']},${entry['supplierName']},'
          '${entry['invoiceNumber']},${entry['invoiceDate']},'
          '${entry['taxableValue']},${entry['cgst']},${entry['sgst']},'
          '${entry['igst']},${entry['totalTax']},${entry['reverseCharge']},'
          '${entry['itcEligible']},${entry['placeOfSupply']}\n';
    }

    return csv;
  }

  // Helper to get tax summary by HSN
  static Future<List<Map<String, dynamic>>> getTaxSummaryByHSN({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    final purchasesSnapshot = await userDocRef
        .collection('purchases')
        .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate))
        .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(toDate))
        .get();

    Map<String, Map<String, double>> hsnSummary = {};

    for (var doc in purchasesSnapshot.docs) {
      final data = doc.data();
      final lineItems = (data['lineItems'] as List?) ?? [];

      for (var item in lineItems) {
        final itemData = item as Map<String, dynamic>;
        final hsn = (itemData['hsnSac'] ?? 'UNCLASSIFIED').toString();
        final taxableValue = (itemData['totalCostValue'] as num?)?.toDouble() ?? 0;
        final cgst = (itemData['cgst'] as num?)?.toDouble() ?? 0;
        final sgst = (itemData['sgst'] as num?)?.toDouble() ?? 0;
        final igst = (itemData['igst'] as num?)?.toDouble() ?? 0;

        if (!hsnSummary.containsKey(hsn)) {
          hsnSummary[hsn] = {
            'taxableValue': 0,
            'cgst': 0,
            'sgst': 0,
            'igst': 0,
            'totalTax': 0,
          };
        }

        hsnSummary[hsn]!['taxableValue'] = 
            (hsnSummary[hsn]!['taxableValue'] ?? 0) + taxableValue;
        hsnSummary[hsn]!['cgst'] = 
            (hsnSummary[hsn]!['cgst'] ?? 0) + (taxableValue * cgst / 100);
        hsnSummary[hsn]!['sgst'] = 
            (hsnSummary[hsn]!['sgst'] ?? 0) + (taxableValue * sgst / 100);
        hsnSummary[hsn]!['igst'] = 
            (hsnSummary[hsn]!['igst'] ?? 0) + (taxableValue * igst / 100);
        hsnSummary[hsn]!['totalTax'] = 
            (hsnSummary[hsn]!['totalTax'] ?? 0) + 
            (taxableValue * (cgst + sgst + igst) / 100);
      }
    }

    return hsnSummary.entries.map((entry) {
      return {
        'hsn': entry.key,
        'taxableValue': entry.value['taxableValue']!.toStringAsFixed(2),
        'cgst': entry.value['cgst']!.toStringAsFixed(2),
        'sgst': entry.value['sgst']!.toStringAsFixed(2),
        'igst': entry.value['igst']!.toStringAsFixed(2),
        'totalTax': entry.value['totalTax']!.toStringAsFixed(2),
      };
    }).toList();
  }
}
