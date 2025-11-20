import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class BackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== EXPORT ALL DATA ====================
  Future<String> exportAllData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'userId': user.uid,
      'email': user.email,
      'version': '1.0',
      'invoices': await _getInvoices(user.uid),
      'clients': await _getClients(user.uid),
      'products': await _getProducts(user.uid),
      'expenses': await _getExpenses(user.uid),
      'purchases': await _getPurchases(user.uid),
      'settings': await _getSettings(user.uid),
    };

    return jsonEncode(data);
  }

  // ==================== EXPORT TO FILE ====================
  Future<String> exportToFile() async {
    final jsonData = await exportAllData();
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'FinzoBilling_Backup_$timestamp.json';
    final file = File('${directory.path}/$fileName');
    
    await file.writeAsString(jsonData);
    return file.path;
  }

  // ==================== SHARE BACKUP ====================
  Future<void> shareBackup() async {
    final filePath = await exportToFile();
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'FinzoBilling Backup',
      text: 'Your FinzoBilling data backup',
    );
  }

  // ==================== EXPORT CSV ====================
  Future<String> exportInvoicesToCSV() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final invoices = await _getInvoices(user.uid);
    
    final csv = StringBuffer();
    csv.writeln('Invoice Number,Date,Client,Amount,Status,CGST,SGST,IGST');
    
    for (var invoice in invoices) {
      csv.writeln(
        '${invoice['invoiceNumber']},'
        '${_formatDate(invoice['invoiceDate'])},'
        '${invoice['clientName']},'
        '${invoice['totalAmount']},'
        '${invoice['status']},'
        '${invoice['cgst'] ?? 0},'
        '${invoice['sgst'] ?? 0},'
        '${invoice['igst'] ?? 0}'
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory.path}/Invoices_$timestamp.csv');
    await file.writeAsString(csv.toString());
    
    return file.path;
  }

  Future<String> exportProductsToCSV() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final products = await _getProducts(user.uid);
    
    final csv = StringBuffer();
    csv.writeln('Name,SKU,Category,Selling Price,Purchase Price,Stock,GST Rate,HSN');
    
    for (var product in products) {
      csv.writeln(
        '${product['name']},'
        '${product['sku'] ?? ''},'
        '${product['category']},'
        '${product['sellingPrice']},'
        '${product['purchasePrice'] ?? 0},'
        '${product['currentStock'] ?? 0},'
        '${product['gstRate']},'
        '${product['hsnCode'] ?? ''}'
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory.path}/Products_$timestamp.csv');
    await file.writeAsString(csv.toString());
    
    return file.path;
  }

  Future<String> exportClientsToCSV() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final clients = await _getClients(user.uid);
    
    final csv = StringBuffer();
    csv.writeln('Name,Phone,Email,GSTIN,Address,State');
    
    for (var client in clients) {
      csv.writeln(
        '${client['name']},'
        '${client['phone']},'
        '${client['email'] ?? ''},'
        '${client['gstin'] ?? ''},'
        '"${client['address'] ?? ''}",'
        '${client['state'] ?? ''}'
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory.path}/Clients_$timestamp.csv');
    await file.writeAsString(csv.toString());
    
    return file.path;
  }

  // ==================== IMPORT DATA ====================
  Future<void> importFromBackup(String jsonData) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final data = jsonDecode(jsonData) as Map<String, dynamic>;
    
    // Validate backup
    if (data['version'] != '1.0') {
      throw Exception('Incompatible backup version');
    }

    // Import in order (to maintain references)
    await _importClients(user.uid, data['clients'] as List);
    await _importProducts(user.uid, data['products'] as List);
    await _importInvoices(user.uid, data['invoices'] as List);
    await _importExpenses(user.uid, data['expenses'] as List);
    await _importPurchases(user.uid, data['purchases'] as List);
    await _importSettings(user.uid, data['settings'] as Map<String, dynamic>);
  }

  // ==================== HELPER METHODS ====================
  Future<List<Map<String, dynamic>>> _getInvoices(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('invoices')
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _getClients(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('clients')
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _getProducts(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('products')
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _getExpenses(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _getPurchases(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('purchases')
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, dynamic>> _getSettings(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('business_details')
        .get();
    return doc.data() ?? {};
  }

  Future<void> _importClients(String userId, List data) async {
    final batch = _firestore.batch();
    for (var client in data) {
      final ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('clients')
          .doc();
      batch.set(ref, client);
    }
    await batch.commit();
  }

  Future<void> _importProducts(String userId, List data) async {
    final batch = _firestore.batch();
    for (var product in data) {
      final ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('products')
          .doc();
      batch.set(ref, product);
    }
    await batch.commit();
  }

  Future<void> _importInvoices(String userId, List data) async {
    final batch = _firestore.batch();
    for (var invoice in data) {
      final ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('invoices')
          .doc();
      batch.set(ref, invoice);
    }
    await batch.commit();
  }

  Future<void> _importExpenses(String userId, List data) async {
    final batch = _firestore.batch();
    for (var expense in data) {
      final ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc();
      batch.set(ref, expense);
    }
    await batch.commit();
  }

  Future<void> _importPurchases(String userId, List data) async {
    final batch = _firestore.batch();
    for (var purchase in data) {
      final ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .doc();
      batch.set(ref, purchase);
    }
    await batch.commit();
  }

  Future<void> _importSettings(String userId, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('business_details')
        .set(data, SetOptions(merge: true));
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(timestamp.toDate());
    }
    return '';
  }
}
