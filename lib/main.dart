// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ ADDED
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// Import your screens
import 'firebase_options.dart';
import 'dashboard_screen.dart';
import 'auth_screen.dart';
import 'reports_screen.dart';
import 'purchases_list_screen.dart';
import 'clients_screen.dart';
import 'screens/client_ledger_screen.dart';
import 'screens/purchase_reports_screen.dart';
import 'services/analytics_service.dart';
import 'screens/credit_notes_list_screen.dart';
import 'screens/create_credit_note_screen.dart';
import 'screens/onboarding/business_setup_screen.dart';
import 'screens/onboarding/welcome_tour_screen.dart';
import 'screens/splash_screen.dart';

// ✅ NEW: Admin screens
import 'screens/admin/admin_dashboard.dart';

// Premium Design System
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ✅ FIXED: Only lock orientation on mobile (not web)
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // ✅ FIXED: Only set system UI overlay on mobile
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    }

    // Initialize date formatting for India
    await initializeDateFormatting('en_IN', null);
    Intl.defaultLocale = 'en_IN';

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable Firestore offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // ✅ FIXED: Crashlytics only on mobile (not web)
    if (!kIsWeb) {
      // Crashlytics error handlers
      FlutterError.onError = (FlutterErrorDetails details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        debugPrint('Flutter Error: ${details.exception}');
        debugPrint('Stack: ${details.stack}');
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      // ✅ ADDED: Web error handling (console logging)
      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('Flutter Error: ${details.exception}');
        debugPrint('Stack: ${details.stack}');
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Uncaught Error: $error');
        debugPrint('Stack: $stack');
        return true;
      };
    }

    // Run the app
    runApp(const MyApp());
  }, (Object error, StackTrace stack) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    debugPrint('Uncaught Error: $error');
    debugPrint('Stack: $stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinzoBilling',
      debugShowCheckedModeBanner: false,
      
      // ✅ IMPROVED: Use custom premium theme
      themeMode: ThemeMode.system,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      
      navigatorObservers: [
        AnalyticsService().analyticsObserver,
      ],
      
      initialRoute: '/',
      
      routes: {
        '/': (ctx) => SplashScreen(),
        '/home': (ctx) => const AuthGate(),
        '/dashboard': (ctx) => const DashboardScreen(),
        '/login': (ctx) => const AuthGate(),
        '/reports': (ctx) => const ReportsScreen(),
        '/purchases': (ctx) => const PurchasesListScreen(),
        '/clients': (ctx) => const ClientsScreen(),
        '/client-ledger': (ctx) => const ClientLedgerScreen(),
        '/purchase-reports': (ctx) => const PurchaseReportsScreen(),
        '/credit_notes': (context) => const CreditNotesListScreen(),
        '/create_credit_note': (context) => const CreateCreditNoteScreen(),
        '/business-setup': (context) => const BusinessSetupScreen(),
        '/welcome-tour': (context) => const WelcomeTourScreen(),
        
        // ✅ NEW: Admin route
        '/admin': (context) => AdminDashboard(),
      },
      
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
                MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2)),
          ),
          child: child!,
        );
      },
    );
  }
}

// ✅ REDESIGNED: Premium AuthGate with smooth animations
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ✅ IMPROVED: Beautiful loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen(context);
        }

        // ✅ IMPROVED: Better error handling
        if (snapshot.hasError) {
          return _buildErrorScreen(context, snapshot.error);
        }

        // Not authenticated
        if (!snapshot.hasData) {
          return const AuthScreen();
        }

        // ✅ IMPROVED: Smooth onboarding check
        final user = snapshot.data!;
        return _buildOnboardingCheck(context, user);
      },
    );
  }

  // ✅ NEW: Premium loading screen
  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium loading spinner
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Premium error screen
  Widget _buildErrorScreen(BuildContext context, Object? error) {
    AnalyticsService().recordError(
      error!,
      StackTrace.current,
      reason: 'Auth state error',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ Error icon with animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                const Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'We encountered an error while loading the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // ✅ Premium retry button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Smooth onboarding check
  Widget _buildOnboardingCheck(BuildContext context, User user) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen(context);
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const BusinessSetupScreen();
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final onboardingComplete = userData?['onboardingComplete'] ?? false;

        AnalyticsService().setUserId(user.uid);

        if (!onboardingComplete) {
          return const BusinessSetupScreen();
        }

        return const DashboardScreen();
      },
    );
  }
}
