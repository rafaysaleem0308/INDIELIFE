import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hello/core/services/api_service.dart';

class AddMealServiceForm extends StatefulWidget {
  final Map<String, dynamic>?
  existingService; // null = add mode, non-null = edit mode
  const AddMealServiceForm({super.key, this.existingService});

  @override
  _AddMealServiceFormState createState() => _AddMealServiceFormState();
}

class _AddMealServiceFormState extends State<AddMealServiceForm> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool get _isEditing => widget.existingService != null;

  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _prepTimeCtrl;
  late final TextEditingController _deliveryTimeCtrl;
  late final TextEditingController _ingredientsCtrl;

  String _mealType = 'Lunch';
  String _cuisineType = 'Pakistani';
  bool _isVegetarian = false;
  bool _isSpicy = false;
  bool _deliveryAvailable = true;
  bool _pickupAvailable = true;
  bool _isLoading = false;

  File? _imageFile;
  String? _existingImageUrl;

  static const _primaryColor = Color(0xFFFF512F);
  static const _accentColor = Color(0xFFFF9D42);

  final _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Dessert'];
  final _cuisines = [
    'Pakistani',
    'Indian',
    'Chinese',
    'Italian',
    'Fast Food',
    'Healthy',
    'Turkish',
    'Arabian',
    'Continental',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.existingService;
    _nameCtrl = TextEditingController(text: s?['serviceName'] ?? '');
    _descCtrl = TextEditingController(text: s?['description'] ?? '');
    _priceCtrl = TextEditingController(text: s?['price']?.toString() ?? '');
    _prepTimeCtrl = TextEditingController(text: s?['preparationTime'] ?? '');
    _deliveryTimeCtrl = TextEditingController(text: s?['deliveryTime'] ?? '');
    final ings = (s?['ingredients'] as List?)?.join(', ') ?? '';
    _ingredientsCtrl = TextEditingController(text: ings);
    if (s != null) {
      _mealType = s['mealType'] ?? 'Lunch';
      _cuisineType = s['cuisineType'] ?? 'Pakistani';
      _isVegetarian = s['isVegetarian'] ?? false;
      _isSpicy = s['isSpicy'] ?? false;
      _deliveryAvailable = s['deliveryAvailable'] ?? true;
      _pickupAvailable = s['pickupAvailable'] ?? true;
      _existingImageUrl = s['imageUrl'];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _prepTimeCtrl.dispose();
    _deliveryTimeCtrl.dispose();
    _ingredientsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final ingredients = _ingredientsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final data = {
        'serviceName': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'unit': 'meal',
        'serviceType': 'Meal Provider',
        'mealType': _mealType,
        'cuisineType': _cuisineType,
        'isVegetarian': _isVegetarian,
        'isSpicy': _isSpicy,
        'preparationTime': _prepTimeCtrl.text,
        'deliveryTime': _deliveryTimeCtrl.text,
        'deliveryAvailable': _deliveryAvailable,
        'pickupAvailable': _pickupAvailable,
        'ingredients': ingredients,
      };

      Map<String, dynamic> result;
      if (_isEditing) {
        result = await ApiService.updateService(
          widget.existingService!['_id'],
          data,
        );
      } else {
        result = await ApiService.addMealService(data);
      }

      if (result['success'] == true && _imageFile != null) {
        final serviceId =
            result['service']?['_id'] ?? widget.existingService?['_id'];
        if (serviceId != null) {
          await ApiService.uploadServiceImage(serviceId, _imageFile!);
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success'] == true) {
          _showSnack(
            _isEditing ? "Dish updated!" : "Dish added successfully!",
            Colors.green,
          );
          Navigator.pop(context, true);
        } else {
          _showSnack(result['message'] ?? "Failed", Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack("Error: $e", Colors.red);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
          _isEditing ? "Edit Dish" : "Add New Dish",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_primaryColor, _accentColor]),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 100),
            _buildStepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _step == 0
                      ? _stepBasicInfo()
                      : (_step == 1 ? _stepDetails() : _stepPreferences()),
                ),
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final labels = ['Basic Info', 'Details', 'Preferences'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(3, (i) {
          final active = i <= _step;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: active ? _primaryColor : Colors.grey[200],
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: active ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    labels[i],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: active ? Colors.black87 : Colors.grey,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (i < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i < _step ? _primaryColor : Colors.grey[200],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _stepBasicInfo() {
    return Column(
      key: const ValueKey('step0'),
      children: [
        _buildImagePicker(),
        const SizedBox(height: 16),
        _section("Dish Information", [
          _field("Dish Name *", _nameCtrl, Icons.restaurant_menu_rounded),
          const SizedBox(height: 14),
          _field(
            "Description *",
            _descCtrl,
            Icons.description_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          _field(
            "Price (PKR) *",
            _priceCtrl,
            Icons.payments_outlined,
            keyboardType: TextInputType.number,
          ),
        ]),
      ],
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _stepDetails() {
    return Column(
      key: const ValueKey('step1'),
      children: [
        _section("Category & Timing", [
          _dropdown(
            "Meal Type",
            _mealType,
            _mealTypes,
            (v) => setState(() => _mealType = v!),
          ),
          const SizedBox(height: 14),
          _dropdown(
            "Cuisine Type",
            _cuisineType,
            _cuisines,
            (v) => setState(() => _cuisineType = v!),
          ),
          const SizedBox(height: 14),
          _field(
            "Prep Time (e.g. 20 min)",
            _prepTimeCtrl,
            Icons.timer_outlined,
            required: false,
          ),
          const SizedBox(height: 14),
          _field(
            "Delivery Time (e.g. 30 min)",
            _deliveryTimeCtrl,
            Icons.delivery_dining,
            required: false,
          ),
        ]),
      ],
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _stepPreferences() {
    return Column(
      key: const ValueKey('step2'),
      children: [
        _section("Ingredients & Preferences", [
          _field(
            "Ingredients (comma separated)",
            _ingredientsCtrl,
            Icons.kitchen_outlined,
            required: false,
            maxLines: 2,
            hint: "Rice, Chicken, Spices, Yogurt",
          ),
          const SizedBox(height: 14),
          _switchTile(
            "Vegetarian",
            _isVegetarian,
            Icons.eco_outlined,
            (v) => setState(() => _isVegetarian = v),
          ),
          _switchTile(
            "Spicy",
            _isSpicy,
            Icons.local_fire_department_outlined,
            (v) => setState(() => _isSpicy = v),
          ),
          _switchTile(
            "Delivery Available",
            _deliveryAvailable,
            Icons.delivery_dining,
            (v) => setState(() => _deliveryAvailable = v),
          ),
          _switchTile(
            "Pickup Available",
            _pickupAvailable,
            Icons.storefront_outlined,
            (v) => setState(() => _pickupAvailable = v),
          ),
        ]),
      ],
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _buildImagePicker() {
    ImageProvider? preview;
    if (_imageFile != null) {
      preview = FileImage(_imageFile!);
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      preview = NetworkImage(ApiService.resolveImageUrl(_existingImageUrl));
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 6),
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
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      color: _accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Tap to add dish photo",
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    "(Optional)",
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "Change",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ).animate().fadeIn().scale(duration: 400.ms);
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: _primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  "Back",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_step < 2) {
                        if (_step == 0 && !_formKey.currentState!.validate())
                          return;
                        setState(() => _step++);
                      } else {
                        _submit();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _step == 2 ? Colors.green : _primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _step == 2
                          ? (_isEditing ? "Save Changes" : "Publish Dish")
                          : "Next »",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── REUSABLE WIDGETS ───

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
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
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = true,
    String? hint,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? "Required" : null
          : null,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _accentColor, size: 20),
        hintText: hint ?? label,
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
          borderSide: const BorderSide(color: _accentColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: options.contains(value) ? value : options.first,
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.category_outlined,
          color: _accentColor,
          size: 20,
        ),
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
      ),
      items: options
          .map(
            (o) => DropdownMenuItem(
              value: o,
              child: Text(o, style: GoogleFonts.inter()),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _switchTile(
    String label,
    bool value,
    IconData icon,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(icon, color: _accentColor, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        value: value,
        activeColor: _primaryColor,
        onChanged: onChanged,
      ),
    );
  }
}
