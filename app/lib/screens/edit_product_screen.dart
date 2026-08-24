import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

const _cloudName = 'dx7jrfytj';
const _uploadPreset = 'seafoods';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product; // full product map including 'id'
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _addStockController; // extra stock to add
  late final TextEditingController _locationController;

  File? _newImageFile; // if seller picks a new photo
  bool _isLoading = false;
  late String _selectedCategory;
  late String _selectedUnit;

  final List<String> _categoryKeys = [
    'cat_fish',
    'cat_shrimp',
    'cat_crab',
    'cat_lobster',
    'cat_squid',
    'cat_octopus',
    'cat_other',
  ];
  final List<String> _unitKeys = [
    'unit_kg',
    'unit_g',
    'unit_piece',
    'unit_dozen'
  ];
  final List<String> _unitValues = ['kg', 'g', 'piece', 'dozen'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p['name'] ?? '');
    _descController = TextEditingController(text: p['description'] ?? '');
    _priceController =
        TextEditingController(text: (p['price'] ?? '').toString());
    _stockController =
        TextEditingController(text: (p['stock'] ?? '').toString());
    _addStockController = TextEditingController(text: '0');
    _locationController = TextEditingController(text: p['location'] ?? '');
    _selectedCategory = _categoryKeys.contains(p['category'])
        ? p['category'] as String
        : 'cat_fish';
    _selectedUnit =
        _unitValues.contains(p['unit']) ? p['unit'] as String : 'kg';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _addStockController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ── Image picker ────────────────────────────────────────────────────────────
  Future<void> _pickImage(LanguageProvider lang) async {
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
                title: Text(lang.t('camera')),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(lang.t('gallery')),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (picked != null) setState(() => _newImageFile = File(picked.path));
  }

  Future<String?> _uploadImage(File file) async {
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

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save(LanguageProvider lang) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final currentStock = double.tryParse(_stockController.text) ?? 0;
      final addStock = double.tryParse(_addStockController.text) ?? 0;
      final newStock = currentStock + addStock;

      // Upload new image if seller changed it
      String? imageUrl = widget.product['imageUrl'] as String?;
      if (_newImageFile != null) {
        imageUrl = await _uploadImage(_newImageFile!);
      }

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product['id'] as String)
          .update({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': double.parse(_priceController.text),
        'unit': _selectedUnit,
        'stock': newStock,
        'category': _selectedCategory,
        'location': _locationController.text.trim(),
        'imageUrl': imageUrl,
        // Re-activate if stock was zero and seller added more
        if (newStock > 0) 'isAvailable': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.isSwahili
                  ? 'Bidhaa imesasishwa!'
                  : 'Product updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // true = reload product list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final existingImageUrl = widget.product['imageUrl'] as String?;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(lang.isSwahili ? 'Hariri Bidhaa' : 'Edit Product'),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Product image ─────────────────────────────────────────
              GestureDetector(
                onTap: () => _pickImage(lang),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xFFB8B7D8), width: 2),
                    image: _newImageFile != null
                        ? DecorationImage(
                            image: FileImage(_newImageFile!),
                            fit: BoxFit.cover,
                          )
                        : (existingImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(existingImageUrl),
                                fit: BoxFit.cover,
                              )
                            : null),
                  ),
                  child: (_newImageFile == null && existingImageUrl == null)
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo,
                                size: 50, color: Color(0xFF6B68A8)),
                            const SizedBox(height: 8),
                            Text(lang.t('select_image'),
                                style:
                                    const TextStyle(color: Color(0xFF1E1B4B))),
                          ],
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  lang.isSwahili ? 'Badilisha' : 'Change photo',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Product details ───────────────────────────────────────
              _sectionTitle(lang.t('product_details')),
              _field(_nameController, lang.t('product_name'), Icons.set_meal,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 14),
              _field(_descController, lang.t('description'), Icons.description,
                  maxLines: 3,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _deco(lang.t('category'), Icons.category),
                items: _categoryKeys
                    .map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(lang.t(k)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 20),

              // ── Pricing ───────────────────────────────────────────────
              _sectionTitle(lang.t('pricing_stock')),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _field(
                      _priceController,
                      lang.t('price_tzs'),
                      Icons.money,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: _deco(lang.t('unit'), Icons.scale),
                      items: List.generate(
                          _unitKeys.length,
                          (i) => DropdownMenuItem(
                                value: _unitValues[i],
                                child: Text(lang.t(_unitKeys[i])),
                              )),
                      onChanged: (v) => setState(() => _selectedUnit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Stock management ──────────────────────────────────────
              _sectionTitle(
                lang.isSwahili ? 'Usimamizi wa Hisa' : 'Stock Management',
              ),
              // Current stock (read-only display)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        color: Colors.grey.shade500, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.isSwahili ? 'Hisa ya Sasa' : 'Current Stock',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                          Text(
                            '${_stockController.text} ${_selectedUnit}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1B4B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Add extra stock field — the main feature for restocking
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_box_outlined,
                            color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          lang.isSwahili
                              ? 'Ongeza Hisa Zaidi'
                              : 'Add More Stock',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang.isSwahili
                          ? 'Ingiza kiasi cha ziada — kitaongezwa kwa hisa ya sasa'
                          : 'Enter additional quantity — it will be added to current stock',
                      style:
                          TextStyle(fontSize: 12, color: Colors.green.shade700),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addStockController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        prefixIcon:
                            Icon(Icons.add, color: Colors.green.shade700),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.green.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.green.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: Colors.green.shade600, width: 1.5),
                        ),
                        suffixText: _selectedUnit,
                      ),
                      validator: (v) {
                        if (v != null &&
                            v.isNotEmpty &&
                            double.tryParse(v) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                      // Show live total
                      onChanged: (v) => setState(() {}),
                    ),
                    if (_addStockController.text.isNotEmpty &&
                        double.tryParse(_addStockController.text) != null &&
                        double.parse(_addStockController.text) > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 16, color: Colors.green.shade700),
                            const SizedBox(width: 6),
                            Text(
                              '${lang.isSwahili ? 'Hisa mpya' : 'New total'}: '
                              '${(double.tryParse(_stockController.text) ?? 0) + (double.tryParse(_addStockController.text) ?? 0)} $_selectedUnit',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Location ──────────────────────────────────────────────
              _sectionTitle(lang.t('location')),
              _field(_locationController, lang.t('pickup_location'),
                  Icons.location_on,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 32),

              // ── Save button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _save(lang),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    lang.isSwahili ? 'Hifadhi Mabadiliko' : 'Save Changes',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1B4B),
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
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700)),
      );

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E1B4B), width: 1.5)),
      );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: _deco(label, icon),
        validator: validator,
      );
}
