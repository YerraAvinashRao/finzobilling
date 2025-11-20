import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_edit_client_screen.dart';
import 'client_detail_screen.dart';

class ClientsScreen extends StatefulWidget {
  final bool selectionMode;
  
  const ClientsScreen({super.key, this.selectionMode = false});
  
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _auth = FirebaseAuth.instance;
  String? _userId;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // 🍎 Apple iOS Premium Colors
  static const Color appleBackground = Color(0xFFFBFBFD);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleText = Color(0xFF1D1D1F);
  static const Color appleSecondary = Color(0xFF86868B);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleDivider = Color(0xFFD2D2D7);
  static const Color appleSubtle = Color(0xFFF5F5F7);

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getClientOutstanding(String clientName) async {
    if (_userId == null) return {'outstanding': 0.0, 'invoices': 0};

    try {
      final invoicesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('invoices')
          .where('clientName', isEqualTo: clientName)
          .get();

      double outstanding = 0;
      int invoiceCount = invoicesSnapshot.docs.length;

      for (var doc in invoicesSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;

        if (status == 'Unpaid') {
          outstanding += total;
        } else if (status == 'Partially Paid') {
          final payments = data['payments'] as List<dynamic>? ?? [];
          double paidAmount = 0;
          for (var payment in payments) {
            paidAmount += (payment['amount'] as num?)?.toDouble() ?? 0;
          }
          outstanding += (total - paidAmount);
        }
      }

      return {'outstanding': outstanding, 'invoices': invoiceCount};
    } catch (e) {
      return {'outstanding': 0.0, 'invoices': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        backgroundColor: appleBackground,
        body: Center(
          child: Text(
            'Please log in to view clients',
            style: TextStyle(color: appleSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: appleBackground,
      body: Column(
        children: [
          // Summary Cards
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_userId)
                .collection('invoices')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              Set<String> uniqueClients = {};
              double totalOutstanding = 0;

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final clientName = data['clientName'] ?? 'Unknown';
                uniqueClients.add(clientName);

                final status = data['status'] as String?;
                final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;

                if (status == 'Unpaid') {
                  totalOutstanding += total;
                } else if (status == 'Partially Paid') {
                  final payments = data['payments'] as List<dynamic>? ?? [];
                  double paidAmount = 0;
                  for (var payment in payments) {
                    paidAmount += (payment['amount'] as num?)?.toDouble() ?? 0;
                  }
                  totalOutstanding += (total - paidAmount);
                }
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      appleAccent.withOpacity(0.05),
                      appleBackground,
                    ],
                    begin
                    : Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Clients',
                        '${uniqueClients.length}',
                        Icons.people_rounded,
                        appleAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Outstanding',
                        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
                            .format(totalOutstanding),
                        Icons.account_balance_wallet_rounded,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: appleSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  fontSize: 15,
                  color: appleText,
                  letterSpacing: -0.2,
                ),
                decoration: InputDecoration(
                  hintText: 'Search clients...',
                  hintStyle: TextStyle(
                    color: appleSecondary,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: appleSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.cancel_rounded,
                            color: appleSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              ),
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
                  return const Center(
                    child: CircularProgressIndicator(color: appleAccent),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: appleSubtle,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.people_outline_rounded,
                            size: 50,
                            color: appleSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No clients yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: appleText,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create an invoice to add a client',
                          style: TextStyle(
                            fontSize: 14,
                            color: appleSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Get unique clients with their data
                Map<String, Map<String, dynamic>> clientsMap = {};
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

                // Sort by name
                clients.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

                if (clients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: appleSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'No clients found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: appleText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try a different search term',
                          style: TextStyle(
                            fontSize: 14,
                            color: appleSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return FutureBuilder<Map<String, dynamic>>(
                      future: _getClientOutstanding(client['name']),
                      builder: (context, outstandingSnapshot) {
                        if (!outstandingSnapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        return _buildClientCard(client, outstandingSnapshot.data!);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditClientScreen()),
          );
        },
        backgroundColor: appleAccent,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Add Client',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appleDivider.withOpacity(0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: appleSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client, Map<String, dynamic> stats) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final outstanding = (stats['outstanding'] as double?) ?? 0.0;
    final invoiceCount = stats['invoices'] ?? 0;

    return Material(
      color: appleCard,
      borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: appleDivider.withOpacity(0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: outstanding > 0 
                          ? [Colors.orange.shade100, Colors.orange.shade200]
                          : [Colors.green.shade100, Colors.green.shade200],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      client['name'].toString()[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: outstanding > 0 
                            ? Colors.orange.shade700 
                            : Colors.green.shade700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Client Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: appleText,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.receipt_rounded, size: 14, color: appleSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '$invoiceCount invoice${invoiceCount != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: appleSecondary,
                            ),
                          ),
                          if (client['phone'] != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.phone_rounded, size: 14, color: appleSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                client['phone'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: appleSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Outstanding Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (outstanding > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DUE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currency.format(outstanding),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'CLEAR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Search Delegate
class ClientSearchDelegate extends SearchDelegate {
  final String userId;

  ClientSearchDelegate(this.userId);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1D1D1F)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1D1D1F),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: const Color(0xFF86868B),
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('invoices')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF007AFF)),
          );
        }

        Map<String, Map<String, dynamic>> clientsMap = {};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final clientName = data['clientName'] ?? 'Unknown';
          
          if (clientName.toLowerCase().contains(query.toLowerCase())) {
            clientsMap[clientName] = {
              'name': clientName,
              'phone': data['client']?['phone'],
              'email': data['client']?['email'],
            };
          }
        }

        var clients = clientsMap.values.toList();

        if (clients.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No clients found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: clients.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final client = clients[index];
            return ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    client['name'].toString()[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ),
              ),
              title: Text(
                client['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: client['phone'] != null 
                  ? Text(
                      client['phone'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ) 
                  : null,
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                close(context, null);
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
            );
          },
        );
      },
    );
  }
}
