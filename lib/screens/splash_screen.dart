import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  AnimationController? _logoController;
  AnimationController? _titleController;
  AnimationController? _shimmerController;
  
  Animation<double>? _logoScale;
  Animation<double>? _logoOpacity;
  Animation<double>? _titleOpacity;
  Animation<Offset>? _titleSlide;
  Animation<double>? _shimmerPosition;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Logo animation (fast)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController!, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController!, curve: Curves.easeIn),
    );

    // Title animation (fast)
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleController!, curve: Curves.easeIn),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _titleController!, curve: Curves.easeOutCubic),
    );

    // Shimmer (continuous)
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _shimmerPosition = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController!, curve: Curves.easeInOut),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    // Start logo
    _logoController?.forward();

    // Title after 400ms
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _titleController?.forward();

    // Navigate after 2 seconds total
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _logoController?.dispose();
    _titleController?.dispose();
    _shimmerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              AnimatedBuilder(
                animation: _logoController!,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScale!.value,
                    child: Opacity(
                      opacity: _logoOpacity!.value,
                      child: _buildLogo(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Title + Subtitle
              SlideTransition(
                position: _titleSlide!,
                child: FadeTransition(
                  opacity: _titleOpacity!,
                  child: Column(
                    children: [
                      _buildTitle(),
                      const SizedBox(height: 12),
                      _buildSubtitle(),
                      const SizedBox(height: 24),
                      _buildMadeInIndiaBadge(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Hero(
      tag: 'app_logo_hero',
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 15),
              spreadRadius: -5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset(
            'assets/images/app_logo.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _shimmerController!,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFF1A1A1A),
                Color(0xFF4A4A4A),
                Color(0xFF1A1A1A),
              ],
              stops: [
                math.max(0.0, _shimmerPosition!.value - 0.3),
                _shimmerPosition!.value,
                math.min(1.0, _shimmerPosition!.value + 0.3),
              ],
            ).createShader(bounds);
          },
          child: const Text(
            'FinzoBilling',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1.0,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'GST Billing Made Simple',
      style: TextStyle(
        fontSize: 15,
        color: Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildMadeInIndiaBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9933), Color(0xFF138808)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9933).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇮🇳', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Text(
            'Made in India',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
