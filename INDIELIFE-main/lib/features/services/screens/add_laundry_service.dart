import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hello/core/services/api_service.dart';

class AddLaundryServiceForm extends StatefulWidget {
  final Map<String, dynamic>? existingService;
  const AddLaundryServiceForm({super.key, this.existingService});
  @override
  _AddLaundryServiceFormState createState() => _AddLaundryServiceFormState();
}

class _AddLaundryServiceFormState extends State<AddLaundryServiceForm> {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.existingService != null;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descCtrl;

  String _laundryType = 'Wash & Fold';
  bool _pickupAvailable = true;
  bool _deliveryAvailable = true;
  bool _isLoading = false;
  File? _imageFile;
  String? _existingImageUrl;

  static const _color = Color(0xFF2196F3);
  static const _accent = Color(0xFF00BCD4);
  final _types = ['Wash & Fold', 'Dry Clean', 'Steam Press', 'Wash & Iron', 'Delicate Care'];

  @override
  void initState() {
    super.initState();
    final s = widget.existingService;
    _nameCtrl  = TextEditingController(text: s?['serviceName'] ?? '');
    _priceCtrl = TextEditingController(text: s?['price']?.toString() ?? '');
    _descCtrl  = TextEditingController(text: s?['description'] ?? '');
    if (s != null) {
      _laundryType       = s['laundryType'] ?? 'Wash & Fold';
      _pickupAvailable   = s['pickupAvailable'] ?? true;
      _deliveryAvailable = s['deliveryAvailable'] ?? true;
      _existingImageUrl  = s['imageUrl'];
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _priceCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = {
        'serviceName': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'unit': 'kg',
        'serviceType': 'Laundry',
        'laundryType': _laundryType,
        'pickupAvailable': _pickupAvailable,
        'deliveryAvailable': _deliveryAvailable,
      };

      Map<String, dynamic> result;
      if (_isEditing) {
        result = await ApiService.updateService(widget.existingService!['_id'], data);
      } else {
        result = await ApiService.addLaundryService(data);
      }

      if (result['success'] == true && _imageFile != null) {
        final id = result['service']?['_id'] ?? widget.existingService?['_id'];
        if (id != null) await ApiService.uploadServiceImage(id, _imageFile!);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditing ? "Service updated!" : "Service added!"),
            backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
          ));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['message'] ?? "Failed"), backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Text(_isEditing ? "Edit Laundry Service" : "Add Laundry Service",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        flexibleSpace: Container(decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_color, _accent]))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(children: [
            // Image Picker
            _buildImagePicker(),
            const SizedBox(height: 20),

            // Details section
            _section("Service Details", const Color(0xFF2196F3), [
              _field("Service Name *", _nameCtrl, Icons.local_laundry_service_outlined),
              const SizedBox(height: 14),
              _dropdown(),
              const SizedBox(height: 14),
              _field("Price per Kg (PKR) *", _priceCtrl, Icons.payments_outlined, keyboardType: TextInputType.number),
              const SizedBox(height: 14),
              _field("Description (what's included?)", _descCtrl, Icons.description_outlined, maxLines: 3),
            ]),
            const SizedBox(height: 20),

            _section("Options", const Color(0xFF2196F3), [
              _switchTile("Pickup Available", _pickupAvailable, Icons.directions_car_outlined, (v) => setState(() => _pickupAvailable = v)),
              _switchTile("Delivery Available", _deliveryAvailable, Icons.delivery_dining, (v) => setState(() => _deliveryAvailable = v)),
            ]),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 58,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditing ? Colors.green : _color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text(_isEditing ? "Save Changes" : "Launch Service",
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    ImageProvider? preview;
    if (_imageFile != null) preview = FileImage(_imageFile!);
    else if (_existingImageUrl != null) preview = NetworkImage(ApiService.resolveImageUrl(_existingImageUrl));

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15)],
          image: preview != null ? DecorationImage(image: preview, fit: BoxFit.cover) : null,
        ),
        child: preview == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo_outlined, color: _color, size: 32),
                const SizedBox(height: 8),
                Text("Add Service Photo (Optional)", style: GoogleFonts.inter(color: Colors.grey[600])),
              ])
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text("Change Photo", style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                ),
              ),
      ),
    ).animate().fadeIn();
  }

  Widget _section(String title, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        ...children,
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl, maxLines: maxLines, keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14),
      validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _color, size: 20),
        labelText: label, labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        filled: true, fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _accent, width: 1.5)),
      ),
    );
  }

  Widget _dropdown() {
    return DropdownButtonFormField<String>(
      value: _types.contains(_laundryType) ? _laundryType : _types.first,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.local_laundry_service, color: _color, size: 20),
        labelText: "Service Type", labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        filled: true, fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
      ),
      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter()))).toList(),
      onChanged: (v) => setState(() => _laundryType = v!),
    );
  }

  Widget _switchTile(String label, bool value, IconData icon, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
      child: SwitchListTile(
        title: Row(children: [
          Icon(icon, color: _color, size: 20),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
        ]),
        value: value, activeColor: _color, onChanged: onChanged,
      ),
    );
  }
}
