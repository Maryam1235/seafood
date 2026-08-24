import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/notification_service.dart';

const _cloudName = 'dx7jrfytj';
const _uploadPreset = 'seafoods';

class ComplaintScreen extends StatefulWidget {
  final String? prefilledOrderId;
  final String? prefilledSellerId;

  const ComplaintScreen({
    super.key,
    this.prefilledOrderId,
    this.prefilledSellerId,
  });

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  static const _navy = Color(0xFF1E1B4B);

  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedOrderId;
  String? _selectedSellerId;
  // The full order data of the selected order — used to show a preview card
  Map<String, dynamic>? _selectedOrderData;
  String _category = 'Wrong item';
  File? _photo;
  bool _isLoading = false;

  final _categories = [
    'Wrong item',
    'Damaged / spoiled',
    'Late delivery',
    'Payment issue',
    'Missing item',
    'Poor quality',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedOrderId = widget.prefilledOrderId;
    _selectedSellerId = widget.prefilledSellerId;
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  // ── Open the order picker bottom sheet ───────────────────────────────────
  Future<void> _pickOrder(LanguageProvider lang, String uid) async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderPickerSheet(uid: uid, lang: lang),
    );
    if (picked == null) return;
    setState(() {
      _selectedOrderId = picked['id'] as String;
      _selectedOrderData = picked;
      // Pre-fill seller from first item
      final items = (picked['items'] as List?) ?? [];
      if (items.isNotEmpty) {
        _selectedSellerId = items.first['sellerId'] as String?;
      }
    });
  }

  // ── Photo picker ─────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<String?> _uploadPhoto(File file) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload'),
    )
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    return jsonDecode(body)['secure_url'] as String?;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit(LanguageProvider lang) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.isSwahili
              ? 'Tafadhali chagua agizo'
              : 'Please select an order'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String? photoUrl;
      if (_photo != null) photoUrl = await _uploadPhoto(_photo!);

      String? sellerId = _selectedSellerId;
      if (sellerId == null) {
        final orderDoc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(_selectedOrderId)
            .get();
        final items = (orderDoc.data()?['items'] as List?) ?? [];
        if (items.isNotEmpty) sellerId = items.first['sellerId'] as String?;
      }

      final complaintRef =
          await FirebaseFirestore.instance.collection('complaints').add({
        'customerId': uid,
        'sellerId': sellerId,
        'orderId': _selectedOrderId,
        'category': _category,
        'description': _descController.text.trim(),
        'photoUrl': photoUrl,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (sellerId != null) {
        await NotificationService.sendNewComplaintNotification(
          sellerId: sellerId,
          complaintId: complaintRef.id,
          orderId: _selectedOrderId!,
          category: _category,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isSwahili
                ? 'Malalamiko yametumwa!'
                : 'Complaint submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title:
            Text(lang.isSwahili ? 'Wasilisha Malalamiko' : 'File a Complaint'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Info banner ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lang.isSwahili
                          ? 'Tunatumia muda wa masaa 24 kushughulikia malalamiko yako.'
                          : 'We aim to resolve complaints within 24 hours.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.blue.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Order selector ────────────────────────────────
            if (widget.prefilledOrderId == null) ...[
              _label(lang.isSwahili ? 'Chagua Agizo' : 'Select Order'),

              // Tap button — opens picker sheet
              GestureDetector(
                onTap: () => _pickOrder(lang, uid),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedOrderId == null
                          ? Colors.grey.shade300
                          : _navy,
                      width: _selectedOrderId == null ? 1 : 2,
                    ),
                  ),
                  child: _selectedOrderId == null
                      // Nothing selected yet
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.receipt_long_outlined,
                                  color: Colors.grey.shade500, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.isSwahili
                                        ? 'Gonga kuchagua agizo'
                                        : 'Tap to choose an order',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  Text(
                                    lang.isSwahili
                                        ? 'Utaona orodha yako yote na maelezo'
                                        : 'You\'ll see all your orders with full details',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: Colors.grey.shade400),
                          ],
                        )
                      // Order selected — show rich preview
                      : _SelectedOrderPreview(
                          orderData: _selectedOrderData,
                          orderId: _selectedOrderId!,
                          lang: lang,
                          onChangeTap: () => _pickOrder(lang, uid),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Pre-filled order preview ──────────────────────
            if (widget.prefilledOrderId != null) ...[
              _label(lang.isSwahili ? 'Agizo' : 'Order'),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('orders')
                    .doc(widget.prefilledOrderId)
                    .get(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                  return _SelectedOrderPreview(
                    orderData: {'id': widget.prefilledOrderId, ...data},
                    orderId: widget.prefilledOrderId!,
                    lang: lang,
                    onChangeTap: null, // locked
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // ── Category ──────────────────────────────────────
            _label(
                lang.isSwahili ? 'Aina ya Malalamiko' : 'Complaint Category'),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: _inputDeco(
                lang.isSwahili ? 'Aina' : 'Category',
                Icons.category_outlined,
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),

            // ── Description ───────────────────────────────────
            _label(lang.isSwahili ? 'Maelezo' : 'Description'),
            TextFormField(
              controller: _descController,
              maxLines: 5,
              decoration: _inputDeco(
                lang.isSwahili
                    ? 'Eleza tatizo lako kwa undani...'
                    : 'Describe the issue in detail...',
                Icons.description_outlined,
              ),
              validator: (v) => (v == null || v.trim().length < 10)
                  ? (lang.isSwahili
                      ? 'Angalau herufi 10 zinahitajika'
                      : 'At least 10 characters required')
                  : null,
            ),
            const SizedBox(height: 16),

            // ── Photo ─────────────────────────────────────────
            _label(
                lang.isSwahili ? 'Picha (Hiari)' : 'Photo Evidence (Optional)'),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _photo != null ? _navy : Colors.grey.shade300,
                    width: _photo != null ? 2 : 1,
                  ),
                  image: _photo != null
                      ? DecorationImage(
                          image: FileImage(_photo!), fit: BoxFit.cover)
                      : null,
                ),
                child: _photo == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 32, color: Colors.grey.shade400),
                          const SizedBox(height: 6),
                          Text(
                            lang.isSwahili
                                ? 'Gonga kuongeza picha'
                                : 'Tap to add photo',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () => setState(() => _photo = null),
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Submit ────────────────────────────────────────
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _submit(lang),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  lang.isSwahili ? 'Tuma Malalamiko' : 'Submit Complaint',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF111827))),
      );

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E1B4B), width: 1.5),
        ),
      );
}

