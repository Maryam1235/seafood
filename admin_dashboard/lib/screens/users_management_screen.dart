import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _roleFilter = 'all';

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
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

    if (confirm == true) {
      try {
        await _firestore.collection('users').doc(userId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or phone...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _roleFilter,
                    decoration: InputDecoration(
                      labelText: 'Filter by Role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Users')),
                      DropdownMenuItem(value: 'customer', child: Text('Customers')),
                      DropdownMenuItem(value: 'seller', child: Text('Sellers')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _roleFilter = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  // Role filter
                  if (_roleFilter != 'all' && data['role'] != _roleFilter) {
                    return false;
                  }
                  
                  // Search filter
                  if (_searchQuery.isEmpty) return true;
                  
                  final fullName = (data['fullName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  final username = (data['username'] ?? '').toString().toLowerCase();
                  
                  return fullName.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      phone.contains(_searchQuery) ||
                      username.contains(_searchQuery);
                }).toList();

                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DataTable2(
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    minWidth: 1000,
                    columns: const [
                      DataColumn2(label: Text('Full Name'), size: ColumnSize.L),
                      DataColumn2(label: Text('Username')),
                      DataColumn2(label: Text('Email'), size: ColumnSize.L),
                      DataColumn2(label: Text('Phone')),
                      DataColumn2(label: Text('Role'), size: ColumnSize.S),
                      DataColumn2(label: Text('Created'), size: ColumnSize.S),
                      DataColumn2(label: Text('Actions'), size: ColumnSize.S),
                    ],
                    rows: users.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final createdAt = data['createdAt'] as Timestamp?;
                      final role = data['role'] ?? 'customer';
                      
                      return DataRow2(
                        cells: [
                          DataCell(Text(data['fullName'] ?? 'N/A')),
                          DataCell(Text(data['username'] ?? 'N/A')),
                          DataCell(Text(data['email'] ?? 'N/A')),
                          DataCell(Text(data['phone'] ?? 'N/A')),
                          DataCell(
                            Chip(
                              label: Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: role == 'seller'
                                  ? Colors.orange.shade100
                                  : Colors.blue.shade100,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                          DataCell(Text(
                            createdAt != null
                                ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                                : 'N/A',
                          )),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteUser(doc.id),
                              tooltip: 'Delete User',
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
