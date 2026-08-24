import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/notification_service.dart';

class SellerComplaintsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const SellerComplaintsScreen({super.key, this.onOpenDrawer});

  @override
  State<SellerComplaintsScreen> createState() => _SellerComplaintsScreenState();
}

class _SellerComplaintsScreenState extends State<SellerComplaintsScreen>
    with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF1E1B4B);
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final sellerId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.isSwahili ? 'Malalamiko' : 'Complaints'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed:
              widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: lang.isSwahili ? 'Wazi' : 'Open'),
            Tab(text: lang.isSwahili ? 'Kujibiwa' : 'Responded'),
            Tab(text: lang.isSwahili ? 'Imefungwa' : 'Resolved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ComplaintsTab(sellerId: sellerId, status: 'open', lang: lang),
          _ComplaintsTab(sellerId: sellerId, status: 'responded', lang: lang),
          _ComplaintsTab(sellerId: sellerId, status: 'resolved', lang: lang),
        ],
      ),
    );
  }
}

// ── _ComplaintsTab — StatefulWidget so it has a stable context ───────────────
class _ComplaintsTab extends StatefulWidget {
  final String sellerId;
  final String status;
  final LanguageProvider lang;

  const _ComplaintsTab({
    required this.sellerId,
    required this.status,
    required this.lang,
  });

  @override
  State<_ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<_ComplaintsTab> {
  static const _navy = Color(0xFF1E1B4B);

  Color _statusColor(String s) {
    switch (s) {
      case 'open':
        return Colors.orange;
      case 'responded':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('sellerId', isEqualTo: widget.sellerId)
          .where('status', isEqualTo: widget.status)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 70, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  widget.status == 'open'
                      ? (lang.isSwahili
                          ? 'Hakuna malalamiko wazi'
                          : 'No open complaints')
                      : (lang.isSwahili
                          ? 'Hakuna malalamiko'
                          : 'No complaints here'),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final doc = docs[index];
            final complaint = doc.data() as Map<String, dynamic>;
            final category = complaint['category'] as String? ?? '';
            final desc = complaint['description'] as String? ?? '';
            final photoUrl = complaint['photoUrl'] as String?;
            final createdAt = complaint['createdAt'] as Timestamp?;
            final orderId = complaint['orderId'] as String? ?? '';
            final cStatus = complaint['status'] as String? ?? 'open';

            return _ComplaintCard(
              key: ValueKey(doc.id),
              doc: doc,
              category: category,
              desc: desc,
              photoUrl: photoUrl,
              createdAt: createdAt,
              orderId: orderId,
              cStatus: cStatus,
              customerId: complaint['customerId'] as String?,
              response: complaint['response'] as String?,
              statusColor: _statusColor(cStatus),
              lang: lang,
              navy: _navy,
            );
          },
        );
      },
    );
  }
}

// ── Each complaint is its own StatefulWidget — owns its dialog context ────────
class _ComplaintCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final String category;
  final String desc;
  final String? photoUrl;
  final Timestamp? createdAt;
  final String orderId;
  final String cStatus;
  final String? customerId;
  final String? response;
  final Color statusColor;
  final LanguageProvider lang;
  final Color navy;

  const _ComplaintCard({
    super.key,
    required this.doc,
    required this.category,
    required this.desc,
    this.photoUrl,
    this.createdAt,
    required this.orderId,
    required this.cStatus,
    this.customerId,
    this.response,
    required this.statusColor,
    required this.lang,
    required this.navy,
  });

  @override
  State<_ComplaintCard> createState() => _ComplaintCardState();
}

class _ComplaintCardState extends State<_ComplaintCard> {
  bool _resolving = false;

  Future<void> _markResolved() async {
    if (_resolving) return;
    setState(() => _resolving = true);
    try {
      await widget.doc.reference.update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  /// Opens the respond dialog. The dialog is a standalone widget — it never
  /// touches the card's context after the first await, so Firestore stream
  /// rebuilds cannot invalidate it.
  void _openRespondDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RespondDialog(
        ref: widget.doc.reference,
        customerId: widget.customerId,
        lang: widget.lang,
        navy: widget.navy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final statusColor = widget.statusColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (widget.orderId.isNotEmpty)
                      Text(
                        'Order #${widget.orderId.substring(0, 6).toUpperCase()}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.cStatus[0].toUpperCase() +
                        widget.cStatus.substring(1),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer info
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.customerId)
                      .get(),
                  builder: (_, custSnap) {
                    final c = custSnap.data?.data() as Map<String, dynamic>?;
                    return Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          c?['fullName'] ?? c?['username'] ?? 'Customer',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 12),
                        if (widget.createdAt != null) ...[
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.createdAt!.toDate().day}/'
                            '${widget.createdAt!.toDate().month}/'
                            '${widget.createdAt!.toDate().year}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  widget.desc,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),

                // Photo
                if (widget.photoUrl != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      widget.photoUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],

                // Seller response
                if (widget.response != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.reply,
                                size: 14, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Text(
                              lang.isSwahili ? 'Jibu lako' : 'Your Response',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.response!,
                          style: TextStyle(
                              fontSize: 13, color: Colors.blue.shade800),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action buttons
                if (widget.cStatus == 'open' ||
                    widget.cStatus == 'responded') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (widget.cStatus == 'responded') ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _resolving ? null : _markResolved,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _resolving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.green),
                                  )
                                : Text(
                                    lang.isSwahili ? 'Funga' : 'Mark Resolved'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openRespondDialog,
                          icon: const Icon(Icons.reply, size: 16),
                          label: Text(lang.isSwahili ? 'Jibu' : 'Respond'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Self-contained respond dialog widget — no external context dependency ─────
class _RespondDialog extends StatefulWidget {
  final DocumentReference ref;
  final String? customerId;
  final LanguageProvider lang;
  final Color navy;

  const _RespondDialog({
    required this.ref,
    this.customerId,
    required this.lang,
    required this.navy,
  });

  @override
  State<_RespondDialog> createState() => _RespondDialogState();
}

class _RespondDialogState extends State<_RespondDialog> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    if (!mounted) return;

    setState(() => _sending = true);

    // Capture navigator before any await
    final nav = Navigator.of(context);

    try {
      await widget.ref.update({
        'response': text,
        'status': 'responded',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (widget.customerId != null) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final sellerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          final sellerName = sellerDoc.data()?['fullName'] ??
              sellerDoc.data()?['username'] ??
              'Seller';
          await NotificationService.sendComplaintResponseNotification(
            customerId: widget.customerId!,
            complaintId: widget.ref.id,
            sellerName: sellerName,
          );
        }
      }

      // Use the captured navigator — safe even if the tree rebuilt
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(lang.isSwahili ? 'Jibu Malalamiko' : 'Respond to Complaint'),
      content: TextField(
        controller: _ctrl,
        maxLines: 4,
        autofocus: true,
        enabled: !_sending,
        decoration: InputDecoration(
          hintText: lang.isSwahili
              ? 'Andika jibu lako hapa...'
              : 'Write your response here...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(lang.isSwahili ? 'Ghairi' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.navy,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(lang.isSwahili ? 'Tuma' : 'Send'),
        ),
      ],
    );
  }
}