// ── Selected order preview card ───────────────────────────────────────────────
class _SelectedOrderPreview extends StatelessWidget {
  final Map<String, dynamic>? orderData;
  final String orderId;
  final LanguageProvider lang;
  final VoidCallback? onChangeTap;

  const _SelectedOrderPreview({
    required this.orderData,
    required this.orderId,
    required this.lang,
    required this.onChangeTap,
  });

  static const _navy = Color(0xFF1E1B4B);

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = orderData ?? {};
    final items = (data['items'] as List?) ?? [];
    final status = data['status'] as String? ?? 'pending';
    final total = (data['grandTotal'] ?? data['total'] ?? 0) as num;
    final createdAt = data['createdAt'] as Timestamp?;
    final shortId = orderId.substring(0, 6).toUpperCase();
    final sc = _statusColor(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long, color: _navy, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Order #$shortId',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: sc.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: TextStyle(
                            color: sc,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (createdAt != null)
                    Text(
                      '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}  ·  TShs ${total.toStringAsFixed(0)}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
            if (onChangeTap != null)
              GestureDetector(
                onTap: onChangeTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    lang.isSwahili ? 'Badilisha' : 'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Items preview (up to 2)
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...items.take(2).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: item['imageUrl'] != null
                          ? Image.network(
                              item['imageUrl'],
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imgBox(),
                            )
                          : _imgBox(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item['name'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'x${item['quantity']}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              )),
          if (items.length > 2)
            Text(
              '+${items.length - 2} ${lang.isSwahili ? 'bidhaa zaidi' : 'more items'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
        ],
      ],
    );
  }

  Widget _imgBox() => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(Icons.set_meal, size: 18, color: Colors.grey.shade400),
      );
}

// ── Order picker bottom sheet ─────────────────────────────────────────────────
class _OrderPickerSheet extends StatefulWidget {
  final String uid;
  final LanguageProvider lang;

