// lib/screens/onboarding/welcome_tour_screen.dart
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class WelcomeTourScreen extends StatefulWidget {
  const WelcomeTourScreen({super.key});

  @override
  State<WelcomeTourScreen> createState() => _WelcomeTourScreenState();
}

class _WelcomeTourScreenState extends State<WelcomeTourScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  AnimationController? _rocketLaunchController;
  Animation<Offset>? _rocketSlideAnimation;
  Animation<double>? _rocketScaleAnimation;
  bool _isLaunching = false;

  // 🍎 APPLE iOS COLORS
  static const Color appleBackground = Color(0xFFFBFBFD);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleText = Color(0xFF1D1D1F);
  static const Color appleSecondary = Color(0xFF86868B);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleDivider = Color(0xFFD2D2D7);
  static const Color appleSubtle = Color(0xFFF5F5F7);

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      illustration: '📦',
      title: 'Smart Inventory',
      description:
          'Track products and stock levels in real-time. Get alerts before you run out!',
      accountantTip: 'I\'ll help you manage inventory effortlessly.',
    ),
    OnboardingPage(
      illustration: '📄',
      title: 'GST Invoices',
      description:
          'Generate professional invoices with automatic CGST, SGST, and IGST calculations.',
      accountantTip: 'Creating invoices is easy - just fill and print!',
    ),
    OnboardingPage(
      illustration: '💰',
      title: 'Payment Tracking',
      description:
          'Monitor payments and cash flow. Know exactly who owes you and when.',
      accountantTip: 'Never miss a payment! I\'ll keep track for you.',
    ),
    OnboardingPage(
      illustration: '📊',
      title: 'GST Reports',
      description:
          'Generate GSTR-1, GSTR-3B instantly. File your GST returns with confidence.',
      accountantTip: 'GST filing made simple - reports ready in one click!',
    ),
    OnboardingPage(
      illustration: '🚀',
      title: 'Ready to Start!',
      description:
          'Everything is set! Let\'s manage your business efficiently with FinzoBilling.',
      accountantTip: 'Excited to work with you! Let\'s get started.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _rocketLaunchController?.dispose();
    super.dispose();
  }

  void _nextPage() async {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await _launchRocket();
    }
  }

  Future<void> _launchRocket() async {
    setState(() => _isLaunching = true);

    _rocketLaunchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _rocketSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -3),
    ).animate(CurvedAnimation(
      parent: _rocketLaunchController!,
      curve: Curves.easeInCubic,
    ));

    _rocketScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.2,
    ).animate(CurvedAnimation(
      parent: _rocketLaunchController!,
      curve: Curves.easeInCubic,
    ));

    setState(() {});

    await Future.delayed(const Duration(milliseconds: 200));
    _rocketLaunchController!.forward();
    await Future.delayed(const Duration(milliseconds: 1800));

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _skip() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appleBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 🍎 Apple-style Top Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: appleAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'FinzoBilling',
                        style: TextStyle(
                          color: appleText,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),

                  // Skip button
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        backgroundColor: appleSubtle,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: appleAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: _isLaunching ? const NeverScrollableScrollPhysics() : null,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _fadeController.forward(from: 0.0);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], index);
                },
              ),
            ),

            // 🍎 Bottom section with Apple shadows
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: appleCard,
                border: Border(
                  top: BorderSide(
                    color: appleDivider.withOpacity(0.5),
                    width: 0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page indicator
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: const ExpandingDotsEffect(
                      dotHeight: 7,
                      dotWidth: 7,
                      expansionFactor: 3,
                      activeDotColor: appleAccent,
                      dotColor: Color(0xFFD2D2D7),
                      spacing: 8,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Next button - Apple style
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLaunching ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appleAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1
                                ? (_isLaunching ? 'Launching...' : 'Get Started')
                                : 'Continue',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.4,
                            ),
                          ),
                          if (!_isLaunching) ...[
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage == _pages.length - 1
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, int index) {
    final bool isLastPage = index == _pages.length - 1;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        physics: _isLaunching ? const NeverScrollableScrollPhysics() : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),

            // 🍎 Apple-style illustration circle
            if (isLastPage && _isLaunching && _rocketSlideAnimation != null && _rocketScaleAnimation != null)
              SlideTransition(
                position: _rocketSlideAnimation!,
                child: ScaleTransition(
                  scale: _rocketScaleAnimation!,
                  child: _buildIllustrationCircle(page.illustration),
                ),
              )
            else
              _buildIllustrationCircle(page.illustration),

            const SizedBox(height: 48),

            // Title - Apple typography
            AnimatedOpacity(
              opacity: _isLaunching && isLastPage ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 500),
              child: Text(
                page.title,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: appleText,
                  letterSpacing: -1.0,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // Description
            AnimatedOpacity(
              opacity: _isLaunching && isLastPage ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 500),
              child: Text(
                page.description,
                style: const TextStyle(
                  fontSize: 17,
                  color: appleSecondary,
                  height: 1.5,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 40),

            // 🍎 Apple-style assistant card
            AnimatedOpacity(
              opacity: _isLaunching && isLastPage ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: appleCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: appleDivider.withOpacity(0.5),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: appleAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/accountant_avatar.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.support_agent_rounded,
                              color: appleAccent,
                              size: 24,
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Assistant',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: appleSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            page.accountantTip,
                            style: const TextStyle(
                              fontSize: 15,
                              color: appleText,
                              height: 1.3,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustrationCircle(String emoji) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: appleSubtle,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 80),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String illustration;
  final String title;
  final String description;
  final String accountantTip;

  OnboardingPage({
    required this.illustration,
    required this.title,
    required this.description,
    required this.accountantTip,
  });
}
