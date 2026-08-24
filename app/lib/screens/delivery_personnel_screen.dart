import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/language_provider.dart';
import 'chat_screen.dart';

class DeliveryPersonnelScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const DeliveryPersonnelScreen({super.key, this.onOpenDrawer});

  String get _currentUid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final uid = _currentUid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.t('delivery_personnel')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1B4B), Color(0xFF3730A3)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Stream all drivers
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'driver')
            .snapshots(),
        builder: (context, driverSnap) {
          if (driverSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!driverSnap.hasData || driverSnap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delivery_dining_outlined,
                    size: 90,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.isSwahili
                        ? 'Hakuna madereva wanaopatikana'
                        : 'No delivery personnel available',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Stream all chats this customer is part of — used to sort drivers
          // by most recent message and count unread per driver
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: uid)
                .snapshots(),
            builder: (context, chatSnap) {
              final chatDocs = chatSnap.data?.docs ?? [];

              // Build a map: driverId → chat doc
              final Map<String, Map<String, dynamic>> chatByDriver = {};
              for (final doc in chatDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final participants = List<String>.from(
                  data['participants'] ?? [],
                );
                final driverId = participants.firstWhere(
                  (p) => p != uid,
                  orElse: () => '',
                );
                if (driverId.isNotEmpty) {
                  chatByDriver[driverId] = {'id': doc.id, ...data};
                }
              }

              // Sort drivers: those with a recent chat first (by lastAt desc),
              // then drivers with no chat at the end
              final drivers = [...driverSnap.data!.docs];
              drivers.sort((a, b) {
                final aChat = chatByDriver[a.id];
                final bChat = chatByDriver[b.id];
                final aTs =
                    (aChat?['lastAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                        0;
                final bTs =
                    (bChat?['lastAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                        0;
                return bTs.compareTo(aTs); // newest first
              });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: drivers.length,
                itemBuilder: (context, index) {
                  final doc = drivers[index];
                  final driver = doc.data() as Map<String, dynamic>;
                  final name =
                      driver['fullName'] ?? driver['username'] ?? 'Driver';
                  final phone = driver['phone'] ?? '';
                  final isOnline = driver['isOnline'] == true;
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
                  final chatData = chatByDriver[doc.id];
                  final chatId = chatData?['id'] as String?;
                  final lastMessage = chatData?['lastMessage'] as String? ?? '';

                  return _DriverCard(
                    driverId: doc.id,
                    name: name,
                    phone: phone,
                    initial: initial,
                    isOnline: isOnline,
                    chatId: chatId,
                    lastMessage: lastMessage,
                    currentUid: uid,
                    lang: lang,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ── Driver card ──────────────────────────────────────────────────────────────
class _DriverCard extends StatelessWidget {
  final String driverId;
  final String name;
  final String phone;
  final String initial;
  final bool isOnline;
  final String? chatId;
  final String lastMessage;
  final String currentUid;
  final LanguageProvider lang;

  static const _navy = Color(0xFF1E1B4B);
  static const _indigo = Color(0xFF3730A3);

  const _DriverCard({
    required this.driverId,
    required this.name,
    required this.phone,
    required this.initial,
    required this.isOnline,
    required this.chatId,
    required this.lastMessage,
    required this.currentUid,
    required this.lang,
  });

  Future<void> _call(BuildContext context) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isSwahili
                ? 'Nambari ya simu haipatikani'
                : 'Phone number not available',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isSwahili
                ? 'Imeshindwa kupiga simu'
                : 'Could not launch phone call',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(driverId: driverId, driverName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stream unread messages sent by the driver to this customer
    final unreadStream = chatId == null
        ? Stream<int>.value(0)
        : FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('senderId', isEqualTo: driverId)
            .snapshots()
            .map(
              (snap) => snap.docs.where((d) => d.data()['read'] != true).length,
            );

    return StreamBuilder<int>(
      stream: unreadStream,
      initialData: 0,
      builder: (context, unreadSnap) {
        final unreadCount = unreadSnap.data ?? 0;
        final hasUnread = unreadCount > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: hasUnread
                ? Border.all(color: _indigo.withValues(alpha: 0.4), width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar + online dot
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: _indigo.withValues(alpha: 0.12),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _indigo,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? Colors.green
                                  : Colors.grey.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Driver info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  hasUnread ? FontWeight.bold : FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 13,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                phone.isNotEmpty ? phone : '—',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          _DeliveryStats(driverId: driverId, lang: lang),
                          // Last message preview
                          if (lastMessage.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 12,
                                  color: hasUnread
                                      ? _indigo
                                      : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    lastMessage,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hasUnread
                                          ? _indigo
                                          : Colors.grey.shade500,
                                      fontWeight: hasUnread
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Online/Offline badge
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? Colors.green.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isOnline
                                ? (lang.isSwahili ? 'Mtandaoni' : 'Online')
                                : (lang.isSwahili ? 'Nje' : 'Offline'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOnline
                                  ? Colors.green.shade700
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        // Unread badge
                        if (hasUnread) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount ${lang.isSwahili ? 'mpya' : 'new'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _call(context),
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: Text(
                          lang.isSwahili ? 'Piga Simu' : 'Call',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _openChat(context),
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 18,
                              ),
                              label: Text(
                                lang.isSwahili ? 'Tuma Ujumbe' : 'Message',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _navy,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          // Badge on the Message button
                          if (hasUnread)
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
        );
      },
    );
  }
}

// ── Delivery stats ────────────────────────────────────────────────────────────
class _DeliveryStats extends StatelessWidget {
  final String driverId;
  final LanguageProvider lang;

  const _DeliveryStats({required this.driverId, required this.lang});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('delivery.driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'delivered')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Row(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 13,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Text(
              '$count ${lang.isSwahili ? 'utoaji' : count == 1 ? 'delivery' : 'deliveries'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        );
      },
    );
  }
}
