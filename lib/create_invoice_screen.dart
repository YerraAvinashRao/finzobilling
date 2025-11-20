import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_edit_item_dialog.dart';
import 'line_item.dart';
import 'add_edit_client_screen.dart';
import 'invoice_number_service.dart';
import '../models/invoice_settings.dart';
import '../services/invoice_pdf_service.dart';
import 'package:finzobilling/services/audit_service.dart';
import 'widgets/client_selection_dialog.dart';
import 'package:finzobilling/services/analytics_service.dart';

// Add after imports, before the helper function
const Color appleBackground = Color(0xFFF2F2F7);
const Color appleCard = Color(0xFFFFFFFF);
const Color appleAccent = Color(0xFF007AFF);


// ✅ Helper: Extract state code from GSTIN
String? _extractStateCodeFromGSTIN(String? gstin) {
  if (gstin == null || gstin.trim().isEmpty) return null;
  final cleaned = gstin.trim().toUpperCase();
  if (cleaned.length < 2) return null;
  
  final stateCode = cleaned.substring(0, 2);
  final code = int.tryParse(stateCode);
  if (code == null || code < 1 || code > 37) return null;
  
  return stateCode;
}

class CreateInvoiceScreen extends StatefulWidget {
  // ✅ NEW: Amendment support parameters
  final bool editMode;
  final Map<String, dynamic>? invoiceData;
  final bool isAmendment;

  const CreateInvoiceScreen({
    super.key,
    this.editMode = false,        // ✅ NEW
    this.invoiceData,             // ✅ NEW
    this.isAmendment = false,     // ✅ NEW
  });

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _placeOfSupplyController = TextEditingController();
  
  String? _selectedClientId;
  Map<String, dynamic>? _selectedClientData;
  Map<String, dynamic>? _businessSettings;
  
  DateTime _invoiceDate = DateTime.now();
  final List<LineItem> _items = [];
  bool _isSaving = false;
  bool _isLoadingSettings = true;
  bool _isGeneratingNumber = false;
  
  // Invoice settings  
  // ✅ State detection
  bool _isInterState = false;
  String? _businessGSTIN;
  String? _clientGSTIN;
  // ✅ NEW: Invoice-level discount
  double _invoiceDiscountPercent = 0;
  double _invoiceDiscountAmount = 0;
  bool _isInvoiceDiscountPercent = true;
  final TextEditingController _invoiceDiscountController = TextEditingController(text: '0');

  DocumentReference<Map<String, dynamic>>? _getUserDocRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  @override
  void initState() {
    super.initState();
    _loadBusinessSettings();
    
    // ✅ NEW: Load invoice data if in edit/amendment mode
    if (widget.editMode && widget.invoiceData != null) {
      _loadInvoiceData(widget.invoiceData!);
    } else {
      _generateInvoiceNumber();
    }
  }

