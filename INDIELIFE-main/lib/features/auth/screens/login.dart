import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hello/features/auth/screens/signup.dart';
import 'package:hello/core/services/api_service.dart';
import 'package:hello/core/services/session_manager.dart';
import 'package:hello/features/home/screens/user_home.dart';
import 'package:hello/features/home/screens/service_provider_home.dart';
import 'package:hello/features/auth/screens/forgot_password.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool passwordVisible = false;
  bool _isLoading = false;
  bool _isAutoLogging = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  // Saved account for "Continue as" feature
  Map<String, dynamic>? _savedAccount;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutQuart,
          ),
        );

    _animationController.forward();
    _loadSavedAccount();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Load saved account to show "Continue as" option
  Future<void> _loadSavedAccount() async {
    final saved = await SessionManager.getSavedAccount();
    if (saved != null &&
        saved['email'] != null &&
        saved['email'].toString().isNotEmpty) {
      if (mounted) {
        setState(() {
          _savedAccount = saved;
          emailController.text = saved['email'] ?? '';
        });
      }
    }
  }

  /// Handle "Continue as" — try to refresh the session
  Future<void> _handleContinueAs() async {
    setState(() => _isAutoLogging = true);

    final refreshed = await SessionManager.refreshSession();

    if (!mounted) return;

    if (refreshed) {
      final userData = await SessionManager.getUserData();
      final role = userData?['role']?.toString().toLowerCase() ?? 'user';

      if (!mounted) return;

      if (role == 'service_provider' || role == 'serviceprovider') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => ServiceProviderHome()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => UserHome()),
          (route) => false,
        );
      }
    } else {
      setState(() => _isAutoLogging = false);
      // Clear saved account since session refresh failed (account may be deleted)
      await SessionManager.clearSavedAccount();
      setState(() => _savedAccount = null);
      _showSnackBar(
        'Session expired. Please enter your password.',
        Colors.orange,
      );
    }
  }

  /// Handle "Use another account"
  void _handleUseAnotherAccount() {
    setState(() {
      _savedAccount = null;
      emailController.clear();
      passwordController.clear();
    });
    SessionManager.clearSavedAccount();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final response = await ApiService.login(
        emailController.text.trim(),
        passwordController.text,
      );

      if (mounted) setState(() => _isLoading = false);

      if (response['success']) {
        await ApiService.saveUserSession(response['user']);

        final role = response['role']?.toString().toLowerCase();

        if (!mounted) return;

        if (role == 'user') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => UserHome()),
            (route) => false,
          );
        } else if (role == 'service_provider' || role == 'serviceprovider') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => ServiceProviderHome()),
            (route) => false,
          );
        } else {
          _showSnackBar('Unknown role: $role', Colors.red);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => UserHome()),
            (route) => false,
          );
        }
      } else {
        final errorMsg = response['message'] ?? 'Login failed';
        _showSnackBar(errorMsg, Colors.red);

        // Clear saved account if account not found in database (deleted or doesn't exist)
        if (errorMsg.toLowerCase().contains('not found') ||
            errorMsg.toLowerCase().contains('invalid email') ||
            errorMsg.toLowerCase().contains('does not exist')) {
          await SessionManager.clearSavedAccount();
          if (mounted) {
            setState(() => _savedAccount = null);
          }
        }
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 14)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  /// Build the "Continue as" card
  Widget _buildSavedAccountCard() {
    if (_savedAccount == null) return const SizedBox.shrink();

    final firstName = _savedAccount!['firstName'] ?? '';
    final lastName = _savedAccount!['lastName'] ?? '';
    final email = _savedAccount!['email'] ?? '';
    final name = '$firstName $lastName'.trim();
    final initials =
        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
            .toUpperCase();
    final profileImage = _savedAccount!['profileImage']?.toString() ?? '';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF9D42).withValues(alpha: 0.1),
                const Color(0xFFFF512F).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF9D42).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFFF9D42),
                    backgroundImage: profileImage.isNotEmpty
                        ? NetworkImage(ApiService.resolveImageUrl(profileImage))
                        : null,
                    child: profileImage.isEmpty
                        ? Text(
                            initials.isNotEmpty ? initials : '?',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : email,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (name.isNotEmpty)
                          Text(
                            email,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Continue as button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAutoLogging ? null : _handleContinueAs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9D42),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isAutoLogging
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Continue as ${firstName.isNotEmpty ? firstName : 'User'}",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _handleUseAnotherAccount,
          child: Text(
            "Use another account",
            style: GoogleFonts.inter(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "or login with password",
                style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF9D42), Color(0xFFFF512F)],
              ),
            ),
          ),

          // 2. Abstract Shapes
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),

          // 3. Glassmorphic Login Form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Logo
                              Hero(
                                tag: 'app_logo',
                                child: Container(
                                  height: 80,
                                  width: 80,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Image.asset(
                                    "assets/images/Logo1.png",
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              Text(
                                "Welcome Back!",
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Login to continue managing your services",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ─── Saved Account Card ──────────────────────
                              _buildSavedAccountCard(),

                              // Email Input
                              TextFormField(
                                controller: emailController,
                                style: GoogleFonts.inter(color: Colors.black87),
                                decoration: InputDecoration(
                                  labelText: "Email",
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: const Color(0xFFFF9D42),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) {
                                  if (value!.isEmpty)
                                    return "Email is required";
                                  if (!RegExp(
                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  ).hasMatch(value)) {
                                    return "Enter valid email";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Password Input
                              TextFormField(
                                controller: passwordController,
                                obscureText: !passwordVisible,
                                style: GoogleFonts.inter(color: Colors.black87),
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: const Color(0xFFFF9D42),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      passwordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => setState(
                                      () => passwordVisible = !passwordVisible,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (val) => val!.isEmpty
                                    ? "Password is required"
                                    : null,
                              ),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Forgot Password?",
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFFF9D42),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF9D42),
                                    foregroundColor: Colors.white,
                                    elevation: 5,
                                    shadowColor: const Color(
                                      0xFFFF9D42,
                                    ).withValues(alpha: 0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          "LOGIN",
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Signup Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "New user? ",
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SignupScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Sign Up",
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFFF9D42),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
