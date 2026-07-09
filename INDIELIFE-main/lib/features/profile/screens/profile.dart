import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:hello/core/services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  File? _imageFile;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _familyContractController;
  late TextEditingController _familyPhoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _familyContractController = TextEditingController();
    _familyPhoneController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _familyContractController.dispose();
    _familyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getUserData();
      if (mounted) {
        setState(() {
          userData = data;
          _isLoading = false;
          _populateControllers();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateControllers() {
    if (userData != null) {
      _nameController.text = userData?['username'] ?? '';
      _phoneController.text = userData?['phone'] ?? '';
      _addressController.text = userData?['address'] ?? '';
      _familyContractController.text = userData?['familyName'] ?? '';
      _familyPhoneController.text = userData?['familyPhone'] ?? '';
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> updateData = {
        'username': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        if (userData?['role']?.toString().toLowerCase() == 'user') ...{
          'familyName': _familyContractController.text,
          'familyPhone': _familyPhoneController.text,
        },
      };

      final userId =
          userData?['id'] ?? userData?['userId'] ?? userData?['_id'] ?? '';
      if (userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: User ID not found"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      final role = userData?['role']?.toString().toLowerCase() ?? 'user';

      if (_imageFile != null) {
        final imageResult = await ApiService.uploadProfileImage(
          userId,
          _imageFile!,
          role,
        );
        if (imageResult['success'] == true) {
          userData = imageResult['user'];
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  imageResult['message'] ?? "Failed to upload image",
                ),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      final result = await ApiService.updateProfile(userId, updateData, role);

      if (mounted) {
        setState(() => _isSaving = false);
        if (result['success'] == true) {
          setState(() {
            userData = result['user'];
            _isEditing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Profile updated successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Failed to update profile"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEditing ? "Edit Profile" : "My Profile",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1E293B), Colors.black]),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            if (_isEditing) {
              setState(() {
                _isEditing = false;
                _imageFile = null;
              });
              _populateControllers(); // Reset changes
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(
                _isEditing ? Icons.check : Icons.edit,
                color: Colors.white,
              ),
              onPressed: () {
                if (_isEditing) {
                  _saveProfile();
                } else {
                  setState(() => _isEditing = true);
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 120, 24, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    SizedBox(height: 32),
                    _buildInfoSection("Account Details", [
                      _infoTile(
                        Icons.person_outline,
                        "Username",
                        _nameController,
                        enabled: _isEditing,
                      ),
                      _infoTile(
                        Icons.phone_outlined,
                        "Phone",
                        _phoneController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                      ),
                      _infoTile(
                        Icons.location_on_outlined,
                        "Address",
                        _addressController,
                        enabled: _isEditing,
                        maxLines: 2,
                      ),
                      if (!_isEditing)
                        ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ),
                          title: Text(
                            "Messages",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          subtitle: Text(
                            "View your conversations",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () =>
                              Navigator.pushNamed(context, '/my-chats'),
                        ),
                    ]),
                    SizedBox(height: 24),
                    if (userData?['role'] == 'user')
                      _buildInfoSection("Family Contact", [
                        _infoTile(
                          Icons.people_outline,
                          "Contact Name",
                          _familyContractController,
                          enabled: _isEditing,
                        ),
                        _infoTile(
                          Icons.call_outlined,
                          "Contact Phone",
                          _familyPhoneController,
                          enabled: _isEditing,
                          keyboardType: TextInputType.phone,
                        ),
                      ]),
                    SizedBox(height: 40),
                    if (_isEditing)
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isSaving
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  "Save Changes",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      )
                    else
                      _buildLogoutButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (mounted) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    }
  }

  Widget _buildProfileHeader() {
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      imageProvider = FileImage(_imageFile!);
    } else if (userData?['profileImage'] != null &&
        userData!['profileImage'].toString().isNotEmpty) {
      imageProvider = NetworkImage(
        ApiService.resolveImageUrl(userData!['profileImage']),
      );
    }

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isEditing ? _pickImage : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF1E293B).withOpacity(0.1),
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? Icon(Icons.person, size: 50, color: Color(0xFF1E293B))
                      : null,
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            userData?['username'] ?? "User",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            userData?['role']?.toString().toUpperCase() ?? "MEMBER",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              letterSpacing: 1,
            ),
          ),
          if (!_isEditing) ...[
            SizedBox(height: 8),
            Text(
              userData?['email'] ?? "",
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().scale(duration: 400.ms);
  }

  Widget _buildInfoSection(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _infoTile(
    IconData icon,
    String label,
    TextEditingController controller, {
    bool enabled = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    if (!enabled) {
      return ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.grey[600], size: 20),
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
        subtitle: Text(
          controller.text.isNotEmpty ? controller.text : "Not set",
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      );
    }

    // Determine if this is a phone field
    final isPhone = keyboardType == TextInputType.phone;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: isPhone
            ? [FilteringTextInputFormatter.digitsOnly]
            : [],
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Color(0xFF1E293B), size: 20),
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          filled: true,
          fillColor: Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: (value) =>
            (value == null || value.isEmpty) ? '$label is required' : null,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () async {
          await ApiService.logout();
          if (mounted)
            Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.red.withOpacity(0.3)),
          ),
        ),
        child: Text(
          "Logout",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ),
    );
  }
}
