import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CreditNotesListScreen extends StatelessWidget {
  const CreditNotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Notes'),
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
            .collection('credit_notes')
            .orderBy('creditNoteDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final creditNotes = snapshot.data!.docs;

          if (creditNotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No Credit Notes',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: creditNotes.length,
            itemBuilder: (context, index) {
              final doc = creditNotes[index];
              final data = doc.data() as Map<String, dynamic>;
              final creditNoteDate = (data['creditNoteDate'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: Icon(Icons.assignment_return, color: Colors.red.shade700),
                  ),
                  title: Text(
                    data['creditNoteNumber'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Against: ${data['originalInvoiceNumber']}'),
                      Text('Client: ${data['clientName']}'),
                      Text(
                        'Date: ${DateFormat('dd MMM yyyy').format(creditNoteDate)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '₹${data['totalReturnAmount'].toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red.shade700,
                    ),
                  ),
                  onTap: () {
                    // TODO: Show credit note details
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/create_credit_note');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Credit Note'),
      ),
    );
  }
}
