import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Color themeColor;
  final VoidCallback? onOpenDrawer;

  const SettingsScreen({
    super.key,
    required this.themeColor,
    this.onOpenDrawer,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _authService.getUserData(user.uid);
      if (mounted) {
        setState(() {
          _userData = data;
          _notificationsEnabled = data?['notificationsEnabled'] ?? true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'notificationsEnabled': value,
      });
    }
  }

  Future<void> _logout() async {
    final lang = context.read<LanguageProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang.isSwahili ? 'Toka' : 'Log Out'),
        content: Text(
          lang.isSwahili
              ? 'Una uhakika unataka kutoka?'
              : 'Are you sure you want to log out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(lang.t('logout')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  void _showInfoSheet({
    required LanguageProvider lang,
    required IconData icon,
    required String title,
    required String content,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.themeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: widget.themeColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade400),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.7,
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

  void _showAboutDialog(LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Image.asset('assets/zanseafoodlogo.png', height: 32),
            const SizedBox(width: 10),
            const Text('ZanSeaFood'),
          ],
        ),
        content: Text(
          lang.isSwahili
              ? 'Toleo 1.0.0\n\nSoko la samaki safi la Zanzibar.\nImetengenezwa na ZanSeaFood Team.'
              : 'Version 1.0.0\n\nFresh seafood marketplace for Zanzibar.\nBuilt by the ZanSeaFood Team.',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(lang.isSwahili ? 'Mipangilio' : 'Settings'),
          backgroundColor: widget.themeColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final role = _userData?['role'] ?? 'customer';
    final fullName = _userData?['fullName'] ?? '';
    final email = _userData?['email'] ?? '';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.isSwahili ? 'Mipangilio' : 'Settings'),
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed:
              widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── Account card ──────────────────────────────────────────
          _buildAccountCard(lang, fullName, email, role, initial),
          const SizedBox(height: 8),

          // ── Language ──────────────────────────────────────────────
          _buildSectionHeader(
            lang.isSwahili ? 'Lugha' : 'Language',
            Icons.language,
          ),
          _buildLanguageTile(lang),
          const SizedBox(height: 8),

          // ── Notifications ─────────────────────────────────────────
          _buildSectionHeader(
            lang.isSwahili ? 'Arifa' : 'Notifications',
            Icons.notifications_outlined,
          ),
          _buildSwitchTile(
            icon: Icons.notifications_active_outlined,
            title: lang.isSwahili ? 'Arifa za Programu' : 'App Notifications',
            subtitle: lang.isSwahili
                ? 'Pokea arifa za maagizo na utoaji'
                : 'Receive order and delivery alerts',
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
          ),
          const SizedBox(height: 8),

          // ── Account ───────────────────────────────────────────────
          _buildSectionHeader(
            lang.isSwahili ? 'Akaunti' : 'Account',
            Icons.manage_accounts_outlined,
          ),
          _buildNavTile(
            icon: Icons.edit_outlined,
            title: lang.isSwahili ? 'Hariri Wasifu' : 'Edit Profile',
            subtitle: lang.isSwahili
                ? 'Badilisha jina, simu, na zaidi'
                : 'Change name, phone, and more',
            onTap: () async {
              if (_userData != null) {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      userData: _userData!,
                      themeColor: widget.themeColor,
                    ),
                  ),
                );
                if (updated == true) _loadUser();
              }
            },
          ),
          _buildNavTile(
            icon: Icons.lock_outline,
            title: lang.isSwahili ? 'Badilisha Nywila' : 'Change Password',
            subtitle: lang.isSwahili
                ? 'Tuma barua pepe ya kubadilisha nywila'
                : 'Send a password reset email',
            onTap: () => _sendPasswordReset(lang),
          ),
          const SizedBox(height: 8),

          // ── Support ───────────────────────────────────────────────
          _buildSectionHeader(
            lang.isSwahili ? 'Msaada' : 'Support',
            Icons.help_outline,
          ),
          _buildNavTile(
            icon: Icons.contact_support_outlined,
            title: lang.isSwahili ? 'Wasiliana Nasi' : 'Contact Us',
            subtitle: lang.isSwahili
                ? 'Pata msaada kupitia barua pepe'
                : 'Get help via email',
            onTap: () => _showInfoSheet(
              lang: lang,
              icon: Icons.contact_support_outlined,
              title: lang.isSwahili ? 'Wasiliana Nasi' : 'Contact Us',
              content: lang.isSwahili
                  ? 'Tuma barua pepe kwa:\nsupport@zanseafood.com\n\nAu piga simu:\n+255 699 000 000\n\nMasaa ya kazi:\nJumatatu – Ijumaa\n8:00 asubuhi – 6:00 jioni'
                  : 'Send us an email at:\nsupport@zanseafood.com\n\nOr call us at:\n+255 699 000 000\n\nWorking hours:\nMonday – Friday\n8:00 AM – 6:00 PM',
            ),
          ),
          _buildNavTile(
            icon: Icons.privacy_tip_outlined,
            title: lang.isSwahili ? 'Sera ya Faragha' : 'Privacy Policy',
            subtitle: lang.isSwahili
                ? 'Jinsi tunavyotumia data yako'
                : 'How we handle your data',
            onTap: () => _showInfoSheet(
              lang: lang,
              icon: Icons.privacy_tip_outlined,
              title: lang.isSwahili ? 'Sera ya Faragha' : 'Privacy Policy',
              content: lang.isSwahili
                  ? '1. Ukusanyaji wa Data\nTunakusanya taarifa unazotoa wakati wa usajili kama vile jina, barua pepe, na nambari ya simu.\n\n2. Matumizi ya Data\nData yako inatumika kutoa huduma za soko, kushughulikia maagizo, na kuboresha uzoefu wako.\n\n3. Usalama\nTunalinda data yako kwa kutumia Firebase na hatua za usalama za kisasa.\n\n4. Kushiriki Data\nHatushirikishi data yako na watu wa nje bila idhini yako, isipokuwa inapohitajika kisheria.\n\n5. Mawasiliano\nKwa maswali yoyote kuhusu faragha, wasiliana nasi kwa support@zanseafood.com'
                  : '1. Data Collection\nWe collect information you provide during registration such as name, email, and phone number.\n\n2. Use of Data\nYour data is used to provide marketplace services, process orders, and improve your experience.\n\n3. Security\nWe protect your data using Firebase and modern security practices.\n\n4. Data Sharing\nWe do not share your data with third parties without your consent, except where required by law.\n\n5. Contact\nFor any privacy questions, contact us at support@zanseafood.com',
            ),
          ),
          _buildNavTile(
            icon: Icons.description_outlined,
            title: lang.isSwahili ? 'Masharti ya Matumizi' : 'Terms of Service',
            subtitle: lang.isSwahili
                ? 'Sheria za kutumia programu'
                : 'Rules for using the app',
            onTap: () => _showInfoSheet(
              lang: lang,
              icon: Icons.description_outlined,
              title: lang.isSwahili
                  ? 'Masharti ya Matumizi'
                  : 'Terms of Service',
              content: lang.isSwahili
                  ? '1. Kukubaliana\nKwa kutumia ZanSeaFood, unakubali masharti haya.\n\n2. Akaunti\nUnawajibika kulinda nywila yako. Taarifa za uongo haziruhusiwi.\n\n3. Bidhaa na Maagizo\nWauzaji wanawajibika kwa ubora wa bidhaa. Maagizo yanayokamilika hayarudishwi isipokuwa kwa sababu maalum.\n\n4. Mwenendo\nMatumizi mabaya, udanganyifu, au ukiukaji wa sheria utasababisha kufutwa kwa akaunti.\n\n5. Mabadiliko\nTunaweza kubadilisha masharti haya wakati wowote. Tutakujulisha kupitia programu.\n\n6. Mawasiliano\nsupport@zanseafood.com'
                  : '1. Acceptance\nBy using ZanSeaFood, you agree to these terms.\n\n2. Account\nYou are responsible for keeping your password secure. False information is not permitted.\n\n3. Products & Orders\nSellers are responsible for product quality. Completed orders are non-refundable except in special cases.\n\n4. Conduct\nMisuse, fraud, or violation of laws will result in account termination.\n\n5. Changes\nWe may update these terms at any time. We will notify you through the app.\n\n6. Contact\nsupport@zanseafood.com',
            ),
          ),
          _buildNavTile(
            icon: Icons.info_outline,
            title: lang.isSwahili ? 'Kuhusu Programu' : 'About App',
            subtitle: 'ZanSeaFood v1.0.0',
            onTap: () => _showAboutDialog(lang),
          ),
          const SizedBox(height: 8),

          // ── Danger zone ───────────────────────────────────────────
          _buildSectionHeader(
            lang.isSwahili ? 'Hatua za Hatari' : 'Danger Zone',
            Icons.warning_amber_outlined,
            color: Colors.red.shade400,
          ),
          _buildNavTile(
            icon: Icons.logout,
            title: lang.t('logout'),
            subtitle: lang.isSwahili
                ? 'Toka kwenye akaunti yako'
                : 'Sign out of your account',
            iconColor: Colors.red.shade400,
            titleColor: Colors.red.shade400,
            onTap: _logout,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Account summary card ─────────────────────────────────────────────────
  Widget _buildAccountCard(
    LanguageProvider lang,
    String fullName,
    String email,
    String role,
    String initial,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: widget.themeColor.withValues(alpha: 0.15),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: widget.themeColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: widget.themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: widget.themeColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ───────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    final c = color ?? Colors.grey.shade500;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: c,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ── Language tile ────────────────────────────────────────────────────────
  Widget _buildLanguageTile(LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.translate,
                    color: widget.themeColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.isSwahili ? 'Lugha ya Programu' : 'App Language',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        lang.isSwahili
                            ? 'Chagua lugha unayopendelea'
                            : 'Choose your preferred language',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _LangButton(
                    label: 'English',
                    flag: '🇬🇧',
                    selected: !lang.isSwahili,
                    themeColor: widget.themeColor,
                    onTap: () => lang.setLanguage('en'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LangButton(
                    label: 'Kiswahili',
                    flag: '🇹🇿',
                    selected: lang.isSwahili,
                    themeColor: widget.themeColor,
                    onTap: () => lang.setLanguage('sw'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Switch tile ──────────────────────────────────────────────────────────
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.themeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: widget.themeColor, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: widget.themeColor,
        ),
      ),
    );
  }

  // ── Nav tile ─────────────────────────────────────────────────────────────
  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    final ic = iconColor ?? widget.themeColor;
    final tc = titleColor ?? const Color(0xFF111827);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ic.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: ic, size: 18),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: tc,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey.shade400,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _sendPasswordReset(LanguageProvider lang) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.isSwahili
                  ? 'Barua pepe ya kubadilisha nywila imetumwa kwa $email'
                  : 'Password reset email sent to $email',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ── Language button ──────────────────────────────────────────────────────────
class _LangButton extends StatelessWidget {
  final String label;
  final String flag;
  final bool selected;
  final Color themeColor;
  final VoidCallback onTap;

  const _LangButton({
    required this.label,
    required this.flag,
    required this.selected,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? themeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? themeColor : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, color: Colors.white, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}
