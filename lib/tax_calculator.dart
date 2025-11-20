class TaxCalculator {
  /// Calculate tax breakdown based on business state and client state
  /// 
  /// Returns:
  /// - CGST + SGST if same state (intra-state)
  /// - IGST if different states (inter-state)
  static Map<String, double> calculateGST({
    required String businessState,
    required String clientState,
    required double taxableAmount,
    required double taxRate, // Total tax rate (e.g., 0.18 for 18%)
  }) {
    final isSameState = businessState.trim().toLowerCase() == 
                        clientState.trim().toLowerCase();

    if (isSameState) {
      // Intra-state: Split into CGST + SGST
      final halfRate = taxRate / 2;
      return {
        'cgst': taxableAmount * halfRate,
        'sgst': taxableAmount * halfRate,
        'igst': 0.0,
        'cgstRate': halfRate * 100, // Convert to percentage
        'sgstRate': halfRate * 100,
        'igstRate': 0.0,
        'totalTax': taxableAmount * taxRate,
      };
    } else {
      // Inter-state: IGST only
      return {
        'cgst': 0.0,
        'sgst': 0.0,
        'igst': taxableAmount * taxRate,
        'cgstRate': 0.0,
        'sgstRate': 0.0,
        'igstRate': taxRate * 100,
        'totalTax': taxableAmount * taxRate,
      };
    }
  }

  /// Get common GST rates in India
  static List<Map<String, dynamic>> getCommonGSTRates() {
    return [
      {'label': '0% (Nil Rated)', 'rate': 0.00},
      {'label': '0.25% (Precious Stones)', 'rate': 0.0025},
      {'label': '3% (Gold, Silver)', 'rate': 0.03},
      {'label': '5% (Essential Goods)', 'rate': 0.05},
      {'label': '12% (Standard Rate)', 'rate': 0.12},
      {'label': '18% (Standard Rate)', 'rate': 0.18},
      {'label': '28% (Luxury Items)', 'rate': 0.28},
    ];
  }

  /// Validate GST rate
  static bool isValidGSTRate(double rate) {
    final validRates = [0.00, 0.0025, 0.03, 0.05, 0.12, 0.18, 0.28];
    return validRates.contains(rate);
  }

  /// Calculate line item tax
  static Map<String, double> calculateLineItemTax({
    required double quantity,
    required double unitPrice,
    required double taxRate,
    required String businessState,
    required String clientState,
  }) {
    final taxableAmount = quantity * unitPrice;
    final taxBreakdown = calculateGST(
      businessState: businessState,
      clientState: clientState,
      taxableAmount: taxableAmount,
      taxRate: taxRate,
    );

    return {
      'taxableAmount': taxableAmount,
      ...taxBreakdown,
      'lineTotal': taxableAmount + taxBreakdown['totalTax']!,
    };
  }

  /// Calculate invoice totals from line items
  static Map<String, double> calculateInvoiceTotals(
    List<Map<String, dynamic>> lineItems,
  ) {
    double totalTaxable = 0;
    double totalCGST = 0;
    double totalSGST = 0;
    double totalIGST = 0;

    for (var item in lineItems) {
      totalTaxable += (item['taxableAmount'] as num?)?.toDouble() ?? 0.0;
      totalCGST += (item['cgst'] as num?)?.toDouble() ?? 0.0;
      totalSGST += (item['sgst'] as num?)?.toDouble() ?? 0.0;
      totalIGST += (item['igst'] as num?)?.toDouble() ?? 0.0;
    }

    final totalTax = totalCGST + totalSGST + totalIGST;
    final grandTotal = totalTaxable + totalTax;

    return {
      'taxableValue': totalTaxable,
      'cgst': totalCGST,
      'sgst': totalSGST,
      'igst': totalIGST,
      'totalTax': totalTax,
      'grandTotal': grandTotal,
      'roundOff': grandTotal.roundToDouble() - grandTotal,
      'finalAmount': grandTotal.roundToDouble(),
    };
  }

  /// Format GST number with dashes for display
  static String formatGSTIN(String gstin) {
    if (gstin.length != 15) return gstin;
    return '${gstin.substring(0, 2)}-${gstin.substring(2, 7)}-${gstin.substring(7, 11)}-${gstin.substring(11, 12)}-${gstin.substring(12, 14)}-${gstin.substring(14, 15)}';
  }

  /// Validate GSTIN format
  static bool isValidGSTIN(String gstin) {
    if (gstin.length != 15) return false;
    final regex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    return regex.hasMatch(gstin);
  }

  /// Extract state code from GSTIN
  static String? getStateCodeFromGSTIN(String gstin) {
    if (gstin.length < 2) return null;
    return gstin.substring(0, 2);
  }

  /// Get state name from state code
  static String? getStateFromCode(String stateCode) {
    final Map<String, String> stateCodes = {
      '01': 'Jammu and Kashmir',
      '02': 'Himachal Pradesh',
      '03': 'Punjab',
      '04': 'Chandigarh',
      '05': 'Uttarakhand',
      '06': 'Haryana',
      '07': 'Delhi',
      '08': 'Rajasthan',
      '09': 'Uttar Pradesh',
      '10': 'Bihar',
      '11': 'Sikkim',
      '12': 'Arunachal Pradesh',
      '13': 'Nagaland',
      '14': 'Manipur',
      '15': 'Mizoram',
      '16': 'Tripura',
      '17': 'Meghalaya',
      '18': 'Assam',
      '19': 'West Bengal',
      '20': 'Jharkhand',
      '21': 'Odisha',
      '22': 'Chhattisgarh',
      '23': 'Madhya Pradesh',
      '24': 'Gujarat',
      '25': 'Daman and Diu',
      '26': 'Dadra and Nagar Haveli',
      '27': 'Maharashtra',
      '28': 'Andhra Pradesh (Old)',
      '29': 'Karnataka',
      '30': 'Goa',
      '31': 'Lakshadweep',
      '32': 'Kerala',
      '33': 'Tamil Nadu',
      '34': 'Puducherry',
      '35': 'Andaman and Nicobar Islands',
      '36': 'Telangana',
      '37': 'Andhra Pradesh',
    };

    return stateCodes[stateCode];
  }
}
