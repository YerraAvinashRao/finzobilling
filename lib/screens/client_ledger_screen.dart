import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finzobilling/client_detail_screen.dart';

class ClientLedgerScreen extends StatefulWidget {
  const ClientLedgerScreen({super.key});

  @override
  State<ClientLedgerScreen> createState() => _ClientLedgerScreenState();
}

class _ClientLedgerScreenState extends State<ClientLedgerScreen> {
  final _auth = FirebaseAuth.instance;
  String? _userId;
  String _searchQuery = '';
  String _sortBy = 'outstanding'; // outstanding, name, invoices

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
  }

  Future<Map<String, dynamic>> _getClientStats(String clientId, String clientName) async {
    if (_userId == null) return {};

    try {
      // Get all invoices for this client
      final invoicesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('invoices')
          .where('clientName', isEqualTo: clientName)
          .get();

      double totalBilled = 0;
      double totalPaid = 0;
      double outstanding = 0;
      int invoiceCount = invoicesSnapshot.docs.length;

      for (var doc in invoicesSnapshot.docs) {
        final data = doc.data();
        final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        final status = data['status'] as String?;

        totalBilled += total;

        if (status == 'Paid') {
          totalPaid += total;
        } else if (status == 'Unpaid') {
          outstanding += total;
        } else if (status == 'Partially Paid') {
          final payments = data['payments'] as List<dynamic>? ?? [];
          double paidAmount = 0;
          for (var payment in payments) {
            paidAmount += (payment['amount'] as num?)?.toDouble() ?? 0;
          }
          totalPaid += paidAmount;
          outstanding += (total - paidAmount);
        }
      }

      return {
        'totalBilled': totalBilled,
        'totalPaid': totalPaid,
        'outstanding': outstanding,
        'invoiceCount': invoiceCount,
      };
    } catch (e) {
      debugPrint('Error getting client stats: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Ledger'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'outstanding',
                child: Text('Sort by Outstanding'),
              ),
              const PopupMenuItem(
                value: 'name',
                child: Text('Sort by Name'),
              ),
              const PopupMenuItem(
                value: 'invoices',
                child: Text('Sort by Invoices'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          // Client List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_userId)
                  .collection('invoices')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No clients yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                // Get unique clients
                Map<String, dynamic> clientsMap = {};
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final clientName = data['clientName'] ?? data['client']?['name'] ?? 'Unknown';
                  
                  if (!clientsMap.containsKey(clientName)) {
                    clientsMap[clientName] = {
                      'name': clientName,
                      'email': data['client']?['email'],
                      'phone': data['client']?['phone'],
                      'gstin': data['client']?['gstin'] ?? data['clientGstin'],
                    };
                  }
                }

                var clients = clientsMap.values.toList();

                // Filter by search
                if (_searchQuery.isNotEmpty) {
                  clients = clients.where((client) {
                    return client['name'].toString().toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (clients.isEmpty) {
                  return Center(
                    child: Text(
                      'No clients found',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: Future.wait(clients.map((client) async {
                    final stats = await _getClientStats('', client['name']);
                    return {...client, ...stats};
                  })),
                  builder: (context, statsSnapshot) {
                    if (!statsSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var clientsWithStats = statsSnapshot.data!;

                    // Sort clients
                    switch (_sortBy) {
                      case 'outstanding':
                        clientsWithStats.sort((a, b) => 
                          (b['outstanding'] ?? 0).compareTo(a['outstanding'] ?? 0));
                        break;
                      case 'name':
                        clientsWithStats.sort((a, b) => 
                          a['name'].toString().compareTo(b['name'].toString()));
                        break;
                      case 'invoices':
                        clientsWithStats.sort((a, b) => 
                          (b['invoiceCount'] ?? 0).compareTo(a['invoiceCount'] ?? 0));
                        break;
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: clientsWithStats.length,
                      itemBuilder: (context, index) {
                        final client = clientsWithStats[index];
                        return _buildClientCard(client);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final outstanding = (client['outstanding'] ?? 0.0) as double;
    final totalBilled = (client['totalBilled'] ?? 0.0) as double;
    final totalPaid = (client['totalPaid'] ?? 0.0) as double;
    final invoiceCount = client['invoiceCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientDetailScreen(
                clientName: client['name'],
                clientData: client,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client Name & Status
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: outstanding > 0 ? Colors.orange.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        client['name'].toString()[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: outstanding > 0 ? Colors.orange.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (client['phone'] != null)
                          Text(
                            client['phone'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (outstanding > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'DUE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'CLEAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Total Billed',
                      currency.format(totalBilled),
                      Icons.receipt_long,
                      Colors.blue,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Paid',
                      currency.format(totalPaid),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Outstanding',
                      currency.format(outstanding),
                      Icons.pending_actions,
                      outstanding > 0 ? Colors.orange : Colors.grey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              
              // Invoice Count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '$invoiceCount Invoice${invoiceCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
