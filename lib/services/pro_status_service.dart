import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'revenue_cat_service.dart';

class ProStatusService {
  static final ProStatusService _instance = ProStatusService._internal();
  factory ProStatusService() => _instance;
  ProStatusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RevenueCatService _revenueCat = RevenueCatService();

  /// Check if user has Pro access (from RevenueCat OR promo code)
  Future<bool> hasProAccess() async {
    try {
      // First check RevenueCat subscription
      final hasRevenueCatPro = await _revenueCat.hasCueProAccess();
      if (hasRevenueCatPro) return true;

      // Check if user has promo code pro access
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final proExpiry = userDoc.data()?['proExpiryDate'] as Timestamp?;
      if (proExpiry == null) return false;

      // Check if pro access is still valid
      final expiryDate = proExpiry.toDate();
      final now = DateTime.now();
      
      return expiryDate.isAfter(now);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking pro access: $e');
      }
      return false;
    }
  }

  /// Get pro expiry date (null if not pro or expired)
  Future<DateTime?> getProExpiryDate() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final proExpiry = userDoc.data()?['proExpiryDate'] as Timestamp?;
      if (proExpiry == null) return null;

      final expiryDate = proExpiry.toDate();
      final now = DateTime.now();
      
      // Return only if not expired
      return expiryDate.isAfter(now) ? expiryDate : null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting pro expiry date: $e');
      }
      return null;
    }
  }

  /// Redeem a promo code
  Future<bool> redeemPromoCode(String code) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Check if code is valid (for now, only "WELCOME")
      if (code.toUpperCase() != 'WELCOME') {
        throw Exception('Invalid promo code');
      }

      // Calculate expiry date (30 days from now)
      final expiryDate = DateTime.now().add(const Duration(days: 30));

      // Store in Firestore
      await _firestore.collection('users').doc(userId).set(
        {
          'proExpiryDate': Timestamp.fromDate(expiryDate),
          'proSource': 'promo_code',
          'promoCode': code.toUpperCase(),
          'promoRedeemedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (kDebugMode) {
        print('Pro access granted via promo code until: $expiryDate');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error redeeming promo code: $e');
      }
      rethrow;
    }
  }

  /// Get the source of pro access ('revenuecat', 'promo_code', or null)
  Future<String?> getProSource() async {
    try {
      // Check RevenueCat first
      final hasRevenueCatPro = await _revenueCat.hasCueProAccess();
      if (hasRevenueCatPro) return 'revenuecat';

      // Check promo code
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final proExpiry = userDoc.data()?['proExpiryDate'] as Timestamp?;
      if (proExpiry == null) return null;

      final expiryDate = proExpiry.toDate();
      final now = DateTime.now();
      
      if (expiryDate.isAfter(now)) {
        return userDoc.data()?['proSource'] as String? ?? 'promo_code';
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting pro source: $e');
      }
      return null;
    }
  }
}
