// lib/widgets/gstin_input_field.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finzobilling/services/gstin_validator.dart';

class GSTINInputField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool required;
  final Function(GSTINValidationResult)? onValidated;
  final bool showLiveValidation;
  final bool enabled;

  const GSTINInputField({
    super.key,
    required this.controller,
    this.label = 'GSTIN',
    this.hint = '22AAAAA0000A1Z5',
    this.required = false,
    this.onValidated,
    this.showLiveValidation = true,
    this.enabled = true,
  });

  @override
  State<GSTINInputField> createState() => _GSTINInputFieldState();
}

class _GSTINInputFieldState extends State<GSTINInputField> {
  GSTINValidationResult? _validationResult;
  bool _showValidation = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    
    if (text.isEmpty) {
      setState(() {
        _validationResult = null;
        _showValidation = false;
      });
      return;
    }

    // Only validate if length >= 15
    if (text.length >= 15) {
      final result = GSTINValidator.validate(text);
      setState(() {
        _validationResult = result;
        _showValidation = widget.showLiveValidation;
      });

      // Callback with result
      if (widget.onValidated != null) {
        widget.onValidated!(result);
      }
    } else {
      setState(() {
        _validationResult = null;
        _showValidation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.receipt_long),
            suffixIcon: _buildSuffixIcon(),
            helperText: widget.required 
                ? 'Required for GST calculation' 
                : 'Optional - Leave empty for B2C customers',
            helperMaxLines: 2,
          ),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            LengthLimitingTextInputFormatter(15),
            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
            UpperCaseTextFormatter(),
          ],
          validator: (value) {
            if (widget.required && (value == null || value.isEmpty)) {
              return 'GSTIN is required';
            }
            
            if (value != null && value.isNotEmpty) {
              final result = GSTINValidator.validate(value);
              if (!result.isValid) {
                return result.error;
              }
            }
            
            return null;
          },
        ),
        
        // Live validation feedback
        if (_showValidation && _validationResult != null) ...[
          const SizedBox(height: 8),
          _buildValidationFeedback(),
        ],
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (_validationResult == null) return null;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _validationResult!.isValid
          ? const Icon(Icons.check_circle, color: Colors.green, size: 24)
          : const Icon(Icons.error, color: Colors.red, size: 24),
    );
  }

  Widget _buildValidationFeedback() {
    final result = _validationResult!;

    if (!result.isValid) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.error ?? 'Invalid GSTIN',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Valid GSTIN - show details
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Valid GSTIN',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('State', '${result.stateName} (${result.stateCode})'),
          _buildInfoRow('PAN', result.pan ?? 'N/A'),
          _buildInfoRow('Entity Type', result.entityType ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper: Auto-uppercase formatter
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
