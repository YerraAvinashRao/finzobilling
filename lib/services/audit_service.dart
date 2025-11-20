import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  // ✅ Log any action - completely separate from your main data
  Future<void> logAction({
    required String entityType, // 'invoice', 'product', 'client', etc.
    required String entityId,
    required String action, // 'CREATE', 'UPDATE', 'DELETE', 'STATUS_CHANGE'
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    List<String>? changedFields,
    String? reason,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final auditLog = {
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userEmail': user.email,
        'beforeData': beforeData,
        'afterData': afterData,
        'changedFields': changedFields,
        'reason': reason,
        'appVersion': '1.0.0', // Add your version
      };

      // ✅ Store in separate audit_logs collection - doesn't affect your existing data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('audit_logs')
          .add(auditLog);

      debugPrint('✅ Audit log created: $action on $entityType');
    } catch (e) {
      debugPrint('❌ Audit log error (non-critical): $e');
      // Don't throw - audit failure shouldn't break the app
    }
  }

  // ✅ Get audit history for any entity
  Stream<QuerySnapshot<Map<String, dynamic>>> getAuditHistory({
    required String entityType,
    required String entityId,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('audit_logs')
        .where('entityType', isEqualTo: entityType)
        .where('entityId', isEqualTo: entityId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ✅ Get all user activity
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserActivity({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('audit_logs')
        .orderBy('timestamp', descending: true);

    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query.limit(100).snapshots();
  }
}
