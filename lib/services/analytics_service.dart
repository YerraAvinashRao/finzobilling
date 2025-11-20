import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  // Navigator observer for automatic screen tracking
  FirebaseAnalyticsObserver get analyticsObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ==================== AUTH EVENTS ====================
  Future<void> logLogin(String method) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      debugPrint('📊 Analytics: Login - $method');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  Future<void> logSignUp(String method) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      debugPrint('📊 Analytics: SignUp - $method');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: 'logout');
      debugPrint('📊 Analytics: Logout');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  // ==================== INVOICE EVENTS ====================
  Future<void> logInvoiceCreated({
    required double amount,
    required String clientId,
    required int itemCount,
    required bool isInterState,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'invoice_created',
        parameters: {
          'amount': amount,
          'client_id': clientId,
          'item_count': itemCount,
          'is_inter_state': isInterState,
          'currency': 'INR',
        },
      );
      debugPrint('📊 Analytics: Invoice Created - ₹$amount');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  Future<void> logPdfGenerated(String invoiceId, String action) async {
    try {
      await _analytics.logEvent(
        name: 'pdf_generated',
        parameters: {
          'invoice_id': invoiceId,
          'action': action, // 'preview', 'share', 'print'
        },
      );
      debugPrint('📊 Analytics: PDF $action - $invoiceId');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  // ==================== PRODUCT EVENTS ====================
  
  // ✅ NEW: Add this method
  Future<void> logProductCreated({required String productId}) async {
    try {
      await _analytics.logEvent(
        name: 'product_created',
        parameters: {
          'product_id': productId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('📊 Analytics: Product Created - $productId');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  Future<void> logProductAdded(String category, double price) async {
    try {
      await _analytics.logEvent(
        name: 'product_added',
        parameters: {
          'category': category,
          'price': price,
        },
      );
      debugPrint('📊 Analytics: Product Added - $category');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  Future<void> logStockAdjusted({
    required String productId,
    required int quantity,
    required String reason,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'stock_adjusted',
        parameters: {
          'product_id': productId,
          'quantity': quantity,
          'reason': reason,
        },
      );
      debugPrint('📊 Analytics: Stock Adjusted - $quantity');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  // ==================== CLIENT EVENTS ====================
  Future<void> logClientAdded() async {
    try {
      await _analytics.logEvent(name: 'client_added');
      debugPrint('📊 Analytics: Client Added');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  // ==================== PAYMENT EVENTS ====================
  Future<void> logPaymentRecorded({
    required double amount,
    required String invoiceId,
    required String method,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'payment_recorded',
        parameters: {
          'amount': amount,
          'invoice_id': invoiceId,
          'payment_method': method,
        },
      );
      debugPrint('📊 Analytics: Payment - ₹$amount');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  // ==================== PURCHASE EVENTS ====================
  Future<void> logPurchaseCreated({
    required double amount,
    required String supplier,
    required int itemCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'purchase_created',
        parameters: {
          'amount': amount,
          'supplier': supplier,
          'item_count': itemCount,
        },
      );
      debugPrint('📊 Analytics: Purchase - ₹$amount');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  // ==================== REPORT EVENTS ====================
  Future<void> logReportViewed(String reportType) async {
    try {
      await _analytics.logEvent(
        name: 'report_viewed',
        parameters: {'report_type': reportType},
      );
      debugPrint('📊 Analytics: Report Viewed - $reportType');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  // ==================== USER PROPERTIES ====================
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
      await _crashlytics.setUserIdentifier(userId);
      debugPrint('📊 Analytics: User ID Set - $userId');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  // ==================== ERROR TRACKING ====================
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      await _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
      );
      debugPrint('🔴 Error Recorded: $exception');
    } catch (e) {
      debugPrint('❌ Crashlytics error: $e');
    }
  }

  // ==================== CUSTOM LOGS ====================
  Future<void> log(String message) async {
    try {
      await _crashlytics.log(message);
    } catch (e) {
      debugPrint('❌ Log error: $e');
    }
  }
}
