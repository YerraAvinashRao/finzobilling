import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:finzobilling/services/analytics_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Password strength
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';

  // Premium animations (same as splash!)
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _shakeController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseScale;
  late Animation<double> _shimmerPosition;
  late Animation<double> _shakeAnimation;

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

    _fadeController.forward();
    _passwordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _shakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
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
    if (_isLogin) return;

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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
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
      final auth = FirebaseAuth.instance;
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isLogin) {
        await auth
            .signInWithEmailAndPassword(email: email, password: password)
            .timeout(const Duration(seconds: 10));

        await AnalyticsService().logLogin('email');
      } else {
        final username = _usernameController.text.trim();
        final userCredential = await auth
            .createUserWithEmailAndPassword(email: email, password: password)
            .timeout(const Duration(seconds: 15));

        final user = userCredential.user;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'username': username,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'loginMethod': 'email',
            'onboardingComplete': false,
          });
          await user.updateDisplayName(username);

          await AnalyticsService().logSignUp('email');
          await AnalyticsService().setUserId(user.uid);
        }
      }
    } on FirebaseAuthException catch (e) {
      await AnalyticsService().recordError(
        e,
        StackTrace.current,
        reason: _isLogin ? 'Login failed: ${e.code}' : 'Signup failed: ${e.code}',
      );

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
        case 'user-not-found':
        case 'invalid-credential':
        case 'wrong-password':
          msg = 'Invalid email or password';
          break;
        case 'user-disabled':
          msg = 'This account has been disabled';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Try again later';
          break;
        case 'network-request-failed':
          msg = 'Network error. Check your connection';
          break;
      }
      _showError(msg);
    } on TimeoutException {
      await AnalyticsService().recordError(
        TimeoutException('Auth request timed out'),
        StackTrace.current,
        reason: 'Auth timeout',
      );
      _showError('Request timed out. Check your connection');
    } catch (e) {
      await AnalyticsService().recordError(
        e,
        StackTrace.current,
        reason: 'Unexpected auth error',
      );
      _showError('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
      _passwordStrength = 0.0;
      _passwordStrengthText = '';
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  // Add this method after _toggleAuthMode()
  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_reset,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reset Password',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email and we\'ll send you instructions to reset your password.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'your@email.com',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final email = emailController.text.trim();
              
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid email'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                
                // Close loading
                if (mounted) Navigator.pop(context);
                
                // Close dialog
                if (mounted) Navigator.pop(context, true);
              } catch (e) {
                // Close loading
                if (mounted) Navigator.pop(context);
                
                String errorMessage = 'Failed to send reset email';
                
                if (e.toString().contains('user-not-found')) {
                  errorMessage = 'No account found with this email';
                } else if (e.toString().contains('invalid-email')) {
                  errorMessage = 'Invalid email address';
                }
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Send Reset Link'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 60,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Email Sent!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Password reset link sent to ${emailController.text}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your email and follow the instructions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Got it!'),
            ),
          ],
        ),
      );
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
                            Text(
                              _isLogin ? 'Sign In' : 'Create Account',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isLogin
                                  ? 'Enter your credentials to continue'
                                  : 'Join us and start managing your business',
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

                            // Username field (signup only)
                            if (!_isLogin) ...[
                              _buildPremiumTextField(
                                controller: _usernameController,
                                label: 'Username',
                                hint: 'Choose a username',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isEmpty) return 'Username is required';
                                  if (v.length < 4) return 'At least 4 characters';
                                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                                    return 'Only letters, numbers, underscores';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

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
                              hint: _isLogin ? 'Enter your password' : 'Create a strong password',
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

                            // Password strength indicator (signup only)
                            if (!_isLogin && _passwordController.text.isNotEmpty) ...[
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

                            // Forgot password (login only)
                            if (_isLogin) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _handleForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Premium Submit Button
                            _buildPremiumButton(
                              onPressed: _isLoading ? null : _submit,
                              isLoading: _isLoading,
                              label: _isLogin ? 'Sign In' : 'Create Account',
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
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              isLoading: false,
                              label: _isLogin ? 'Continue with Google' : 'Sign up with Google',
                              icon: 'https://www.google.com/favicon.ico',
                              isPrimary: false,
                            ),

                            const SizedBox(height: 24),

                            // Toggle auth mode link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isLogin
                                      ? "Don't have an account? "
                                      : 'Already have an account? ',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isLoading ? null : _toggleAuthMode,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _isLogin ? 'Sign Up' : 'Sign In',
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
                      'By continuing, you agree to our Terms & Privacy Policy',
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
    );
  }

  // METALLIC LOGO (Exact same as splash!)
  Widget _buildMetallicLogo() {
  return Hero(  // ✅ ADD THIS - SAME TAG!
    tag: 'app_logo_hero',  // ✅ SAME TAG as splash screen
    child: Container(
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
    ),
  );  // ✅ Hero ends here
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
              icon: icon != null
                  ? Image.network(
                      icon,
                      height: 24,
                      width: 24,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.login, size: 24);
                      },
                    )
                  : const SizedBox.shrink(),
              label: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }
}
