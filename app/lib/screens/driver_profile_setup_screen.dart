import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'driver_dashboard.dart';

const _cloudName = 'dx7jrfytj';
const _uploadPreset = 'seafoods';

class DriverProfileSetupScreen extends StatefulWidget {
  const DriverProfileSetupScreen({super.key});

  @override
  State<DriverProfileSetupScreen> createState() =>
      _DriverProfileSetupScreenState();
}

class _DriverProfileSetupScreenState extends State<DriverProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  static const _navy = Color(0xFF1E1B4B);
  static const _indigo = Color(0xFF3730A3);

  final _dobController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _licenseController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _plateController = TextEditingController();
  final _emergencyController = TextEditingController();

  File? _idCardImage;
  File? _licenseImage;
  File? _dcLetterImage;
  bool _isLoading = false;

  Future<File?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return null;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
    );
    return picked != null ? File(picked.path) : null;
  }

  Future<String?> _uploadImage(File file) async {
    final req =
        http.MultipartRequest(
            'POST',
            Uri.parse(
              'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
            ),
          )
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    return jsonDecode(body)['secure_url'];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idCardImage == null ||
        _licenseImage == null ||
        _dcLetterImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload all required documents'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final idUrl = await _uploadImage(_idCardImage!);
      final licUrl = await _uploadImage(_licenseImage!);
      final dcUrl = await _uploadImage(_dcLetterImage!);
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'driverProfile': {
          'dateOfBirth': _dobController.text.trim(),
          'nationalId': _nationalIdController.text.trim(),
          'licenseNumber': _licenseController.text.trim(),
          'vehicleType': _vehicleController.text.trim(),
          'licensePlate': _plateController.text.trim(),
          'emergencyContact': _emergencyController.text.trim(),
          'idCardUrl': idUrl,
          'licenseUrl': licUrl,
          'dcLetterUrl': dcUrl,
          'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp(),
        },
        'profileComplete': true,
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverDashboard()),
        );
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

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: _navy,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_navy, _indigo],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white24,
                          child: Icon(
                            Icons.delivery_dining,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          lang.isSwahili
                              ? 'Kamilisha Wasifu Wako'
                              : 'Complete Your Profile',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          lang.isSwahili
                              ? 'Jaza taarifa zako ili kuanza kufanya kazi'
                              : 'Fill in your details to start delivering',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Personal Info
                    _sectionCard(
                      icon: Icons.person_outline,
                      title: lang.isSwahili
                          ? 'Taarifa Binafsi'
                          : 'Personal Information',
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime(2000),
                              firstDate: DateTime(1950),
                              lastDate: DateTime.now().subtract(
                                const Duration(days: 365 * 18),
                              ),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF1E1B4B),
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _dobController.text =
                                    '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: _field(
                              _dobController,
                              lang.isSwahili
                                  ? 'Tarehe ya Kuzaliwa'
                                  : 'Date of Birth',
                              Icons.calendar_today_outlined,
                              hint: lang.isSwahili
                                  ? 'Gusa kuchagua tarehe'
                                  : 'Tap to select date',
                            ),
                          ),
                        ),
                        _field(
                          _nationalIdController,
                          lang.isSwahili
                              ? 'Nambari ya NIDA'
                              : 'National ID (NIDA)',
                          Icons.badge_outlined,
                        ),
                        _field(
                          _emergencyController,
                          lang.isSwahili
                              ? 'Nambari ya Dharura'
                              : 'Emergency Contact',
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          isTanzaniaPhone: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Info
                    _sectionCard(
                      icon: Icons.directions_car_outlined,
                      title: lang.isSwahili
                          ? 'Taarifa za Gari'
                          : 'Vehicle Information',
                      children: [
                        _field(
                          _licenseController,
                          lang.isSwahili
                              ? 'Nambari ya Leseni'
                              : 'Driver License Number',
                          Icons.drive_eta_outlined,
                        ),
                        _field(
                          _vehicleController,
                          lang.isSwahili ? 'Aina ya Gari' : 'Vehicle Type',
                          Icons.local_shipping_outlined,
                          hint: lang.isSwahili
                              ? 'Mfano: Pikipiki, Gari'
                              : 'e.g. Motorcycle, Car',
                        ),
                        _field(
                          _plateController,
                          lang.isSwahili
                              ? 'Nambari ya Usajili'
                              : 'License Plate',
                          Icons.confirmation_number_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Documents
                    _sectionCard(
                      icon: Icons.folder_outlined,
                      title: lang.isSwahili
                          ? 'Nyaraka Muhimu'
                          : 'Required Documents',
                      children: [
                        _docTile(
                          label: lang.isSwahili
                              ? 'Kitambulisho cha Taifa (NIDA)'
                              : 'National ID Card (NIDA)',
                          subtitle: lang.isSwahili
                              ? 'Picha ya mbele na nyuma'
                              : 'Front and back photo',
                          icon: Icons.badge,
                          file: _idCardImage,
                          onTap: () async {
                            final f = await _pickImage();
                            if (f != null) setState(() => _idCardImage = f);
                          },
                        ),
                        const Divider(height: 1),
                        _docTile(
                          label: lang.isSwahili
                              ? 'Leseni ya Udereva'
                              : 'Driver\'s License',
                          subtitle: lang.isSwahili
                              ? 'Leseni halali ya sasa'
                              : 'Valid current license',
                          icon: Icons.drive_eta,
                          file: _licenseImage,
                          onTap: () async {
                            final f = await _pickImage();
                            if (f != null) setState(() => _licenseImage = f);
                          },
                        ),
                        const Divider(height: 1),
                        _docTile(
                          label: lang.isSwahili
                              ? 'Barua ya Mkurugenzi wa Wilaya'
                              : 'District Commissioner Letter',
                          subtitle: lang.isSwahili
                              ? 'Barua ya utambulisho'
                              : 'Official recommendation letter',
                          icon: Icons.description,
                          file: _dcLetterImage,
                          onTap: () async {
                            final f = await _pickImage();
                            if (f != null) setState(() => _dcLetterImage = f);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              lang.isSwahili
                                  ? 'Nyaraka zako zitakaguliwa na msimamizi. Utaarifiwa baada ya kukubaliwa.'
                                  : 'Your documents will be reviewed by admin. You will be notified once approved.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          lang.isSwahili
                              ? 'Wasilisha Maombi'
                              : 'Submit Application',
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF1E1B4B), size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: w,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? hint,
    TextInputType? keyboardType,
    bool isTanzaniaPhone = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: isTanzaniaPhone ? 9 : null,
      buildCounter: isTanzaniaPhone
          ? (_, {required currentLength, required isFocused, maxLength}) => null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: isTanzaniaPhone ? '7XXXXXXXX' : hint,
        prefixIcon: isTanzaniaPhone
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🇹🇿', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 4),
                    Text(
                      '+255',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : Icon(icon, color: Colors.grey, size: 20),
        prefix: null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E1B4B), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      ),
      validator: (v) {
        if (v?.isEmpty ?? true) return 'Required';
        if (isTanzaniaPhone && v!.length != 9)
          return 'Must be 9 digits after +255';
        return null;
      },
    );
  }

  Widget _docTile({
    required String label,
    required String subtitle,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    final uploaded = file != null;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: uploaded
              ? const Color(0xFF1E1B4B).withOpacity(0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: uploaded
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(file, fit: BoxFit.cover),
              )
            : Icon(icon, color: Colors.grey.shade500, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        uploaded ? '✓ Uploaded' : subtitle,
        style: TextStyle(
          fontSize: 12,
          color: uploaded ? Colors.green.shade600 : Colors.grey.shade500,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: uploaded
              ? Colors.green.shade50
              : const Color(0xFF1E1B4B).withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          uploaded ? 'Change' : 'Upload',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: uploaded ? Colors.green.shade700 : const Color(0xFF1E1B4B),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dobController.dispose();
    _nationalIdController.dispose();
    _licenseController.dispose();
    _vehicleController.dispose();
    _plateController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }
}
