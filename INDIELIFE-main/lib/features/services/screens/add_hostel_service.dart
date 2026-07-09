import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hello/core/services/api_service.dart';

class AddHostelServiceForm extends StatefulWidget {
  final Map<String, dynamic>? existingService;
  const AddHostelServiceForm({super.key, this.existingService});
  @override
  State<AddHostelServiceForm> createState() => _AddHostelServiceFormState();
}

class _AddHostelServiceFormState extends State<AddHostelServiceForm> {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.existingService != null;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _contactCtrl;

  String _accommodationType = 'Hostel';
  int _availableRooms = 1;
  int _maxOccupants = 1;
  int _currentOccupants = 0;
  bool _isShared = false;
  bool _isLoading = false;
  File? _imageFile;
  String? _existingImageUrl;
  Position? _currentPosition;

  static const _color = Color(0xFF2193b0);
  static const _accent = Color(0xFF6dd5ed);
  final _types = ['Hostel', 'Flat', 'Room', 'Guest House', 'Studio Apartment'];

  final _features = [
    'WiFi',
    'Geyser',
    'AC',
    'Generator',
    'Security Guard',
    'CCTV',
    'Parking',
    'Laundry',
  ];
  List<String> _selectedFeatures = [];

  @override
  void initState() {
    super.initState();
    final s = widget.existingService;
    _nameCtrl = TextEditingController(text: s?['serviceName'] ?? '');
    _addressCtrl = TextEditingController(text: s?['address'] ?? '');
    _priceCtrl = TextEditingController(text: s?['price']?.toString() ?? '');
    _descCtrl = TextEditingController(text: s?['description'] ?? '');
    _contactCtrl = TextEditingController(text: s?['contactNumber'] ?? '');
    if (s != null) {
      _accommodationType = s['accommodationType'] ?? 'Hostel';
      _availableRooms = s['availableRooms'] ?? 1;
      _maxOccupants = s['maxOccupants'] ?? 1;
      _currentOccupants = s['currentOccupants'] ?? 0;
      _isShared = s['isShared'] ?? false;
      _existingImageUrl = s['imageUrl'];
      _selectedFeatures = List<String>.from(s['roomFeatures'] ?? []);
    }
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      if (mounted) setState(() {});
    } catch (e) {
      // location optional
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null && mounted)
      setState(() => _imageFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = {
        'serviceName': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'unit': 'month',
        'serviceType': 'Hostel/Flat Accommodation',
        'accommodationType': _accommodationType,
        'address': _addressCtrl.text.trim(),
        'contactNumber': _contactCtrl.text.trim(),
        'availableRooms': _availableRooms,
        'isShared': _isShared,
        'maxOccupants': _maxOccupants,
        'currentOccupants': _currentOccupants,
        'roomFeatures': _selectedFeatures,
        if (_currentPosition != null) 'lat': _currentPosition!.latitude,
        if (_currentPosition != null) 'lng': _currentPosition!.longitude,
      };

      Map<String, dynamic> result;
      if (_isEditing) {
        result = await ApiService.updateService(
          widget.existingService!['_id'],
          data,
        );
      } else {
        result = await ApiService.addHousingService(data);
      }

      if (result['success'] == true && _imageFile != null) {
        final id = result['service']?['_id'] ?? widget.existingService?['_id'];
        if (id != null) await ApiService.uploadServiceImage(id, _imageFile!);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditing ? "Listing updated!" : "Listing published!",
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Failed"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEditing ? "Edit Accommodation" : "List Accommodation",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_color, _accent]),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImagePicker(),
              const SizedBox(height: 20),

              _section("Property Details", [
                _field("Property Name *", _nameCtrl, Icons.apartment_rounded),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _types.contains(_accommodationType)
                      ? _accommodationType
                      : _types.first,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.category_outlined,
                      color: _color,
                      size: 20,
                    ),
                    labelText: "Accommodation Type",
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  items: _types
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, style: GoogleFonts.inter()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _accommodationType = v!),
                ),
                const SizedBox(height: 14),
                _field(
                  "Monthly Rent (PKR) *",
                  _priceCtrl,
                  Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                ),
              ]),
              const SizedBox(height: 20),

              _section("Location & Contact", [
                _field(
                  "Full Address *",
                  _addressCtrl,
                  Icons.location_on_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                _field(
                  "Contact Number *",
                  _contactCtrl,
                  Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                if (_currentPosition != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "GPS location captured ✓",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
              const SizedBox(height: 20),

              _section("Capacity", [
                _counterRow(
                  "Available Rooms",
                  _availableRooms,
                  (v) => setState(() => _availableRooms = v),
                ),
                const Divider(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      "Shared Property",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "Multiple tenants in one unit",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    value: _isShared,
                    activeColor: _color,
                    onChanged: (v) => setState(() => _isShared = v),
                  ),
                ),
                if (_isShared) ...[
                  const SizedBox(height: 12),
                  _counterRow(
                    "Max Occupants",
                    _maxOccupants,
                    (v) => setState(() => _maxOccupants = v),
                  ),
                  const SizedBox(height: 8),
                  _counterRow(
                    "Current Occupants",
                    _currentOccupants,
                    (v) => setState(() => _currentOccupants = v),
                  ),
                ],
              ]),
              const SizedBox(height: 20),

              _section("Amenities & Features", [
                Text(
                  "Select all available:",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _features.map((f) {
                    final sel = _selectedFeatures.contains(f);
                    return FilterChip(
                      label: Text(
                        f,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: sel,
                      selectedColor: _color,
                      backgroundColor: const Color(0xFFE8F4FD),
                      checkmarkColor: Colors.white,
                      side: BorderSide(color: sel ? _color : Colors.grey[300]!),
                      onSelected: (v) => setState(
                        () => v
                            ? _selectedFeatures.add(f)
                            : _selectedFeatures.remove(f),
                      ),
                    );
                  }).toList(),
                ),
              ]),
              const SizedBox(height: 20),

              _section("Description", [
                _field(
                  "Facilities, Rules & Notes *",
                  _descCtrl,
                  Icons.description_outlined,
                  maxLines: 4,
                ),
              ]),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditing ? Colors.green : _color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : Text(
                          _isEditing ? "Save Changes" : "Publish Listing",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

  Widget _buildImagePicker() {
    ImageProvider? preview;
    if (_imageFile != null)
      preview = FileImage(_imageFile!);
    else if (_existingImageUrl != null)
      preview = NetworkImage(ApiService.resolveImageUrl(_existingImageUrl));

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 15,
            ),
          ],
          image: preview != null
              ? DecorationImage(image: preview, fit: BoxFit.cover)
              : null,
        ),
        child: preview == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    color: _color,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Add Property Photo (Optional)",
                    style: GoogleFonts.inter(color: Colors.grey[600]),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Change Photo",
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
      ),
    ).animate().fadeIn();
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    // Determine if this is a phone field
    final isPhone = keyboardType == TextInputType.phone;

    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: isPhone ? [FilteringTextInputFormatter.digitsOnly] : [],
      style: GoogleFonts.inter(fontSize: 14),
      validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _color, size: 20),
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _color, width: 1.5),
        ),
      ),
    );
  }

  Widget _counterRow(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.remove, color: _color, size: 18),
                onPressed: () {
                  if (value > 0) onChanged(value - 1);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$value',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: _color, size: 18),
                onPressed: () => onChanged(value + 1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
