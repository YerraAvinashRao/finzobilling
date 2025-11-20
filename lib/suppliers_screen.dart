import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_edit_supplier_screen.dart';




class SuppliersScreen extends StatefulWidget {
  final bool selectionMode;

  const SuppliersScreen({
    super.key,
    this.selectionMode = false,
  });

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  DocumentReference<Map<String, dynamic>>? _getUserDocRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getSuppliersStream() {
    final userDocRef = _getUserDocRef();
    if (userDocRef == null) return const Stream.empty();
    return userDocRef.collection('suppliers').orderBy('name').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Select Supplier' : 'Suppliers'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getSuppliersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No suppliers yet.\nTap "+" to add your first supplier.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = data['name'] ?? 'Unnamed';
              final gstin = data['gstin'] ?? '';
              final state = data['state'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S'),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (gstin.isNotEmpty) 
                        Text('GSTIN: $gstin', style: const TextStyle(fontSize: 12)),
                      if (state.isNotEmpty) 
                        Text('State: $state', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: widget.selectionMode
                      ? const Icon(Icons.check_circle_outline)
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    if (widget.selectionMode) {
                      Navigator.pop(context, {
                        'id': doc.id,
                        'name': name,
                        'gstin': data['gstin'],
                        'address': data['address'],
                        'state': data['state'],
                        'stateCode': data['stateCode'],
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupplierDetailScreen(  // ✅ NO const here
                            supplierId: doc.id,
                            supplierData: data,
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: widget.selectionMode
          ? null
          : FloatingActionButton(
              heroTag: 'suppliers-screen-fab',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditSupplierScreen(),  // ✅ const OK here
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

class SupplierDetailScreen extends StatelessWidget {
  final String supplierId;
  final Map<String, dynamic> supplierData;

  const SupplierDetailScreen({
    super.key,
    required this.supplierId,
    required this.supplierData,
  });

  Future<void> _deleteSupplier(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: const Text(
            'Are you sure you want to delete this supplier? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('suppliers')
          .doc(supplierId)
          .delete();

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supplier deleted successfully'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting supplier: $e')),
      );
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = supplierData['name'] ?? 'Unknown';
    final gstin = supplierData['gstin'] ?? '';
    final pan = supplierData['pan'] ?? '';
    final address = supplierData['address'] ?? '';
    final city = supplierData['city'] ?? '';
    final state = supplierData['state'] ?? '';
    final stateCode = supplierData['stateCode'] ?? '';
    final pincode = supplierData['pincode'] ?? '';
    final phone = supplierData['phone'] ?? '';
    final email = supplierData['email'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditSupplierScreen(  // ✅ NO const here
                    supplierId: supplierId,
                    supplierData: supplierData,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteSupplier(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.business,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),

            _buildSectionTitle('GST & Tax Information'),
            if (gstin.isNotEmpty) _buildInfoRow(Icons.receipt_long, 'GSTIN', gstin),
            if (pan.isNotEmpty) _buildInfoRow(Icons.credit_card, 'PAN', pan),
            if (stateCode.isNotEmpty)
              _buildInfoRow(Icons.map, 'State Code', stateCode),

            const SizedBox(height: 16),
            const Divider(),

            _buildSectionTitle('Address'),
            if (address.isNotEmpty)
              _buildInfoRow(Icons.location_on, 'Address', address),
            if (city.isNotEmpty) _buildInfoRow(Icons.location_city, 'City', city),
            if (state.isNotEmpty) _buildInfoRow(Icons.map, 'State', state),
            if (pincode.isNotEmpty)
              _buildInfoRow(Icons.pin_drop, 'Pincode', pincode),

            const SizedBox(height: 16),
            const Divider(),

            _buildSectionTitle('Contact Information'),
            if (phone.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.blue),
                title: const Text('Phone'),
                subtitle: Text(phone),
                trailing: IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _launchPhone(phone),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            if (email.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.email, color: Colors.blue),
                title: const Text('Email'),
                subtitle: Text(email),
                trailing: IconButton(
                  icon: const Icon(Icons.mail_outline, color: Colors.orange),
                  onPressed: () => _launchEmail(email),
                ),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