  // ✅ NEW: Load invoice data into form fields
  void _loadInvoiceData(Map<String, dynamic> data) {
    // Load client
    if (data['client'] != null) {
      _selectedClientData = Map<String, dynamic>.from(data['client']);
      _selectedClientId = data['clientId'];
      _customerController.text = _selectedClientData!['name'] ?? '';
    } else if (data['clientName'] != null) {
      _selectedClientData = {
        'name': data['clientName'],
        'phone': data['clientPhone'] ?? '',
        'email': data['clientEmail'] ?? '',
        'gstin': data['clientGstin'] ?? '',
        'state': data['clientState'] ?? '',
      };
      _selectedClientId = data['clientId'];
      _customerController.text = data['clientName'];
    }

    // Load invoice date
    if (data['invoiceDate'] != null) {
      final timestamp = data['invoiceDate'] as Timestamp;
      _invoiceDate = timestamp.toDate();
    }

    // Load place of supply
    if (data['placeOfSupply'] != null) {
      _placeOfSupplyController.text = data['placeOfSupply'];
    }

    // Load items
    // Load items
      if (data['lineItems'] != null) {
        final items = data['lineItems'] as List<dynamic>;
        for (var item in items) {
          _items.add(LineItem(
            id: item['productId'] ?? '',
            name: item['productName'] ?? '',
            hsnSac: item['hsnSac'],
            quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
            price: (item['price'] as num?)?.toDouble() ?? 0,
            taxRate: (item['taxRate'] as num?)?.toDouble() ?? 0,
            discountPercent: (item['discountPercent'] as num?)?.toDouble() ?? 0,  // ✅ NEW
            discountAmount: (item['discountAmount'] as num?)?.toDouble() ?? 0,    // ✅ NEW
          ));
        }
      }

      // ✅ NEW: Load invoice-level discount
      if (data['invoiceDiscountPercent'] != null) {
        _invoiceDiscountPercent = (data['invoiceDiscountPercent'] as num).toDouble();
        _invoiceDiscountController.text = _invoiceDiscountPercent.toString();
      }
      if (data['invoiceDiscountAmount'] != null) {
        _invoiceDiscountAmount = (data['invoiceDiscountAmount'] as num).toDouble();
        _isInvoiceDiscountPercent = false;
        _invoiceDiscountController.text = _invoiceDiscountAmount.toString();
      }


    // Set invoice number for display only
    if (data['invoiceNumber'] != null) {
      _invoiceNumberController.text = data['invoiceNumber'];
    }

    // Detect inter-state
    _detectInterState();
  }

  Future<void> _loadBusinessSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('business_details')
          .get();

