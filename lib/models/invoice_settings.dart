import 'dart:convert';

class InvoiceSettings {
  // Branding
  String? logoPath;              // Local path to logo image
  String templateStyle;          // 'classic', 'modern', 'colorful', 'service', 'retail'
  String primaryColor;           // Hex color code
  String secondaryColor;         // Hex color code
  bool showWatermark;
  String watermarkText;          // 'ORIGINAL', 'COPY', 'PAID', 'UNPAID'

  // ❌ REMOVED: Payment Details (now in business settings)
  // String? upiId;
  // String? bankName;
  // String? accountNumber;
  // String? ifscCode;
  
  String paymentTerms;           // 'Net 30 Days', 'Net 15 Days', etc.

  // Terms & Conditions
  String termsAndConditions;
  String? footerText;

  // Additional Fields
  bool showPONumber;
  bool showDeliveryNote;
  bool showTransportDetails;
  bool showEWayBill;

  // Signature
  String? signaturePath;         // Local path to signature image
  String? signatoryName;
  String? signatoryDesignation;

  // Tax Settings
  bool showDetailedTaxBreakdown; // Show separate CGST/SGST for B2C
  
  // Layout Preferences
  String logoPosition;           // 'left', 'center', 'right'
  bool showQRCode;              // Show UPI QR code

  InvoiceSettings({
    this.logoPath,
    this.templateStyle = 'classic',
    this.primaryColor = '#1976D2',      // Material Blue
    this.secondaryColor = '#424242',    // Dark Gray
    this.showWatermark = false,
    this.watermarkText = 'ORIGINAL',
    this.paymentTerms = 'Net 30 Days',
    this.termsAndConditions = '1. Payment is due within 30 days from invoice date.\n'
        '2. Late payments may attract interest charges.\n'
        '3. Goods once sold will not be taken back.\n'
        '4. Subject to local jurisdiction only.',
    this.footerText,
    this.showPONumber = false,
    this.showDeliveryNote = false,
    this.showTransportDetails = false,
    this.showEWayBill = false,
    this.signaturePath,
    this.signatoryName,
    this.signatoryDesignation,
    this.showDetailedTaxBreakdown = true,
    this.logoPosition = 'left',
    this.showQRCode = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'logoPath': logoPath,
      'templateStyle': templateStyle,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'showWatermark': showWatermark,
      'watermarkText': watermarkText,
      'paymentTerms': paymentTerms,
      'termsAndConditions': termsAndConditions,
      'footerText': footerText,
      'showPONumber': showPONumber,
      'showDeliveryNote': showDeliveryNote,
      'showTransportDetails': showTransportDetails,
      'showEWayBill': showEWayBill,
      'signaturePath': signaturePath,
      'signatoryName': signatoryName,
      'signatoryDesignation': signatoryDesignation,
      'showDetailedTaxBreakdown': showDetailedTaxBreakdown,
      'logoPosition': logoPosition,
      'showQRCode': showQRCode,
    };
  }

  factory InvoiceSettings.fromMap(Map<String, dynamic> map) {
    return InvoiceSettings(
      logoPath: map['logoPath'] as String?,
      templateStyle: map['templateStyle'] as String? ?? 'classic',
      primaryColor: map['primaryColor'] as String? ?? '#1976D2',
      secondaryColor: map['secondaryColor'] as String? ?? '#424242',
      showWatermark: map['showWatermark'] as bool? ?? false,
      watermarkText: map['watermarkText'] as String? ?? 'ORIGINAL',
      paymentTerms: map['paymentTerms'] as String? ?? 'Net 30 Days',
      termsAndConditions: map['termsAndConditions'] as String? ?? 
          '1. Payment is due within 30 days from invoice date.\n'
          '2. Late payments may attract interest charges.\n'
          '3. Goods once sold will not be taken back.\n'
          '4. Subject to local jurisdiction only.',
      footerText: map['footerText'] as String?,
      showPONumber: map['showPONumber'] as bool? ?? false,
      showDeliveryNote: map['showDeliveryNote'] as bool? ?? false,
      showTransportDetails: map['showTransportDetails'] as bool? ?? false,
      showEWayBill: map['showEWayBill'] as bool? ?? false,
      signaturePath: map['signaturePath'] as String?,
      signatoryName: map['signatoryName'] as String?,
      signatoryDesignation: map['signatoryDesignation'] as String?,
      showDetailedTaxBreakdown: map['showDetailedTaxBreakdown'] as bool? ?? true,
      logoPosition: map['logoPosition'] as String? ?? 'left',
      showQRCode: map['showQRCode'] as bool? ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory InvoiceSettings.fromJson(String source) =>
      InvoiceSettings.fromMap(json.decode(source) as Map<String, dynamic>);

  InvoiceSettings copyWith({
    String? logoPath,
    String? templateStyle,
    String? primaryColor,
    String? secondaryColor,
    bool? showWatermark,
    String? watermarkText,
    String? paymentTerms,
    String? termsAndConditions,
    String? footerText,
    bool? showPONumber,
    bool? showDeliveryNote,
    bool? showTransportDetails,
    bool? showEWayBill,
    String? signaturePath,
    String? signatoryName,
    String? signatoryDesignation,
    bool? showDetailedTaxBreakdown,
    String? logoPosition,
    bool? showQRCode,
  }) {
    return InvoiceSettings(
      logoPath: logoPath ?? this.logoPath,
      templateStyle: templateStyle ?? this.templateStyle,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      showWatermark: showWatermark ?? this.showWatermark,
      watermarkText: watermarkText ?? this.watermarkText,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      footerText: footerText ?? this.footerText,
      showPONumber: showPONumber ?? this.showPONumber,
      showDeliveryNote: showDeliveryNote ?? this.showDeliveryNote,
      showTransportDetails: showTransportDetails ?? this.showTransportDetails,
      showEWayBill: showEWayBill ?? this.showEWayBill,
      signaturePath: signaturePath ?? this.signaturePath,
      signatoryName: signatoryName ?? this.signatoryName,
      signatoryDesignation: signatoryDesignation ?? this.signatoryDesignation,
      showDetailedTaxBreakdown: showDetailedTaxBreakdown ?? this.showDetailedTaxBreakdown,
      logoPosition: logoPosition ?? this.logoPosition,
      showQRCode: showQRCode ?? this.showQRCode,
    );
  }
}
