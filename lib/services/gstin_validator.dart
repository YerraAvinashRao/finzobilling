// lib/services/gstin_validator.dart

class GSTINValidationResult {
  final bool isValid;
  final String? error;
  final String? stateCode;
  final String? stateName;
  final String? pan;
  final String? entityType;
  
  const GSTINValidationResult({
    required this.isValid,
    this.error,
    this.stateCode,
    this.stateName,
    this.pan,
    this.entityType,
  });
  
  factory GSTINValidationResult.valid({
    required String stateCode,
    required String stateName,
    required String pan,
    required String entityType,
  }) {
    return GSTINValidationResult(
      isValid: true,
      stateCode: stateCode,
      stateName: stateName,
      pan: pan,
      entityType: entityType,
    );
  }
  
  factory GSTINValidationResult.invalid(String error) {
    return GSTINValidationResult(
      isValid: false,
      error: error,
    );
  }
}

class GSTINValidator {
  // State code to name mapping (all 36 states + UTs)
  static const Map<String, String> stateNames = {
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
    '28': 'Andhra Pradesh',
    '29': 'Karnataka',
    '30': 'Goa',
    '31': 'Lakshadweep',
    '32': 'Kerala',
    '33': 'Tamil Nadu',
    '34': 'Puducherry',
    '35': 'Andaman and Nicobar Islands',
    '36': 'Telangana',
    '37': 'Andhra Pradesh (New)',
    '38': 'Ladakh',
  };

  // Entity type mapping
  static const Map<String, String> entityTypes = {
    '1': 'Company',
    '2': 'Partnership Firm',
    '3': 'LLP',
    '4': 'Trust',
    '5': 'Society',
    '6': 'Individual',
    '7': 'HUF',
    '8': 'AOP',
    '9': 'Government',
    'A': 'Association',
    'B': 'BOI',
    'C': 'Corporation',
    'D': 'Development Agency',
    'E': 'Embassy',
    'F': 'Foreign Company',
    'G': 'Government',
    'H': 'HUF',
    'I': 'Individual',
    'J': 'Joint Venture',
    'K': 'Krishi Upaj',
    'L': 'Local Authority',
    'M': 'Municipality',
    'N': 'NRI',
    'O': 'Other',
    'P': 'Partnership',
    'Q': 'Qualified',
    'R': 'Representative',
    'S': 'Society',
    'T': 'Trust',
    'U': 'University',
    'V': 'Vendor',
    'W': 'Wholesale',
    'X': 'Exchange',
    'Y': 'Youth',
    'Z': 'Zone',
  };

  /// Main validation function
  static GSTINValidationResult validate(String? gstin) {
    // Check if empty
    if (gstin == null || gstin.trim().isEmpty) {
      return GSTINValidationResult.invalid('GSTIN cannot be empty');
    }

    final cleaned = gstin.trim().toUpperCase();

    // Check length
    if (cleaned.length != 15) {
      return GSTINValidationResult.invalid('GSTIN must be exactly 15 characters');
    }

    // Check format using regex
    final gstinRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}[Z]{1}[0-9A-Z]{1}$');
    if (!gstinRegex.hasMatch(cleaned)) {
      return GSTINValidationResult.invalid('Invalid GSTIN format');
    }

    // Validate state code
    final stateCode = cleaned.substring(0, 2);
    if (!stateNames.containsKey(stateCode)) {
      return GSTINValidationResult.invalid('Invalid state code: $stateCode');
    }

    // Extract PAN (characters 3-12)
    final pan = cleaned.substring(2, 12);

    // Validate PAN format
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    if (!panRegex.hasMatch(pan)) {
      return GSTINValidationResult.invalid('Invalid PAN in GSTIN');
    }

    // Extract entity type (13th character)
    final entityChar = cleaned[12];
    final entityType = entityTypes[entityChar] ?? 'Unknown';

    // Validate checksum (last character)
    if (!_validateChecksum(cleaned)) {
      return GSTINValidationResult.invalid('Invalid checksum - GSTIN may have typo');
    }

    // All validations passed
    return GSTINValidationResult.valid(
      stateCode: stateCode,
      stateName: stateNames[stateCode]!,
      pan: pan,
      entityType: entityType,
    );
  }

  /// Checksum validation using GST algorithm
  static bool _validateChecksum(String gstin) {
    // GST checksum algorithm
    const String chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    
    int factor = 2;
    int sum = 0;
    
    // Process first 14 characters
    for (int i = gstin.length - 2; i >= 0; i--) {
      int codePoint = chars.indexOf(gstin[i]);
      if (codePoint == -1) return false;
      
      int addend = factor * codePoint;
      factor = (factor == 2) ? 1 : 2;
      addend = (addend ~/ 36) + (addend % 36);
      sum += addend;
    }
    
    int remainder = sum % 36;
    int checkCodePoint = (36 - remainder) % 36;
    String checkChar = chars[checkCodePoint];
    
    // Compare with actual last character
    return checkChar == gstin[gstin.length - 1];
  }

  /// Quick format check (without checksum)
  static bool isValidFormat(String? gstin) {
    if (gstin == null || gstin.isEmpty) return false;
    final cleaned = gstin.trim().toUpperCase();
    if (cleaned.length != 15) return false;
    
    final gstinRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}[Z]{1}[0-9A-Z]{1}$');
    return gstinRegex.hasMatch(cleaned);
  }

  /// Extract state code only
  static String? getStateCode(String? gstin) {
    if (gstin == null || gstin.length < 2) return null;
    final stateCode = gstin.substring(0, 2);
    return stateNames.containsKey(stateCode) ? stateCode : null;
  }

  /// Extract state name
  static String? getStateName(String? gstin) {
    final stateCode = getStateCode(gstin);
    return stateCode != null ? stateNames[stateCode] : null;
  }

  /// Extract PAN
  static String? getPAN(String? gstin) {
    if (gstin == null || gstin.length < 12) return null;
    return gstin.substring(2, 12);
  }

  /// Format GSTIN with hyphens for display
  static String formatForDisplay(String gstin) {
    if (gstin.length != 15) return gstin;
    // Format: 22-AAAAA-0000-A-1-Z-5
    return '${gstin.substring(0, 2)}-${gstin.substring(2, 7)}-${gstin.substring(7, 11)}-${gstin.substring(11, 12)}-${gstin.substring(12, 13)}-${gstin.substring(13, 14)}-${gstin.substring(14, 15)}';
  }

  /// Remove formatting
  static String removeFormatting(String gstin) {
    return gstin.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
  }
}
