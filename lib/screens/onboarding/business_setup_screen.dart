import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:finzobilling/widgets/animated_accountant_assistant.dart';

class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _gstinController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedState = 'Karnataka';
  bool _isLoading = false;

  // ✅ ADD THESE 5 LINES HERE (after _isLoading):
  int _completedFieldsCount = 0;
  String? _assistantMessage = "Hi! Let's set up your business! 👋";
  bool _showCelebration = false;
  final List<String> _completedFields = [];
  final List<String> _messages = [
    "Hi! Let's set up your business! 👋",
    "Great start! Keep going! 💪",
    "Perfect! You're doing amazing! 🎯",
    "Almost there! Just a bit more! 🚀",
    "Fantastic work! One more! ⭐",
    "Excellent! All done! 🎉",
  ];

  // ✨ Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _shimmerController;
  late AnimationController _logoBreathController;
  late AnimationController _floatingController;
  late AnimationController _particleController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shimmerPosition;
  late Animation<double> _logoBreath;
  late Animation<double> _floatingAnimation;

  final Map<String, String> _indianStates = {
    'Andaman and Nicobar Islands': '35',
    'Andhra Pradesh': '37',
    'Arunachal Pradesh': '12',
    'Assam': '18',
    'Bihar': '10',
    'Chandigarh': '04',
    'Chhattisgarh': '22',
    'Dadra and Nagar Haveli and Daman and Diu': '26',
    'Delhi': '07',
    'Goa': '30',
    'Gujarat': '24',
    'Haryana': '06',
    'Himachal Pradesh': '02',
    'Jammu and Kashmir': '01',
    'Jharkhand': '20',
    'Karnataka': '29',
    'Kerala': '32',
    'Ladakh': '38',
    'Lakshadweep': '31',
    'Madhya Pradesh': '23',
    'Maharashtra': '27',
    'Manipur': '14',
    'Meghalaya': '17',
    'Mizoram': '15',
    'Nagaland': '13',
    'Odisha': '21',
    'Puducherry': '34',
    'Punjab': '03',
    'Rajasthan': '08',
    'Sikkim': '11',
    'Tamil Nadu': '33',
    'Telangana': '36',
    'Tripura': '16',
    'Uttar Pradesh': '09',
    'Uttarakhand': '05',
    'West Bengal': '19',
  };

  @override
  void initState() {
    super.initState();
    
    // Fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Slide animation
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

    // Shimmer animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    
    _shimmerPosition = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // ✨ NEW: Logo breathing animation
    _logoBreathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _logoBreath = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _logoBreathController, curve: Curves.easeInOut),
    );

    // ✨ NEW: Floating banner animation
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    
    _floatingAnimation = Tween<double>(begin: -15.0, end: 15.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    // ✨ NEW: Particle animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 20000),
    )..repeat();

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _shimmerController.dispose();
    _logoBreathController.dispose();
    _floatingController.dispose();
    _particleController.dispose();
    _businessNameController.dispose();
    _gstinController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveBusinessInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'email': user.email,
        'onboardingComplete': true,
        'setupCompletedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('business_details')
          .set({
        'name': _businessNameController.text.trim(),
        'gstin': _gstinController.text.trim().toUpperCase(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'state': _selectedState,
        'stateCode': _indianStates[_selectedState],
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/welcome-tour');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving business info: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ ADD THIS ENTIRE METHOD HERE (after _saveBusinessInfo):
  void _markFieldComplete(String fieldName) {
    if (!_completedFields.contains(fieldName)) {
      setState(() {
        _completedFields.add(fieldName);
        _completedFieldsCount = _completedFields.length;
        _assistantMessage = _messages[_completedFieldsCount.clamp(0, 5)];
        _showCelebration = true;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _showCelebration = false);
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ✨ Animated background with floating particles
          _buildAnimatedBackground(),
          
          // Main content
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.5,
                colors: [
                  Colors.white.withOpacity(0.95),
                  const Color(0xFFFAFAFA).withOpacity(0.95),
                ],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // ✨ Animated breathing logo with Hero
                          _buildAnimatedLogo(),

                          const SizedBox(height: 24),

                          // Shimmering welcome title
                          _buildShimmeringTitle(),

                          const SizedBox(height: 8),

                          // ✨ Animated subtitle
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              'Let\'s set up your business profile',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ✨ Animated form card
                          _buildAnimatedFormCard(),

                          const SizedBox(height: 24),

                          // ✨ Animated button
                          _buildAnimatedButton(),

                          const SizedBox(height: 24),

                          // ✨ Floating info banner
                          _buildFloatingBanner(),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ✅ ACCOUNTANT ASSISTANT (CORRECT VERSION)
          Positioned(
            top: 190,
            right: 16,
            child: AnimatedAccountantAssistant(
              completedFields: _completedFieldsCount,
              currentMessage: _assistantMessage,
              showCelebration: _showCelebration,
            ),
          ),
        ],
      ),
    );
  }

  // ✨ NEW: Animated floating particles background
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(_particleController.value),
          size: Size.infinite,
        );
      },
    );
  }

  // ✨ NEW: Animated breathing logo
  Widget _buildAnimatedLogo() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: AnimatedBuilder(
            animation: _logoBreath,
            builder: (context, _) {
              return Transform.scale(
                scale: _logoBreath.value,
                child: Hero(
                  tag: 'app_logo_hero',
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
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
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: -5,
                        ),
                        // ✅ PULSING BLUE GLOW
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.4 * _logoBreath.value),  // ✅ MORE VISIBLE
                          blurRadius: 50 * _logoBreath.value,  // ✅ CHANGES SIZE
                          offset: const Offset(0, 0),
                          spreadRadius: 5 * _logoBreath.value,  // ✅ SPREADS
                        ),
                        // ✅ PURPLE OUTER GLOW
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3 * _logoBreath.value),
                          blurRadius: 60 * _logoBreath.value,
                          offset: const Offset(0, 0),
                          spreadRadius: 10 * _logoBreath.value,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
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
                                  Icons.business,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 35,
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
                ),
              );
            },
          ),
        );
      },
    );
  }
  Widget _buildShimmeringTitle() {
  return AnimatedBuilder(
    animation: Listenable.merge([_shimmerController, _logoBreathController]),
    builder: (context, child) {
      return Transform.scale(
        scale: 1.0 + (_logoBreathController.value * 0.02),  // ✅ Subtle scale
        child: ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF1A1A1A),
                Color(0xFF6A4AFF),  // ✅ PURPLE highlight
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
            'Welcome! 🎉',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
      );
    },
  );
}


  // ✨ NEW: Animated form card with staggered fields
  Widget _buildAnimatedFormCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(24),
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
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnimatedField('Business Name', 0, 
                    _buildPremiumTextField(
                      controller: _businessNameController,
                      hint: 'Enter your business name',
                      icon: Icons.store_outlined,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (v) {  // ✅ ADD THESE 3 LINES
                          if (v.trim().isNotEmpty) _markFieldComplete('business_name');
                        },
                      validator: (v) => v == null || v.trim().isEmpty 
                          ? 'Business name is required' 
                          : null,
                    ),
                  ),

                  _buildAnimatedField('GSTIN', 200,
                    _buildPremiumTextField(
                      controller: _gstinController,
                      hint: '22AAAAA0000A1Z5',
                      icon: Icons.receipt_long_outlined,
                      helperText: '15-character GST identification number',
                      onChanged: (v) {  // ✅ ADD THESE 3 LINES
                        if (v.length == 15) _markFieldComplete('gstin');
                      },
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(15),
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                        UpperCaseTextFormatter(),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'GSTIN is required';
                        }
                        if (v.length != 15) {
                          return 'GSTIN must be 15 characters';
                        }
                        return null;
                      },
                    ),
                  ),

                  _buildAnimatedField('State', 400,
                    _buildPremiumDropdown(),
                  ),

                  _buildAnimatedField('Phone Number', 600,
                    _buildPremiumTextField(
                      controller: _phoneController,
                      hint: '9876543210',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      onChanged: (v) {  // ✅ ADD THESE 3 LINES
                        if (v.length == 10) _markFieldComplete('phone');
                      },
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(10),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (v) => v == null || v.length != 10 
                          ? 'Enter valid 10-digit phone' 
                          : null,
                    ),
                  ),

                  _buildAnimatedField('Business Address', 800,
                    _buildPremiumTextField(
                      controller: _addressController,
                      hint: 'Enter your business address',
                      icon: Icons.location_on_outlined,
                       onChanged: (v) {  // ✅ ADD THESE 3 LINES
                        if (v.trim().isNotEmpty) _markFieldComplete('address');
                      },
                      maxLines: 3,
                      validator: (v) => v == null || v.trim().isEmpty 
                          ? 'Address is required' 
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ✨ NEW: Animated field with stagger delay
  Widget _buildAnimatedField(String label, int delayMs, Widget field) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (delayMs > 0) const SizedBox(height: 20),
                _buildFieldLabel(label, true),
                field,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFieldLabel(String text, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? helperText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,  // ✅ ADD THIS LINE
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary.withOpacity(0.7), size: 22),
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

  Widget _buildPremiumDropdown() {
  return DropdownButtonFormField<String>(
    initialValue: _selectedState,
    isExpanded: true,  // ✅ ADD THIS - fixes overflow
    decoration: InputDecoration(
      prefixIcon: Icon(
        Icons.map_outlined,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        size: 22,
      ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
    items: _indianStates.keys.map((state) {
      return DropdownMenuItem(
        value: state,
        child: Text(
          '$state (${_indianStates[state]})',
          overflow: TextOverflow.ellipsis,  // ✅ ADD THIS - prevents text overflow
          maxLines: 1,  // ✅ ADD THIS
        ),
      );
    }).toList(),
    onChanged: (value) {
      if (value != null) {
        setState(() => _selectedState = value);
        _markFieldComplete('state');  // ✅ ADD THIS LINE
      }
    },
  );
}


  // ✨ NEW: Animated bouncing button
  Widget _buildAnimatedButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveBusinessInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Continue to App Tour',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  // ✨ NEW: Floating animated banner
  Widget _buildFloatingBanner() {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatingAnimation.value),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.95 + (0.05 * value),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.shade100,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // ✨ Animated rotating icon
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 2000),
                          builder: (context, value, child) {
                            return Transform.rotate(
                              angle: value * 2 * math.pi,
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 22,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your data is encrypted and stored securely',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ✨ NEW: More visible floating particles
class ParticlePainter extends CustomPainter {
  final double animationValue;

  ParticlePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw 8 more visible floating particles
    for (int i = 0; i < 8; i++) {
      final offset = (animationValue + i * 0.125) % 1.0;
      final x = size.width * (0.1 + i * 0.11);
      final y = size.height * offset;
      
      // ✅ MORE VISIBLE gradient
      final gradient = RadialGradient(
        colors: [
          Colors.blue.withOpacity(0.25),  // ✅ INCREASED from 0.1
          Colors.purple.withOpacity(0.15),  // ✅ Added second color
          Colors.blue.withOpacity(0.0),
        ],
        stops: [0.0, 0.5, 1.0],
      );

      paint.shader = gradient.createShader(
        Rect.fromCircle(center: Offset(x, y), radius: 60 + i * 15),  // ✅ LARGER
      );

      canvas.drawCircle(Offset(x, y), 60 + i * 15, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}


// Helper: Auto-uppercase formatter
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