  const _OrderPickerSheet({required this.uid, required this.lang});

  @override
  State<_OrderPickerSheet> createState() => _OrderPickerSheetState();
}

class _OrderPickerSheetState extends State<_OrderPickerSheet> {
  static const _navy = Color(0xFF1E1B4B);
  String _search = '';

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    if (widget.lang.isSwahili) {
      switch (s) {
        case 'pending':
          return 'Inasubiri';
        case 'confirmed':
          return 'Imethibitishwa';
        case 'delivered':
          return 'Imewasilishwa';
        case 'cancelled':
          return 'Imeghairiwa';
        default:
          return s;
      }
    }
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle + title ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: _navy),
                      const SizedBox(width: 10),
                      Text(
                        lang.isSwahili ? 'Chagua Agizo' : 'Select an Order',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  TextField(
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: lang.isSwahili
                          ? 'Tafuta kwa jina la bidhaa...'
                          : 'Search by product name...',
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.grey, size: 20),
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
                ],
              ),
            ),

            // ── Order list ─────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('customerId', isEqualTo: widget.uid)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            lang.isSwahili
                                ? 'Hakuna maagizo bado'
                                : 'No orders found',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  // Sort newest first
                  var docs = [...snap.data!.docs];
                  docs.sort((a, b) {
                    final aTs = ((a.data() as Map)['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    final bTs = ((b.data() as Map)['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    return bTs.compareTo(aTs);
                  });

                  // Filter by search
                  if (_search.isNotEmpty) {
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final items = (data['items'] as List?) ?? [];
                      return items.any((i) => (i['name'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_search));
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        lang.isSwahili
                            ? 'Hakuna maagizo yanayolingana'
                            : 'No matching orders',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final items = (data['items'] as List?) ?? [];
                      final status = data['status'] as String? ?? 'pending';
                      final total =
                          (data['grandTotal'] ?? data['total'] ?? 0) as num;
                      final createdAt = data['createdAt'] as Timestamp?;
                      final sc = _statusColor(status);

                      return GestureDetector(
                        onTap: () => Navigator.pop(
                          context,
                          {'id': doc.id, ...data},
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.shade100, blurRadius: 6),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Order #${doc.id.substring(0, 6).toUpperCase()}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          if (createdAt != null)
                                            Text(
                                              '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Status badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: sc.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                          color: sc,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Select arrow
                                    Icon(Icons.chevron_right,
                                        color: Colors.grey.shade400, size: 20),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Product image strip
                                if (items.isNotEmpty)
                                  Row(
                                    children: [
                                      // Images (up to 3)
                                      ...items.take(3).map((item) => Padding(
                                            padding:
                                                const EdgeInsets.only(right: 6),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: item['imageUrl'] != null
                                                  ? Image.network(
                                                      item['imageUrl'],
                                                      width: 44,
                                                      height: 44,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, __, ___) =>
                                                              _imgBox(),
                                                    )
                                                  : _imgBox(),
                                            ),
                                          )),
                                      const SizedBox(width: 4),
                                      // Names list
                                      Expanded(
                                        child: Text(
                                          items
                                              .take(3)
                                              .map((i) =>
                                                  '${i['name']} x${i['quantity']}')
                                              .join(', '),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                // More items + total
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (items.length > 3)
                                      Text(
                                        '+${items.length - 3} ${lang.isSwahili ? 'zaidi' : 'more'}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade400),
                                      )
                                    else
                                      const SizedBox(),
                                    Text(
                                      'TShs ${total.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: _navy,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgBox() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.set_meal, size: 20, color: Colors.grey.shade400),
      );
}
