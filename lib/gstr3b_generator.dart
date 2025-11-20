// lib/services/gstr3b_generator.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class GSTR3BGenerator {
  /// Generate GSTR-3B for a specific month
  /// This is the MOST CRITICAL GST return - filed monthly to pay tax
  static Future<Map<String, dynamic>> generateGSTR3B({
    required DateTime month,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    // Get start and end of month
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    debugPrint('🔍 Generating GSTR-3B for ${DateFormat('MMM yyyy').format(month)}');
    debugPrint('📅 Period: ${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(endDate)}');

    try {
      // ✅ Fetch invoices (outward supplies - Sales)
      final invoicesSnapshot = await userDocRef
          .collection('invoices')
          .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('status', whereIn: ['Paid', 'Unpaid', 'Partially Paid'])
          .get();

      // ✅ NEW: Filter out amended invoices (they're replaced by corrected ones)
      final validInvoices = invoicesSnapshot.docs.where((doc) {
        final data = doc.data();
        final isAmended = data['isAmended'] as bool? ?? false;
        return !isAmended; // Exclude amended originals
      }).toList();

      // ✅ Fetch purchases (inward supplies - for ITC)
      final purchasesSnapshot = await userDocRef
          .collection('purchases')
          .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      // ✅ Fetch credit notes (reduce output tax)
      final creditNotesSnapshot = await userDocRef
          .collection('credit_notes')
          .where('creditNoteDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('creditNoteDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      // ✅ UPDATED: Log with valid count
      debugPrint('📊 Found ${invoicesSnapshot.docs.length} invoices (${validInvoices.length} valid after excluding amended), ${purchasesSnapshot.docs.length} purchases, ${creditNotesSnapshot.docs.length} credit notes');

      // ============================================
      // SECTION 3.1: OUTWARD SUPPLIES (SALES)
      // ============================================
      double totalTaxableValue = 0;
      double totalCGST = 0;
      double totalSGST = 0;
      double totalIGST = 0;
      double totalCess = 0;

      // ✅ UPDATED: Process VALID invoices only (exclude amended)
      for (var doc in validInvoices) {
        final data = doc.data();
        if (data['status'] == 'Void') continue;

        final items = data['items'] as List<dynamic>? ?? [];
        
        for (var item in items) {
          final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
          final price = (item['price'] as num?)?.toDouble() ?? 0;
          final taxRate = (item['taxRate'] ?? item['gstRate'] as num?)?.toDouble() ?? 0;
          
          final itemValue = quantity * price;
          final itemTax = itemValue * (taxRate / 100);
          
          totalTaxableValue += itemValue;
          
          // Check if inter-state or intra-state
          final igstValue = (data['igst'] as num?)?.toDouble() ?? 0;
          final isInterState = igstValue > 0;
          
          if (isInterState) {
            totalIGST += itemTax;
          } else {
            totalCGST += itemTax / 2;
            totalSGST += itemTax / 2;
          }
        }
        
        totalCess += (data['cess'] as num?)?.toDouble() ?? 0;
      }

      // ✅ Deduct Credit Notes from Output Tax
      double creditNoteCGST = 0;
      double creditNoteSGST = 0;
      double creditNoteIGST = 0;
      double creditNoteTaxableValue = 0;

      for (var doc in creditNotesSnapshot.docs) {
        final data = doc.data();
        final totalReturn = (data['totalReturnAmount'] as num?)?.toDouble() ?? 0;
        final cgst = (data['cgst'] as num?)?.toDouble() ?? 0;
        final sgst = (data['sgst'] as num?)?.toDouble() ?? 0;
        final igst = (data['igst'] as num?)?.toDouble() ?? 0;

        creditNoteTaxableValue += (totalReturn - cgst - sgst - igst);
        creditNoteCGST += cgst;
        creditNoteSGST += sgst;
        creditNoteIGST += igst;
      }

      // Net output tax (after credit notes)
      final netTaxableValue = totalTaxableValue - creditNoteTaxableValue;
      final netOutputCGST = totalCGST - creditNoteCGST;
      final netOutputSGST = totalSGST - creditNoteSGST;
      final netOutputIGST = totalIGST - creditNoteIGST;

      // ============================================
      // SECTION 3.2: INWARD SUPPLIES (ITC)
      // ============================================
      double itcCGST = 0;
      double itcSGST = 0;
      double itcIGST = 0;
      double itcCess = 0;
      double purchaseTaxableValue = 0;

      for (var doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final itcEligible = data['itcEligible'] as bool? ?? true;
        final reverseCharge = data['reverseCharge'] as bool? ?? false;

        // Only claim ITC if eligible and not reverse charge
        if (itcEligible && !reverseCharge) {
          final lineItems = (data['lineItems'] as List?) ?? [];
          
          for (var item in lineItems) {
            final costPrice = (item['costPrice'] as num?)?.toDouble() ?? 0;
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
            final taxableValue = costPrice * quantity;
            
            final cgstRate = (item['cgst'] as num?)?.toDouble() ?? 0;
            final sgstRate = (item['sgst'] as num?)?.toDouble() ?? 0;
            final igstRate = (item['igst'] as num?)?.toDouble() ?? 0;

            purchaseTaxableValue += taxableValue;
            
            // Calculate ITC amounts
            itcCGST += taxableValue * (cgstRate / 100);
            itcSGST += taxableValue * (sgstRate / 100);
            itcIGST += taxableValue * (igstRate / 100);
          }
        }
      }

      // ============================================
      // SECTION 4: TAX PAYABLE (or REFUND)
      // ============================================
      final netCGST = netOutputCGST - itcCGST;
      final netSGST = netOutputSGST - itcSGST;
      final netIGST = netOutputIGST - itcIGST;
      final netCess = totalCess - itcCess;

      // Split into payable vs refund
      final taxPayableCGST = netCGST > 0 ? netCGST : 0;
      final taxPayableSGST = netSGST > 0 ? netSGST : 0;
      final taxPayableIGST = netIGST > 0 ? netIGST : 0;
      final taxPayableCess = netCess > 0 ? netCess : 0;

      final itcRefundCGST = netCGST < 0 ? netCGST.abs() : 0;
      final itcRefundSGST = netSGST < 0 ? netSGST.abs() : 0;
      final itcRefundIGST = netIGST < 0 ? netIGST.abs() : 0;
      final itcRefundCess = netCess < 0 ? netCess.abs() : 0;

      final totalTaxPayable = taxPayableCGST + taxPayableSGST + taxPayableIGST + taxPayableCess;
      final totalRefund = itcRefundCGST + itcRefundSGST + itcRefundIGST + itcRefundCess;

      debugPrint('💰 Tax Payable: ₹${totalTaxPayable.toStringAsFixed(2)}');
      debugPrint('💚 ITC Refund: ₹${totalRefund.toStringAsFixed(2)}');

      // ============================================
      // RETURN COMPLETE GSTR-3B DATA
      // ============================================
      return {
        'month': DateFormat('MMM yyyy').format(month),
        'monthYear': month,
        'generatedAt': DateTime.now(),
        
        // Section 3.1: Outward Supplies (Sales)
        'outwardSupplies': {
          'taxableValue': _round(netTaxableValue),
          'cgst': _round(netOutputCGST),
          'sgst': _round(netOutputSGST),
          'igst': _round(netOutputIGST),
          'cess': _round(totalCess),
          'totalTax': _round(netOutputCGST + netOutputSGST + netOutputIGST + totalCess),
        },
        
        // Section 3.2: ITC Available (Purchases)
        'itcAvailable': {
          'taxableValue': _round(purchaseTaxableValue),
          'cgst': _round(itcCGST),
          'sgst': _round(itcSGST),
          'igst': _round(itcIGST),
          'cess': _round(itcCess),
          'total': _round(itcCGST + itcSGST + itcIGST + itcCess),
        },
        
        // Section 4: Tax Payable
        'taxPayable': {
          'cgst': _round(taxPayableCGST),
          'sgst': _round(taxPayableSGST),
          'igst': _round(taxPayableIGST),
          'cess': _round(taxPayableCess),
          'total': _round(totalTaxPayable),
        },
        
        // ITC Refund (if ITC > Output Tax)
        'itcRefund': {
          'cgst': _round(itcRefundCGST),
          'sgst': _round(itcRefundSGST),
          'igst': _round(itcRefundIGST),
          'cess': _round(itcRefundCess),
          'total': _round(totalRefund),
        },
        
        // Credit Notes Info
        'creditNotes': {
          'count': creditNotesSnapshot.docs.length,
          'totalAmount': _round(creditNoteTaxableValue),
          'cgst': _round(creditNoteCGST),
          'sgst': _round(creditNoteSGST),
          'igst': _round(creditNoteIGST),
        },
        
        // Summary
        'summary': {
          'totalInvoices': validInvoices.length, // ✅ UPDATED: Use valid count
          'totalPurchases': purchasesSnapshot.docs.length,
          'totalCreditNotes': creditNotesSnapshot.docs.length,
          'amendedInvoices': invoicesSnapshot.docs.length - validInvoices.length, // ✅ NEW: Track amended
          'netTaxPosition': _round(totalTaxPayable - totalRefund),
          'status': totalTaxPayable > totalRefund ? 'TAX_PAYABLE' : 'REFUND_DUE',
        },
      };
    } catch (e) {
      debugPrint('❌ Error generating GSTR-3B: $e');
      throw Exception('Failed to generate GSTR-3B: $e');
    }
  }

  /// Round to 2 decimal places
  static double _round(num value) {
    return double.parse(value.toStringAsFixed(2));
  }

  /// Export GSTR-3B as JSON (for GST portal upload)
  static Map<String, dynamic> exportAsJSON(Map<String, dynamic> gstr3bData, String gstin) {
    return {
      'gstin': gstin,
      'ret_period': DateFormat('MMyyyy').format(gstr3bData['monthYear']),
      'version': 'GST3B',
      
      // Section 3.1: Outward Supplies
      'sup_details': {
        'osup_det': {
          'txval': gstr3bData['outwardSupplies']['taxableValue'],
          'iamt': gstr3bData['outwardSupplies']['igst'],
          'camt': gstr3bData['outwardSupplies']['cgst'],
          'samt': gstr3bData['outwardSupplies']['sgst'],
          'csamt': gstr3bData['outwardSupplies']['cess'],
        },
      },
      
      // Section 4: Tax Payable
      'intr_details': {
        'intr_det': {
          'iamt': gstr3bData['taxPayable']['igst'],
          'camt': gstr3bData['taxPayable']['cgst'],
          'samt': gstr3bData['taxPayable']['sgst'],
          'csamt': gstr3bData['taxPayable']['cess'],
        },
      },
      
      // Section 3.2: ITC
      'itc_elg': {
        'itc_avl': [{
          'ty': 'IMPG',
          'iamt': gstr3bData['itcAvailable']['igst'],
          'camt': gstr3bData['itcAvailable']['cgst'],
          'samt': gstr3bData['itcAvailable']['sgst'],
          'csamt': gstr3bData['itcAvailable']['cess'],
        }],
      },
    };
  }
}
