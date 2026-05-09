import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Color themeColor;
  const EditProfileScreen({
    super.key,
    required this.userData,
    required this.themeColor,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _mobilePaymentController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.userData['fullName'] ?? '',
    );
    _usernameController = TextEditingController(
      text: widget.userData['username'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.userData['phone'] ?? '',
    );
    _mobilePaymentController = TextEditingController(
      text: widget.userData['mobilePayment'] ?? '',
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fullName': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'mobilePayment': _mobilePaymentController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: Colors.grey),
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
      borderSide: BorderSide(color: widget.themeColor, width: 1.5),
    ),
    filled: true,
    fillColor: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 50,
                backgroundColor: widget.themeColor.withOpacity(0.15),
                child: Icon(Icons.person, size: 55, color: widget.themeColor),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _fullNameController,
                decoration: _dec(lang.t('full_name'), Icons.person_outline),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Required';
                  if (RegExp(r'\d').hasMatch(v!)) {
                    return 'Name cannot contain numbers';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: _dec(lang.t('username'), Icons.alternate_email),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: _dec(lang.t('phone'), Icons.phone),
                keyboardType: TextInputType.phone,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Mobile payment number
              TextFormField(
                controller: _mobilePaymentController,
                decoration:
                    _dec(
                      lang.isSwahili
                          ? 'Nambari ya Malipo (M-Pesa / Airtel)'
                          : 'Mobile Payment Number (M-Pesa / Airtel)',
                      Icons.mobile_friendly,
                    ).copyWith(
                      helperText: lang.isSwahili
                          ? 'Wateja watatumia nambari hii kukutumia pesa'
                          : 'Customers will use this number to send you payment',
                      helperStyle: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              // Email - read only
              TextFormField(
                initialValue: widget.userData['email'] ?? '',
                decoration: _dec(lang.t('email'), Icons.email_outlined)
                    .copyWith(
                      suffixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.grey,
                        size: 18,
                      ),
                    ),
                readOnly: true,
                style: TextStyle(color: Colors.grey.shade500),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _mobilePaymentController.dispose();
    super.dispose();
  }
}
