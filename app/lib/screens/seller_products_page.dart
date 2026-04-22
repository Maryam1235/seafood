import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/language_provider.dart';
import 'add_product_screen.dart';

int _getTime(Map p) {
  final t = p['createdAt'];
  if (t == null) return 0;
  if (t is int) return t;
  if (t is Timestamp) return t.millisecondsSinceEpoch;
  return 0;
}

class SellerProductsPage extends StatefulWidget {
  final LanguageProvider lang;
  final VoidCallback? onOpenDrawer;
  const SellerProductsPage({super.key, required this.lang, this.onOpenDrawer});

  @override
  State<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends State<SellerProductsPage> {
  String _search = '';
  String _sortBy = 'newest';
  String _filterStatus = 'all';

  Future<void> _deleteProduct(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(widget.lang.t('delete_product')),
        content: Text(widget.lang.t('delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.lang.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              widget.lang.t('delete'),
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('products').doc(id).delete();
    }
  }

  Future<void> _toggleAvailability(String id, bool current) async {
    await FirebaseFirestore.instance.collection('products').doc(id).update({
      'isAvailable': !current,
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.lang.t('my_products')),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed:
              widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddProductScreen()),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(widget.lang.t('add_product')),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: widget.lang.t('search_products'),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _sortBy,
                        decoration: InputDecoration(
                          labelText: widget.lang.t('sort_by'),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'newest',
                            child: Text(widget.lang.t('newest')),
                          ),
                          DropdownMenuItem(
                            value: 'oldest',
                            child: Text(widget.lang.t('oldest')),
                          ),
                          DropdownMenuItem(
                            value: 'price_high',
                            child: Text(widget.lang.t('price_high')),
                          ),
                          DropdownMenuItem(
                            value: 'price_low',
                            child: Text(widget.lang.t('price_low')),
                          ),
                          DropdownMenuItem(
                            value: 'name',
                            child: Text(widget.lang.t('name_az')),
                          ),
                        ],
                        onChanged: (v) => setState(() => _sortBy = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterStatus,
                        decoration: InputDecoration(
                          labelText: widget.lang.t('status'),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(widget.lang.t('all')),
                          ),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text(widget.lang.t('active')),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text(widget.lang.t('inactive')),
                          ),
                        ],
                        onChanged: (v) => setState(() => _filterStatus = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('sellerId', isEqualTo: uid)
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
                        Icon(
                          Icons.inventory,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.lang.t('no_products'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var products = snapshot.data!.docs
                    .map(
                      (d) => {'id': d.id, ...d.data() as Map<String, dynamic>},
                    )
                    .toList();

                if (_search.isNotEmpty) {
                  products = products
                      .where(
                        (p) =>
                            (p['name'] ?? '').toString().toLowerCase().contains(
                              _search,
                            ) ||
                            (p['category'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains(_search),
                      )
                      .toList();
                }

                if (_filterStatus == 'active') {
                  products = products
                      .where((p) => p['isAvailable'] == true)
                      .toList();
                } else if (_filterStatus == 'inactive') {
                  products = products
                      .where((p) => p['isAvailable'] != true)
                      .toList();
                }

                products.sort((a, b) {
                  switch (_sortBy) {
                    case 'oldest':
                      return _getTime(a).compareTo(_getTime(b));
                    case 'price_high':
                      return ((b['price'] ?? 0) as num).compareTo(
                        (a['price'] ?? 0) as num,
                      );
                    case 'price_low':
                      return ((a['price'] ?? 0) as num).compareTo(
                        (b['price'] ?? 0) as num,
                      );
                    case 'name':
                      return (a['name'] ?? '').toString().compareTo(
                        (b['name'] ?? '').toString(),
                      );
                    default:
                      return _getTime(b).compareTo(_getTime(a));
                  }
                });

                if (products.isEmpty) {
                  return Center(
                    child: Text(
                      widget.lang.t('no_match'),
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final isAvailable = p['isAvailable'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: p['imageUrl'] != null
                                  ? Image.network(
                                      p['imageUrl'],
                                      width: 65,
                                      height: 65,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 65,
                                      height: 65,
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                            title: Text(
                              p['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'TShs ${p['price']} / ${p['unit']}',
                                  style: const TextStyle(
                                    color: Color(0xFF1E1B4B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Stock: ${p['stock']} ${p['unit']} • ${p['category']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isAvailable
                                    ? widget.lang.t('active')
                                    : widget.lang.t('inactive'),
                                style: TextStyle(
                                  color: isAvailable
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () => _toggleAvailability(
                                      p['id'],
                                      isAvailable,
                                    ),
                                    icon: Icon(
                                      isAvailable
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isAvailable
                                          ? widget.lang.t('deactivate')
                                          : widget.lang.t('activate'),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.grey.shade100,
                                ),
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () => _deleteProduct(p['id']),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                    ),
                                    label: Text(
                                      widget.lang.t('delete'),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
}
