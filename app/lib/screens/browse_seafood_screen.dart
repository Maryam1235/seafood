import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/recommendation_event_service.dart';
import 'login_screen.dart';
import 'cart_screen.dart';

class BrowseSeafoodScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const BrowseSeafoodScreen({super.key, this.onOpenDrawer});

  @override
  State<BrowseSeafoodScreen> createState() => _BrowseSeafoodScreenState();
}

class _BrowseSeafoodScreenState extends State<BrowseSeafoodScreen> {
  String _search = '';
  String _selectedCategory = 'all';
  String _username = '';
  final _authService = AuthService();
  final _searchController = TextEditingController();

  static const _navy = Color(0xFF1E1B4B);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _authService.getUserData(user.uid);
      if (mounted && data != null) {
        setState(() => _username = data['username'] ?? '');
      }
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  String _catLabel(String key, LanguageProvider lang) {
    if (key == 'all') return lang.isSwahili ? 'Zote' : 'All';
    return lang.t(key);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          // SliverAppBar with search
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed:
                  widget.onOpenDrawer ??
                  () => Scaffold.of(context).openDrawer(),
            ),
            actions: [
              // Cart icon with badge
              StreamBuilder<QuerySnapshot>(
                stream: CartService().cartStream(),
                builder: (context, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartScreen()),
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: _logout,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E1B4B), Color(0xFF3730A3)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(72, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.isSwahili
                              ? 'Habari, $_username 👋'
                              : 'Hello, $_username 👋',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang.isSwahili
                              ? 'Tafuta Samaki Safi'
                              : 'Find Fresh Seafood',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Search bar
                        Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) =>
                                setState(() => _search = v.toLowerCase()),
                            decoration: InputDecoration(
                              hintText: lang.isSwahili
                                  ? 'Tafuta samaki...'
                                  : 'Search seafood...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.grey,
                                size: 20,
                              ),
                              suffixIcon: _search.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _search = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Category chips
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('isAvailable', isEqualTo: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox(height: 56);
                final cats = [
                  'all',
                  ...{
                    ...snap.data!.docs.map(
                      (d) => (d.data() as Map)['category'] as String? ?? '',
                    ),
                  }.where((c) => c.isNotEmpty),
                ];

                return Container(
                  color: Colors.white,
                  height: 52,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount: cats.length,
                    itemBuilder: (context, i) {
                      final cat = cats[i];
                      final selected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? _navy : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? _navy : Colors.grey.shade200,
                            ),
                          ),
                          child: Text(
                            _catLabel(cat, lang),
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          SliverToBoxAdapter(child: _RecommendedProductsSection(lang: lang)),

          // Products
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('isAvailable', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.set_meal,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          lang.isSwahili
                              ? 'Hakuna bidhaa zinazopatikana'
                              : 'No products available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              var products = snapshot.data!.docs.map((d) {
                return {'id': d.id, ...d.data() as Map<String, dynamic>};
              }).toList();

              if (_search.isNotEmpty) {
                products = products.where((p) {
                  final name = (p['name'] ?? '').toString().toLowerCase();
                  final cat = (p['category'] ?? '').toString().toLowerCase();
                  final loc = (p['location'] ?? '').toString().toLowerCase();
                  return name.contains(_search) ||
                      cat.contains(_search) ||
                      loc.contains(_search);
                }).toList();
              }

              if (_selectedCategory != 'all') {
                products = products
                    .where((p) => p['category'] == _selectedCategory)
                    .toList();
              }

              if (products.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      lang.isSwahili
                          ? 'Hakuna bidhaa zinazolingana'
                          : 'No products match',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _ProductCard(product: products[index], lang: lang),
                    childCount: products.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _RecommendedProductsSection extends StatelessWidget {
  final LanguageProvider lang;
  const _RecommendedProductsSection({required this.lang});

  static const _navy = Color(0xFF1E1B4B);

  Future<Set<String>> _purchasedProductIds(String userId) async {
    final purchasedSnap = await FirebaseFirestore.instance
        .collection('purchase_history')
        .where('userId', isEqualTo: userId)
        .get();
    return purchasedSnap.docs
        .map((doc) => doc.data()['productId']?.toString())
        .whereType<String>()
        .toSet();
  }

  bool _isSellable(Map<String, dynamic> product) {
    final stock = (product['stock'] ?? 0) as num;
    return product['isAvailable'] != false && stock > 0;
  }

  Future<List<Map<String, dynamic>>> _loadProductsByIds(
    List<String> productIds,
    Set<String> purchasedIds,
  ) async {
    final products = <Map<String, dynamic>>[];
    for (final productId in productIds.take(10)) {
      final productSnap = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      if (!productSnap.exists) continue;

      final product = {
        'id': productSnap.id,
        ...productSnap.data() as Map<String, dynamic>,
      };
      final repeatBuy = product['repeatBuy'] == true;
      if (!_isSellable(product)) continue;
      if (purchasedIds.contains(productId) && !repeatBuy) continue;
      products.add(product);
    }
    return products;
  }

  /// When no recommendation doc (or all recs filtered out), show available products.
  Future<List<Map<String, dynamic>>> _loadPopularFallback(
    Set<String> purchasedIds,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .where('isAvailable', isEqualTo: true)
        .limit(20)
        .get();

    final products = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final product = {'id': doc.id, ...doc.data()};
      final stock = (product['stock'] ?? 0) as num;
      final repeatBuy = product['repeatBuy'] == true;
      if (stock <= 0) continue;
      if (purchasedIds.contains(doc.id) && !repeatBuy) continue;
      products.add(product);
      if (products.length >= 10) break;
    }
    return products;
  }

  Future<List<Map<String, dynamic>>> _loadRecommendedProducts(
    String userId,
    List<dynamic> recommendationItems,
  ) async {
    final purchasedIds = await _purchasedProductIds(userId);

    final recommendedIds = recommendationItems
        .whereType<Map>()
        .map((item) => item['productId']?.toString())
        .whereType<String>()
        .toList();

    if (recommendedIds.isNotEmpty) {
      final products = await _loadProductsByIds(recommendedIds, purchasedIds);
      if (products.isNotEmpty) return products;
    }

    // Cold-start / empty recs / all recs out of stock → popular available products.
    return _loadPopularFallback(purchasedIds);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recommendations')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final items = (data?['items'] as List?) ?? [];

        return FutureBuilder<List<Map<String, dynamic>>>(
          // Include item count in future identity so Stream updates re-fetch.
          future: _loadRecommendedProducts(userId, items),
          builder: (context, productSnap) {
            if (productSnap.connectionState == ConnectionState.waiting &&
                !productSnap.hasData) {
              return const SizedBox.shrink();
            }
            final products = productSnap.data ?? [];
            if (products.isEmpty) return const SizedBox.shrink();

            return Container(
              color: const Color(0xFFF5F6FA),
              padding: const EdgeInsets.fromLTRB(16, 16, 0, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: _navy, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          lang.isSwahili
                              ? 'Mapendekezo Kwako'
                              : 'Recommended For You',
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 210,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => _RecommendedProductCard(
                        product: products[index],
                        lang: lang,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RecommendedProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final LanguageProvider lang;
  const _RecommendedProductCard({required this.product, required this.lang});

  static const _navy = Color(0xFF1E1B4B);

  @override
  Widget build(BuildContext context) {
    final imageUrl = product['imageUrl'];
    final name = product['name'] ?? '';
    final price = product['price'];
    final unit = product['unit'] ?? 'kg';
    final category = product['category'] ?? '';

    return GestureDetector(
      onTap: () {
        RecommendationEventService.logClick(product);
        RecommendationEventService.logView(product);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ProductDetailSheet(
            product: product,
            lang: lang,
            rootContext: context,
          ),
        );
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      height: 105,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang.t(category.isNotEmpty ? category : 'cat_other'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'TShs ${price?.toStringAsFixed(0) ?? '0'} / $unit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 105,
    width: double.infinity,
    color: Colors.grey.shade100,
    child: Icon(Icons.set_meal, size: 34, color: Colors.grey.shade300),
  );
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final LanguageProvider lang;
  const _ProductCard({required this.product, required this.lang});

  static const _navy = Color(0xFF1E1B4B);

  @override
  Widget build(BuildContext context) {
    final name = product['name'] ?? '';
    final price = product['price'];
    final unit = product['unit'] ?? 'kg';
    final stock = product['stock'];
    final location = product['location'] ?? '';
    final imageUrl = product['imageUrl'];
    final category = product['category'] ?? '';

    return GestureDetector(
      onTap: () {
        RecommendationEventService.logClick(product);
        RecommendationEventService.logView(product);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ProductDetailSheet(
            product: product,
            lang: lang,
            rootContext: context,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                // Category badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _navy.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      lang.t(category.isNotEmpty ? category : 'cat_other'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TShs ${price?.toStringAsFixed(0) ?? '0'} / $unit',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 11,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$stock $unit',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 120,
    width: double.infinity,
    color: Colors.grey.shade100,
    child: Icon(Icons.set_meal, size: 40, color: Colors.grey.shade300),
  );
}

class _ProductDetailSheet extends StatelessWidget {
  final Map<String, dynamic> product;
  final LanguageProvider lang;
  final BuildContext rootContext;
  const _ProductDetailSheet({
    required this.product,
    required this.lang,
    required this.rootContext,
  });

  static const _navy = Color(0xFF1E1B4B);

  @override
  Widget build(BuildContext context) {
    final imageUrl = product['imageUrl'];
    final name = product['name'] ?? '';
    final price = product['price'];
    final unit = product['unit'] ?? 'kg';
    final stock = product['stock'];
    final location = product['location'] ?? '';
    final description = product['description'] ?? '';
    final category = product['category'] ?? '';
    final sellerId = product['sellerId'];

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (imageUrl != null)
              Image.network(
                imageUrl,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            else
              Container(
                height: 200,
                color: Colors.grey.shade100,
                child: Icon(
                  Icons.set_meal,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _navy.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          lang.t(category.isNotEmpty ? category : 'cat_other'),
                          style: const TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'TShs ${price?.toStringAsFixed(0) ?? '0'} / $unit',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(
                        Icons.inventory_2_outlined,
                        '${lang.isSwahili ? 'Hisa' : 'Stock'}: $stock $unit',
                        Colors.green,
                      ),
                      _chip(
                        Icons.location_on_outlined,
                        location,
                        Colors.orange,
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(lang.isSwahili ? 'Maelezo' : 'Description'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                  if (sellerId != null) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(
                      lang.isSwahili
                          ? 'Maelezo ya Muuzaji'
                          : 'Seller Information',
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(sellerId)
                          .get(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        final seller =
                            snap.data!.data() as Map<String, dynamic>?;
                        if (seller == null) return const SizedBox();
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _navy.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _navy.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: _navy,
                                child: Text(
                                  (seller['username'] ?? '?')
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      seller['fullName'] ??
                                          seller['username'] ??
                                          '',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    _sellerRow(
                                      Icons.phone,
                                      seller['phone'] ?? 'N/A',
                                      Colors.green.shade700,
                                    ),
                                    const SizedBox(height: 3),
                                    _sellerRow(
                                      Icons.location_on,
                                      seller['location']?['name'] ?? 'N/A',
                                      Colors.orange.shade700,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await CartService().addToCart(product);
                          RecommendationEventService.logAddToCart(product);
                          if (context.mounted) {
                            Navigator.pop(context);
                            final nav = Navigator.of(rootContext);
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  lang.isSwahili
                                      ? 'Imeongezwa kwenye magulio!'
                                      : 'Added to cart!',
                                ),
                                backgroundColor: _navy,
                                action: SnackBarAction(
                                  label: lang.isSwahili
                                      ? 'Tazama'
                                      : 'View Cart',
                                  textColor: Colors.white,
                                  onPressed: () => nav.push(
                                    MaterialPageRoute(
                                      builder: (_) => const CartScreen(),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  lang.isSwahili
                                      ? 'Samahani, hisa haitoshi!'
                                      : 'Sorry, not enough stock available!',
                                ),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: Text(
                        lang.isSwahili
                            ? 'Ongeza kwenye Magulio'
                            : 'Add to Cart',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Color(0xFF111827),
    ),
  );

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _sellerRow(IconData icon, String text, Color color) => Row(
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
