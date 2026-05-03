import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'chat_screen.dart';

/// Shows all chat conversations the driver is part of,
/// with unread count badges and last message preview.
class DriverMessagesScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const DriverMessagesScreen({super.key, this.onOpenDrawer});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.isSwahili ? 'Ujumbe' : 'Messages'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF004D40), Color(0xFF00695C)],
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
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: _uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Sort client-side by lastAt descending — avoids needing a
          // Firestore composite index on (participants + lastAt)
          final docs = [...(snapshot.data?.docs ?? [])];
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTs =
                (aData['lastAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bTs =
                (bData['lastAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bTs.compareTo(aTs);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.isSwahili ? 'Hakuna ujumbe bado' : 'No messages yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.isSwahili
                        ? 'Wateja watakuwasiliana nawe hapa'
                        : 'Customers will contact you here',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final chat = doc.data() as Map<String, dynamic>;
              final participants = List<String>.from(
                chat['participants'] ?? [],
              );
              // The other person is whoever is NOT the driver
              final otherUid = participants.firstWhere(
                (id) => id != _uid,
                orElse: () => '',
              );
              final lastMessage = chat['lastMessage'] as String? ?? '';

              return _ConversationTile(
                chatId: doc.id,
                otherUid: otherUid,
                lastMessage: lastMessage,
                driverUid: _uid,
                lang: lang,
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String chatId;
  final String otherUid;
  final String lastMessage;
  final String driverUid;
  final LanguageProvider lang;

  const _ConversationTile({
    required this.chatId,
    required this.otherUid,
    required this.lastMessage,
    required this.driverUid,
    required this.lang,
  });

  static const _teal = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .get(),
      builder: (context, snap) {
        final userData = snap.data?.data() as Map<String, dynamic>?;
        final name =
            userData?['fullName'] ?? userData?['username'] ?? 'Customer';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

        return StreamBuilder<QuerySnapshot>(
          // Count unread messages sent by the other person
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .where('senderId', isEqualTo: otherUid)
              .snapshots(),
          builder: (context, unreadSnap) {
            // Count messages where read != true (includes missing field)
            final unreadCount =
                unreadSnap.data?.docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['read'] != true;
                }).length ??
                0;

            return GestureDetector(
              onTap: () async {
                // Mark all unread messages from the other person as read
                final unreadDocs = unreadSnap.data?.docs ?? [];
                for (final d in unreadDocs) {
                  d.reference.update({'read': true});
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      driverId: otherUid,
                      driverName: name,
                      isDriverView: true,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: _teal.withValues(alpha: 0.12),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _teal,
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Name + last message
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              lastMessage.isNotEmpty
                                  ? lastMessage
                                  : (lang.isSwahili
                                        ? 'Gusa kuanza mazungumzo'
                                        : 'Tap to start chatting'),
                              style: TextStyle(
                                fontSize: 13,
                                color: unreadCount > 0
                                    ? const Color(0xFF111827)
                                    : Colors.grey.shade500,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Unread badge or chevron
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _teal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