      if (mounted && doc.exists) {
        setState(() {
          _businessSettings = doc.data();
          _businessGSTIN = _businessSettings?['gstin'] as String?;
          _isLoadingSettings = false;
        });

        if (_businessSettings?['state'] == null || 
            _businessSettings?['name'] == null) {
          _showSettingsWarning();
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingSettings = false);
          _showSettingsWarning();
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoadingSettings = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading business settings: $e')),
        );
      }
    }
  }

  void _showSettingsWarning() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Setup Required'),
          content: const Text(
            'Please complete your business settings (especially Business Name and State) before creating invoices.\n\nThis is required for GST compliance.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _generateInvoiceNumber() async {
    setState(() => _isGeneratingNumber = true);
    
    try {
      final number = await InvoiceNumberService.generateNextInvoiceNumber();
      if (mounted) {
        setState(() {
          _invoiceNumberController.text = number;
          _isGeneratingNumber = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating invoice number: $e');
      if (mounted) {
        setState(() => _isGeneratingNumber = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invoice number: $e')),
        );
      }
    }
  }

  void _detectInterState() {
    if (_businessSettings == null || _selectedClientData == null) {
      setState(() => _isInterState = false);
      return;
    }

    final businessState = _businessSettings!['state'] as String?;
    final clientState = _selectedClientData!['state'] as String?;
    _clientGSTIN = _selectedClientData!['gstin'] as String?;

    bool isInterState = false;
    String detectionMethod = '';

    final businessStateCode = _extractStateCodeFromGSTIN(_businessGSTIN);
    final clientStateCode = _extractStateCodeFromGSTIN(_clientGSTIN);

    if (businessStateCode != null && clientStateCode != null) {
      isInterState = (businessStateCode != clientStateCode);
      detectionMethod = 'GSTIN ($businessStateCode vs $clientStateCode)';
    } else if (businessState != null && clientState != null) {
      isInterState = (businessState != clientState);
      detectionMethod = 'State ($businessState vs $clientState)';
    }

    setState(() => _isInterState = isInterState);

    debugPrint('🎯 State Detection: ${isInterState ? "INTER-STATE" : "INTRA-STATE"}');
    debugPrint('📍 Method: $detectionMethod');
  }

  Future<void> _selectClient() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const ClientSelectionDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedClientId = result['id'] as String?;
        _selectedClientData = result;
        _customerController.text = result['name'] ?? 'Unknown Client';
        _placeOfSupplyController.text = result['state'] ?? '';
      });

      _detectInterState();
    }
  }

  Future<void> _addNewClient() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditClientScreen(),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can now select the newly added client'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showAddOrEditItemDialog({
    LineItem? editingItem,
    int? editingIndex,
  }) async {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please select a client first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userDocRef = _getUserDocRef();
    if (userDocRef == null) return;

    try {
      final productsSnapshot = await userDocRef.collection('products').get();
      final products = productsSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      if (!mounted) return;

      final newItem = await showDialog<LineItem?>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AddEditItemDialog(
          editingItem: editingItem,
          allProducts: products,
        ),
      );

      if (newItem != null) {
        final productDoc = await userDocRef
            .collection('products')
            .doc(newItem.id)
            .get();

        if (productDoc.exists) {
          final availableQty = (productDoc.data()?['currentStock'] as num?)?.toDouble() ?? 0.0;
          final requestedQty = newItem.quantity;
          
          if (requestedQty > availableQty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Insufficient stock! Available: $availableQty ${productDoc.data()?['unit'] ?? 'units'}',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return;
          }
        }

        setState(() {
          if (editingIndex != null) {
            _items[editingIndex] = newItem;
          } else {
            _items.add(newItem);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  Map<String, double> _calculateTotals() {
    if (_businessSettings == null || _selectedClientData == null) {
      return {
        'subtotal': 0,
        'lineItemDiscount': 0,
        'afterLineDiscount': 0,
        'invoiceDiscount': 0,
        'taxableValue': 0,
        'cgst': 0,
        'sgst': 0,
        'igst': 0,
        'totalTax': 0,
        'grandTotal': 0,
        'roundOff': 0,
        'finalAmount': 0,
      };
    }

    // Step 1: Calculate subtotal (before any discounts)
    double subtotal = 0;
    double lineItemDiscount = 0;
    
    for (var item in _items) {
      double itemSubtotal = item.quantity * item.price;
      subtotal += itemSubtotal;
      lineItemDiscount += item.totalDiscount;
    }

    // Step 2: After line-item discounts
    double afterLineDiscount = subtotal - lineItemDiscount;

    // Step 3: Apply invoice-level discount
    double invoiceDiscount = 0;
    if (_isInvoiceDiscountPercent) {
      invoiceDiscount = afterLineDiscount * (_invoiceDiscountPercent / 100);
    } else {
      invoiceDiscount = _invoiceDiscountAmount;
    }

    // Step 4: Taxable value (after all discounts)
    double taxableValue = afterLineDiscount - invoiceDiscount;

    // Step 5: Calculate tax on taxable value
    double totalCGST = 0;
    double totalSGST = 0;
    double totalIGST = 0;

    for (var item in _items) {
      // Calculate proportion of this item in taxable value
      double itemAfterDiscount = item.lineTotal;
      double itemProportion = afterLineDiscount > 0 ? itemAfterDiscount / afterLineDiscount : 0;
      double itemTaxableValue = taxableValue * itemProportion;
      
      // Calculate tax for this item
      double itemTax = itemTaxableValue * item.taxRate;

      if (_isInterState) {
        totalIGST += itemTax;
      } else {
        totalCGST += itemTax / 2;
        totalSGST += itemTax / 2;
      }
    }

    final totalTax = totalCGST + totalSGST + totalIGST;
    final grandTotal = taxableValue + totalTax;
    final roundOff = grandTotal.roundToDouble() - grandTotal;
    final finalAmount = grandTotal.roundToDouble();

    return {
      'subtotal': subtotal,
      'lineItemDiscount': lineItemDiscount,
      'afterLineDiscount': afterLineDiscount,
      'invoiceDiscount': invoiceDiscount,
      'taxableValue': taxableValue,
      'cgst': totalCGST,
      'sgst': totalSGST,
      'igst': totalIGST,
      'totalTax': totalTax,
      'grandTotal': grandTotal,
      'roundOff': roundOff,
      'finalAmount': finalAmount,
    };
  }


  // ✅ UPDATED: Save invoice or return data for amendment
  Future<void> _saveInvoice() async {
    if (_selectedClientId == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client and add items')),
      );
      return;
    }

    if (_businessSettings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business settings not loaded')),
      );
      return;
    }

    final userDocRef = _getUserDocRef();
    if (userDocRef == null) return;

    setState(() => _isSaving = true);
    

    try {
      final totals = _calculateTotals();

      final productIds = _items.map((item) => item.id).whereType<String>().toList();


      final lineItemsWithTax = _items.map((item) {
        final itemSubtotal = item.quantity * item.price;
        final itemAfterDiscount = item.lineTotal;
        final itemProportion = totals['afterLineDiscount']! > 0 
            ? itemAfterDiscount / totals['afterLineDiscount']! 
            : 0;
        final itemTaxableValue = totals['taxableValue']! * itemProportion;
        final taxAmount = itemTaxableValue * item.taxRate;
      

        return {
          'productId': item.id,
          'productName': item.name,
          'hsnSac': item.hsnSac,
          'quantity': item.quantity,
          'unit': 'Nos',
          'price': item.price,
          'discountPercent': item.discountPercent,      // ✅ NEW
          'discountAmount': item.discountAmount,        // ✅ NEW
          'lineDiscount': item.totalDiscount,           // ✅ NEW
          'priceAfterDiscount': item.lineTotal,         // ✅ NEW
          'taxRate': item.taxRate,
          'taxableAmount': itemTaxableValue,
          'cgst': _isInterState ? 0 : taxAmount / 2,
          'sgst': _isInterState ? 0 : taxAmount / 2,
          'igst': _isInterState ? taxAmount : 0,
          'cgstRate': _isInterState ? 0 : (item.taxRate / 2),
          'sgstRate': _isInterState ? 0 : (item.taxRate / 2),
          'igstRate': _isInterState ? item.taxRate : 0,
          'totalTax': taxAmount,
          'lineTotal': item.lineTotal,
        };
      }).toList();


      final invoiceData = {
        'invoiceNumber': _invoiceNumberController.text.trim(),
        'invoiceDate': Timestamp.fromDate(_invoiceDate),
        'clientId': _selectedClientId,
        'clientName': _customerController.text.trim(),
        'clientGstin': _selectedClientData?['gstin'],
        'clientAddress': _selectedClientData?['address'],
        'clientPhone': _selectedClientData?['phone'],
        'clientState': _selectedClientData?['state'],
        'clientStateCode': _selectedClientData?['stateCode'],
        'placeOfSupply': _placeOfSupplyController.text.trim(),
        'businessName': _businessSettings!['name'],
        'businessGstin': _businessSettings!['gstin'],
        'businessState': _businessSettings!['state'],
        'businessStateCode': _businessSettings!['stateCode'],
        'isInterState': _isInterState,
        'lineItems': lineItemsWithTax,
        'productIds': productIds,
        'subtotal': totals['subtotal'],                           // ✅ NEW
        'lineItemDiscount': totals['lineItemDiscount'],           // ✅ NEW
        'invoiceDiscountPercent': _invoiceDiscountPercent,        // ✅ NEW
        'invoiceDiscountAmount': _invoiceDiscountAmount,          // ✅ NEW
        'invoiceDiscount': totals['invoiceDiscount'],             // ✅ NEW
        'taxableValue': totals['taxableValue'],
        'cgst': totals['cgst'],
        'sgst': totals['sgst'],
        'igst': totals['igst'],
        'totalTax': totals['totalTax'],
        'grandTotal': totals['grandTotal'],
        'roundOff': totals['roundOff'],
        'totalAmount': totals['finalAmount'],
        'status': 'Unpaid',
        'createdAt': Timestamp.now(),
        'createdBy': FirebaseAuth.instance.currentUser?.email,
      };

      // ✅ If amendment mode, return data instead of saving
      if (widget.isAmendment) {
        Navigator.pop(context, invoiceData); // ✅ Return edited data
        return;
      }

      // ✅ Otherwise, save normally
      final batch = FirebaseFirestore.instance.batch();
      final invoiceRef = userDocRef.collection('invoices').doc();

      batch.set(invoiceRef, invoiceData);

      if (_selectedClientId != null) {
        final clientRef = userDocRef.collection('clients').doc(_selectedClientId);
        batch.update(clientRef, {
          'lastInvoiceDate': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
      }

      for (var item in _items) {
        final productRef = userDocRef.collection('products').doc(item.id);
        batch.update(productRef, {
          'currentStock': FieldValue.increment(-item.quantity),
          'lastSoldAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
      }

      await batch.commit();

      await AnalyticsService().logInvoiceCreated(
        amount: totals['finalAmount']!,
        clientId: _selectedClientId!,
        itemCount: _items.length,
        isInterState: _isInterState,
      );

      try {
        await AuditService().logAction(
          entityType: 'invoice',
          entityId: invoiceRef.id,
          action: 'CREATE',
          afterData: {
            'invoiceNumber': _invoiceNumberController.text.trim(),
            'clientName': _customerController.text.trim(),
            'clientId': _selectedClientId,
            'totalAmount': totals['finalAmount'],
            'taxableValue': totals['taxableValue'],
            'cgst': totals['cgst'],
            'sgst': totals['sgst'],
            'igst': totals['igst'],
            'status': 'Unpaid',
            'isInterState': _isInterState,
            'itemCount': _items.length,
          },
          reason: 'New invoice created by user',
        );
      } catch (e) {
        debugPrint('⚠️ Audit log failed (non-critical): $e');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Invoice created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      final generatePdf = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invoice Created!'),
          content: const Text('Would you like to generate PDF now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Generate PDF'),
            ),
          ],
        ),
      );

      if (generatePdf == true && mounted) {
        await _generateInvoicePDF(invoiceRef.id);
      }

      Navigator.pop(context);
    } catch (e) {
      await AnalyticsService().recordError(
        e,
        StackTrace.current,
        reason: 'Invoice creation failed',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _generateInvoicePDF(String invoiceId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final userDocRef = _getUserDocRef();
      if (userDocRef == null) return;

      final invoiceDoc = await userDocRef.collection('invoices').doc(invoiceId).get();
      final invoiceData = invoiceDoc.data()!;

      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('invoice_settings');
      final settings = settingsJson != null 
          ? InvoiceSettings.fromJson(settingsJson) 
          : InvoiceSettings();

      final businessDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('settings')
          .doc('business_details')
          .get();

      final businessData = businessDoc.data() ?? {};

      final pdfService = InvoicePdfService();
      final pdf = await pdfService.generateInvoicePdf(
        invoiceData: invoiceData,
        businessData: businessData,
        settings: settings,
      );

      if (mounted) Navigator.pop(context);

      if (mounted) {
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF Generated!'),
            content: const Text('What would you like to do?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'preview'),
                child: const Text('Preview'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'share'),
                child: const Text('Share'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'print'),
                child: const Text('Print'),
              ),
            ],
          ),
        );

        if (action == 'preview') {
          await pdfService.previewPdf(pdf, context);
          await AnalyticsService().logPdfGenerated(invoiceId, 'preview');
        } else if (action == 'share') {
          await pdfService.sharePdf(
            pdf, 
            'Invoice_${invoiceData['invoiceNumber']}',
          );
          await AnalyticsService().logPdfGenerated(invoiceId, 'share');

          try {
            await AuditService().logAction(
              entityType: 'invoice',
              entityId: invoiceId,
              action: 'SHARE_PDF',
              afterData: {
                'invoiceNumber': invoiceData['invoiceNumber'],
                'sharedVia': 'app_share',
              },
              reason: 'Invoice PDF shared by user',
            );
          } catch (e) {
            debugPrint('⚠️ Audit log failed: $e');
          }
        } else if (action == 'print') {
          await pdfService.printPdf(pdf);
          await AnalyticsService().logPdfGenerated(invoiceId, 'print');
          
          try {
            await AuditService().logAction(
              entityType: 'invoice',
              entityId: invoiceId,
              action: 'PRINT_PDF',
              afterData: {
                'invoiceNumber': invoiceData['invoiceNumber'],
              },
              reason: 'Invoice PDF printed by user',
            );
          } catch (e) {
            debugPrint('⚠️ Audit log failed: $e');
          }
        }
      }
    } catch (e) {
      await AnalyticsService().recordError(
        e,
        StackTrace.current,
        reason: 'PDF generation failed',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _invoiceNumberController.dispose();
    _placeOfSupplyController.dispose();
    _invoiceDiscountController.dispose();  // ✅ NEW
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final totals = _calculateTotals();

    if (_isLoadingSettings) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Invoice')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: appleBackground,  // ← Add this
      appBar: AppBar(
        title: Text(
          widget.isAmendment 
              ? 'Edit Invoice (Amendment)' 
              : widget.editMode 
                  ? 'Edit Invoice' 
                  : 'Create Invoice'
        ),
        backgroundColor: widget.isAmendment ? Colors.orange : appleCard,  // ← Change this
        elevation: 0,  // ← Add this
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            onPressed: _isSaving ? null : _saveInvoice,
            tooltip: widget.isAmendment ? 'Save Amendment' : 'Save Invoice',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ NEW: Amendment warning banner
            if (widget.isAmendment)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.orange, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '📝 Editing invoice for amendment. Make your corrections and tap Save.',
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

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _invoiceNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Number *',
                      prefixIcon: Icon(Icons.tag),
                      border: OutlineInputBorder(),
                    ),
                    enabled: false,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _invoiceDate = date);
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Invoice Date *',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          hintText: DateFormat('dd/MM/yyyy').format(_invoiceDate),
                        ),
                        controller: TextEditingController(
                          text: DateFormat('dd/MM/yyyy').format(_invoiceDate),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Client Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectClient,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _customerController,
                        decoration: InputDecoration(
                          labelText: 'Client Name *',
                          hintText: 'Tap to select client',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: _selectedClientId != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _selectedClientId = null;
                                      _selectedClientData = null;
                                      _customerController.clear();
                                      _placeOfSupplyController.clear();
                                      _isInterState = false;
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addNewClient,
                  icon: const Icon(Icons.person_add, color: Colors.white),  // ← Add color
                  tooltip: 'Add New Client',
                  style: IconButton.styleFrom(
                    backgroundColor: appleAccent,  // ← Change to appleAccent
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            if (_selectedClientData != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedClientData!['gstin'] != null &&
                        _selectedClientData!['gstin'].toString().isNotEmpty)
                      Text(
                        'GSTIN: ${_selectedClientData!['gstin']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (_selectedClientData!['state'] != null)
                      Text(
                        'State: ${_selectedClientData!['state']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (_selectedClientData!['phone'] != null)
                      Text(
                        'Phone: ${_selectedClientData!['phone']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isInterState ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isInterState ? Colors.orange.shade300 : Colors.green.shade300,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isInterState ? Icons.flight_takeoff : Icons.location_city,
                      size: 20,
                      color: _isInterState ? Colors.orange.shade700 : Colors.green.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isInterState ? '🔒 INTER-STATE SUPPLY' : '🔒 INTRA-STATE SUPPLY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isInterState ? Colors.orange.shade900 : Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isInterState
                                ? 'IGST will be applied'
                                : 'CGST + SGST will be applied',
                            style: TextStyle(
                              fontSize: 10,
                              color: _isInterState ? Colors.orange.shade800 : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            TextFormField(
              controller: _placeOfSupplyController,
              decoration: const InputDecoration(
                labelText: 'Place of Supply',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              enabled: false,
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Invoice Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _showAddOrEditItemDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(48),
                child: const Center(
                  child: Text(
                    'No items added yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (_, index) {
                  final item = _items[index];
                  final lineTotal = item.price * item.quantity;
                  final taxableValue = lineTotal / (1 + item.taxRate);
                  final lineTax = lineTotal - taxableValue;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Qty: ${item.quantity} • Rate: ${currency.format(item.price)} • GST: ${(item.taxRate * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                          // ✅ NEW: Show discount if any
                          if (item.totalDiscount > 0)
                            Text(
                              'Discount: ${item.discountPercent > 0 ? "${item.discountPercent.toStringAsFixed(1)}%" : currency.format(item.discountAmount)} = ${currency.format(item.totalDiscount)} off',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (item.hsnSac != null && item.hsnSac!.isNotEmpty)
                            Text(
                              'HSN/SAC: ${item.hsnSac}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ✅ UPDATED: Show price with strikethrough if discount
                          if (item.totalDiscount > 0)
                            Text(
                              currency.format(item.quantity * item.price),
                              style: TextStyle(
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          Text(
                            currency.format(item.lineTotal),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: item.totalDiscount > 0 ? Colors.green.shade700 : null,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showAddOrEditItemDialog(
                        editingItem: item,
                        editingIndex: index,
                      ),
                    ),
                  );

                },
              ),

            const SizedBox(height: 24),

            if (_items.isNotEmpty && _selectedClientData != null) ...[
              const Divider(thickness: 2),
              const SizedBox(height: 16),
              
              // ✅ NEW: Invoice-level discount input
              const Text(
                'Invoice Discount (Optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _invoiceDiscountController,
                      decoration: InputDecoration(
                        labelText: _isInvoiceDiscountPercent ? 'Discount %' : 'Discount ₹',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(_isInvoiceDiscountPercent ? Icons.percent : Icons.currency_rupee),
                        hintText: '0',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          if (_isInvoiceDiscountPercent) {
                            _invoiceDiscountPercent = double.tryParse(value) ?? 0;
                            _invoiceDiscountAmount = 0;
                          } else {
                            _invoiceDiscountAmount = double.tryParse(value) ?? 0;
                            _invoiceDiscountPercent = 0;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ToggleButtons(
                      isSelected: [_isInvoiceDiscountPercent, !_isInvoiceDiscountPercent],
                      onPressed: (index) {
                        setState(() {
                          _isInvoiceDiscountPercent = index == 0;
                          _invoiceDiscountController.clear();
                          _invoiceDiscountPercent = 0;
                          _invoiceDiscountAmount = 0;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      constraints: const BoxConstraints(
                        minHeight: 40,
                        minWidth: 50,
                      ),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('%', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // ✅ UPDATED: Enhanced summary with discount breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Subtotal', totals['subtotal']!, currency),
                    
                    // ✅ NEW: Line-item discount
                    if (totals['lineItemDiscount']! > 0) ...[
                      const SizedBox(height: 4),
                      _buildSummaryRow(
                        'Line Item Discount',
                        -totals['lineItemDiscount']!,
                        currency,
                        color: Colors.green,
                      ),
                    ],
                    
                    // ✅ NEW: After line discount
                    if (totals['lineItemDiscount']! > 0) ...[
                      const Divider(height: 16),
                      _buildSummaryRow(
                        'After Line Discount',
                        totals['afterLineDiscount']!,
                        currency,
                      ),
                    ],
                    
                    // ✅ NEW: Invoice discount
                    if (totals['invoiceDiscount']! > 0) ...[
                      const SizedBox(height: 4),
                      _buildSummaryRow(
                        'Invoice Discount',
                        -totals['invoiceDiscount']!,
                        currency,
                        color: Colors.green,
                      ),
                      const Divider(height: 16),
                    ],
                    
                    _buildSummaryRow('Taxable Value', totals['taxableValue']!, currency),
                    const SizedBox(height: 8),
                    
                    if (totals['cgst']! > 0) ...[
                      _buildSummaryRow('CGST', totals['cgst']!, currency, color: Colors.blue),
                      const SizedBox(height: 4),
                      _buildSummaryRow('SGST', totals['sgst']!, currency, color: Colors.blue),
                    ],
                    if (totals['igst']! > 0)
                      _buildSummaryRow('IGST', totals['igst']!, currency, color: Colors.blue),
                    const Divider(height: 24),
                    _buildSummaryRow(
                      'Grand Total',
                      totals['finalAmount']!,
                      currency,
                      isBold: true,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value,
    NumberFormat currency, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
            color: color,
          ),
        ),
        Text(
          currency.format(value),
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
            color: color,
          ),
        ),
      ],
    );
  }
}
