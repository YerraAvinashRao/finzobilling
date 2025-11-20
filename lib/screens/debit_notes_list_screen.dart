import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'create_debit_note_screen.dart';

class DebitNotesListScreen extends StatelessWidget {
  const DebitNotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debit Notes'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter options
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('debit_notes')
            .orderBy('debitNoteDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final debitNotes = snapshot.data!.docs;

          if (debitNotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_return, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No Debit Notes',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create debit note when returning goods to supplier',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: debitNotes.length,
            itemBuilder: (context, index) {
              final doc = debitNotes[index];
              final data = doc.data() as Map<String, dynamic>;
              final debitNoteDate = (data['debitNoteDate'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Icon(Icons.assignment_return_outlined, color: Colors.orange.shade700),
                  ),
                  title: Text(
                    data['debitNoteNumber'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Against: ${data['originalPurchaseNumber']}'),
                      Text('Supplier: ${data['supplierName']}'),
                      Text(
                        'Date: ${DateFormat('dd MMM yyyy').format(debitNoteDate)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${data['totalReturnAmount'].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      if (data['itcReversalStatus'] == 'pending')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ITC Pending',
                            style: TextStyle(fontSize: 9, color: Colors.red.shade700),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    // TODO: Show debit note details
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateDebitNoteScreen()),
          );
        },
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add),
        label: const Text('New Debit Note'),
      ),
    );
  }
}
