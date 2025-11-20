import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:finzobilling/services/analytics_service.dart';

class ModernSignUpScreen extends StatefulWidget {
  final VoidCallback onLoginTapped;
  const ModernSignUpScreen({super.key, required this.onLoginTapped});

  @override
  State<ModernSignUpScreen> createState() => _ModernSignUpScreenState();
}

class _ModernSignUpScreenState extends State<ModernSignUpScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  
  // Premium animations (same as splash!)
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _shakeController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseScale;
  late Animation<double> _shimmerPosition;
  late Animation<double> _shakeAnimation;

  // Password strength
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _pulseScale = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    
    _shimmerPosition = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });

    _passwordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _shakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    _shakeController.forward(from: 0);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  void _checkPasswordStrength() {
    final password = _passwordController.text;
    double strength = 0.0;
    String strengthText = '';

    if (password.isEmpty) {
      strength = 0.0;
      strengthText = '';
    } else if (password.length < 6) {
      strength = 0.25;
      strengthText = 'Weak';
    } else if (password.length < 8) {
      strength = 0.5;
      strengthText = 'Fair';
    } else if (password.length < 10 && 
               RegExp(r'[A-Z]').hasMatch(password) && 
               RegExp(r'[0-9]').hasMatch(password)) {
      strength = 0.75;
      strengthText = 'Good';
    } else if (password.length >= 10 && 
               RegExp(r'[A-Z]').hasMatch(password) && 
               RegExp(r'[0-9]').hasMatch(password) && 
               RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      strength = 1.0;
      strengthText = 'Strong';
    } else {
      strength = 0.5;
      strengthText = 'Fair';
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthText = strengthText;
    });
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));

      final user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'onboardingComplete': false,
        });
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'An error occurred. Please try again.';
      switch (e.code) {
        case 'weak-password':
          msg = 'The password provided is too weak';
          break;
        case 'email-already-in-use':
          msg = 'An account already exists for that email';
          break;
        case 'invalid-email':
          msg = 'The email address is invalid';
          break;
        case 'operation-not-allowed':
          msg = 'Email/password accounts are not enabled';
          break;
        case 'network-request-failed':
          msg = 'Network error. Check your connection';
          break;
      }
      _showError(msg);
    } on TimeoutException {
      _showError('Sign-up timed out. Check your connection');
    } catch (e) {
      _showError('Unexpected error occurred. Try again');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'email': user.email,
            'displayName': user.displayName ?? 'User',
            'photoUrl': user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'loginMethod': 'google',
            'onboardingComplete': false,
          });
          await AnalyticsService().logSignUp('google');
        } else {
          await AnalyticsService().logLogin('google');
        }
        await AnalyticsService().setUserId(user.uid);
      }
    } catch (e) {
      _showError('Google Sign-In failed');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              Colors.white,
              const Color(0xFFFAFAFA),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              physics: const BouncingScrollPhysics(),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // PREMIUM METALLIC LOGO (Same as splash!)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseScale.value,
                            child: _buildMetallicLogo(),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Shimmering title
                      _buildShimmeringTitle(),

                      const SizedBox(height: 10),
                      
                      Text(
                        'GST Billing Made Simple',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // India Badge (same as splash!)
                      _buildIndiaBadge(),

                      const SizedBox(height: 32),

                      // Premium Form Card
                      Container(
                        constraints: const BoxConstraints(maxWidth: 440),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.08),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                              spreadRadius: -8,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.04),
                              blurRadius: 48,
                              offset: const Offset(0, 24),
                              spreadRadius: -12,
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section title
                              const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Join us and start managing your business',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),

                              const SizedBox(height: 28),

                              // Error message with shake
                              if (_errorMessage != null)
                                AnimatedBuilder(
                                  animation: _shakeAnimation,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(
                                        _shakeAnimation.value *
                                            (_shakeController.status == AnimationStatus.reverse ? -1 : 1),
                                        0,
                                      ),
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Email field
                              _buildPremiumTextField(
                                controller: _emailController,
                                label: 'Email',
                                hint: 'your.email@example.com',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isEmpty) return 'Email is required';
                                  final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                                  if (!regex.hasMatch(v)) return 'Enter a valid email';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Password field
                              _buildPremiumTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: 'Create a strong password',
                                icon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (value.length < 6) {
                                    return 'At least 6 characters required';
                                  }
                                  return null;
                                },
                              ),

                              // Password strength indicator
                              if (_passwordController.text.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: _passwordStrength,
                                          minHeight: 4,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            _passwordStrength < 0.5
                                                ? Colors.red
                                                : _passwordStrength < 0.75
                                                    ? Colors.orange
                                                    : Colors.green,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _passwordStrengthText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _passwordStrength < 0.5
                                            ? Colors.red
                                            : _passwordStrength < 0.75
                                                ? Colors.orange
                                                : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 24),

                              // Premium Create Account Button
                              _buildPremiumButton(
                                onPressed: _isLoading ? null : _signUp,
                                isLoading: _isLoading,
                                label: 'Create Account',
                                isPrimary: true,
                              ),

                              // Divider
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.grey[300])),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'OR',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.grey[300])),
                                  ],
                                ),
                              ),

                              // Google Button
                              _buildPremiumButton(
                                onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                                isLoading: _isGoogleLoading,
                                label: 'Sign up with Google',
                                icon: 'https://www.google.com/favicon.ico',
                                isPrimary: false,
                              ),

                              const SizedBox(height: 24),

                              // Login link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Already have an account? ",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _isLoading ? null : widget.onLoginTapped,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Terms
                      Text(
                        'By signing up, you agree to our Terms & Privacy Policy',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // METALLIC LOGO (Exact same as splash!)
  Widget _buildMetallicLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFE0E0E0),
            Color(0xFFA0A0A0),
            Color(0xFF707070),
          ],
          stops: [0.0, 0.3, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(-8, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Image.asset(
              'assets/images/app_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    size: 55,
                    color: Colors.white,
                  ),
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shimmering title (same as splash!)
  Widget _buildShimmeringTitle() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF1A1A1A),
                Color(0xFF4A4A4A),
                Color(0xFF1A1A1A),
              ],
              stops: [
                math.max(0.0, _shimmerPosition.value - 0.3),
                _shimmerPosition.value,
                math.min(1.0, _shimmerPosition.value + 0.3),
              ],
            ).createShader(bounds);
          },
          child: const Text(
            'FinzoBilling',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1.0,
              height: 1.0,
            ),
          ),
        );
      },
    );
  }

  // India Badge (same as splash!)
  Widget _buildIndiaBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF9933),
            Color(0xFF138808),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9933).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🇮🇳',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Text(
            'Made in India',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.25),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Premium text field
  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary.withOpacity(0.7), size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  // Premium button
  Widget _buildPremiumButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required String label,
    required bool isPrimary,
    String? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: isPrimary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : (icon != null
                      ? Image.network(
                          icon,
                          height: 24,
                          width: 24,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.login, size: 24);
                          },
                        )
                      : const SizedBox.shrink()),
              label: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }
}
