import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'revenue_cat_service.dart';

@immutable
class TrialInfo {
  final bool isPro;
  final bool isTrialActive;
  final DateTime? expiryDate;
  final int daysElapsed;
  final int daysRemaining;
  final String? source; // 'free_trial', 'promo_code', 'revenuecat', etc.

  const TrialInfo({
    required this.isPro,
    required this.isTrialActive,
    this.expiryDate,
    required this.daysElapsed,
    required this.daysRemaining,
    this.source,
  });
}

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
      // If user is logged in, check Firestore user doc for promo/trial
      final userId = _auth.currentUser?.uid;
      final now = DateTime.now();

      if (userId != null) {
        final userDocRef = _firestore.collection('users').doc(userId);
        final userDoc = await userDocRef.get();

        // If doc doesn't exist, create minimal doc and grant trial
        if (!userDoc.exists) {
          // Grant a 14-day free trial for new users
          final expiryDate = now.add(const Duration(days: 14));
          await userDocRef.set({
            'proExpiryDate': Timestamp.fromDate(expiryDate),
            'proSource': 'free_trial',
            'trialGranted': true,
            'trialGrantedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return true;
        }

        final proExpiry = userDoc.data()?['proExpiryDate'] as Timestamp?;
        final trialGranted = userDoc.data()?['trialGranted'] as bool? ?? false;

        // If user already has a valid proExpiry, respect it
        if (proExpiry != null) {
          final expiryDate = proExpiry.toDate();
          if (expiryDate.isAfter(now)) return true;
        }

        // If trial hasn't been granted yet, grant a one-time 14-day free trial
        if (!trialGranted) {
          final expiryDate = now.add(const Duration(days: 14));
          await userDocRef.set({
            'proExpiryDate': Timestamp.fromDate(expiryDate),
            'proSource': 'free_trial',
            'trialGranted': true,
            'trialGrantedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return true;
        }

        return false;
      }

      // If user is not logged in, fall back to local SharedPreferences trial
      final prefs = await SharedPreferences.getInstance();
      final localExpiryMs = prefs.getInt('local_pro_expiry_ms');
      final localTrialGranted = prefs.getBool('local_trial_granted') ?? false;

      if (localExpiryMs != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(localExpiryMs);
        if (expiryDate.isAfter(now)) return true;
      }

      if (!localTrialGranted) {
        final expiryDate = now.add(const Duration(days: 14));
        await prefs.setInt('local_pro_expiry_ms', expiryDate.millisecondsSinceEpoch);
        await prefs.setBool('local_trial_granted', true);
        await prefs.setInt('local_trial_granted_at_ms', now.millisecondsSinceEpoch);
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking pro access: $e');
      }
      return false;
    }
  }

  /// Returns trial info including days elapsed/remaining for the 14-day free trial.
  Future<TrialInfo> getTrialInfo() async {
    try {
      final now = DateTime.now();

      // RevenueCat users are considered Pro but not on the app-managed free trial
      final hasRevenueCatPro = await _revenueCat.hasCueProAccess();
      if (hasRevenueCatPro) {
        return TrialInfo(
          isPro: true,
          isTrialActive: false,
          expiryDate: null,
          daysElapsed: 0,
          daysRemaining: 0,
          source: 'revenuecat',
        );
      }

      final userId = _auth.currentUser?.uid;

      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          return TrialInfo(isPro: false, isTrialActive: false, expiryDate: null, daysElapsed: 0, daysRemaining: 0, source: null);
        }

        final data = userDoc.data() ?? {};
        final proExpiry = data['proExpiryDate'] as Timestamp?;
        final proSource = data['proSource'] as String?;
        final trialGrantedAt = data['trialGrantedAt'] as Timestamp?;

        if (proExpiry == null) {
          return TrialInfo(isPro: false, isTrialActive: false, expiryDate: null, daysElapsed: 0, daysRemaining: 0, source: null);
        }

        final expiryDate = proExpiry.toDate();
        final isActive = expiryDate.isAfter(now);

        if (proSource == 'free_trial') {
          // Determine start
          DateTime start;
          if (trialGrantedAt != null) {
            start = trialGrantedAt.toDate();
          } else {
            start = expiryDate.subtract(const Duration(days: 14));
          }

          final elapsed = now.difference(start).inDays.clamp(0, 14);
          final remaining = expiryDate.difference(now).inDays.clamp(0, 14);

          return TrialInfo(
            isPro: isActive,
            isTrialActive: isActive && proSource == 'free_trial',
            expiryDate: expiryDate,
            daysElapsed: elapsed,
            daysRemaining: remaining < 0 ? 0 : remaining,
            source: proSource,
          );
        }

        // Not a free trial — return pro/promo info
        return TrialInfo(
          isPro: isActive,
          isTrialActive: false,
          expiryDate: expiryDate,
          daysElapsed: 0,
          daysRemaining: expiryDate.difference(now).inDays > 0 ? expiryDate.difference(now).inDays : 0,
          source: proSource,
        );
      }

      // Anonymous/local fallback
      final prefs = await SharedPreferences.getInstance();
      final localExpiryMs = prefs.getInt('local_pro_expiry_ms');
      final localGrantedAtMs = prefs.getInt('local_trial_granted_at_ms');

      if (localExpiryMs == null) {
        return TrialInfo(isPro: false, isTrialActive: false, expiryDate: null, daysElapsed: 0, daysRemaining: 0, source: null);
      }

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(localExpiryMs);
      final isActive = expiryDate.isAfter(now);

      DateTime start;
      if (localGrantedAtMs != null) {
        start = DateTime.fromMillisecondsSinceEpoch(localGrantedAtMs);
      } else {
        start = expiryDate.subtract(const Duration(days: 14));
      }

      final elapsed = now.difference(start).inDays.clamp(0, 14);
      final remaining = expiryDate.difference(now).inDays.clamp(0, 14);

      return TrialInfo(
        isPro: isActive,
        isTrialActive: isActive,
        expiryDate: expiryDate,
        daysElapsed: elapsed,
        daysRemaining: remaining < 0 ? 0 : remaining,
        source: 'free_trial',
      );
    } catch (e) {
      if (kDebugMode) print('Error getting trial info: $e');
      return TrialInfo(isPro: false, isTrialActive: false, expiryDate: null, daysElapsed: 0, daysRemaining: 0, source: null);
    }
  }

  /// Get pro expiry date (null if not pro or expired)
  Future<DateTime?> getProExpiryDate() async {
    try {
      final userId = _auth.currentUser?.uid;
      final now = DateTime.now();

      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) return null;

        final proExpiry = userDoc.data()?['proExpiryDate'] as Timestamp?;
        if (proExpiry == null) return null;

        final expiryDate = proExpiry.toDate();
        return expiryDate.isAfter(now) ? expiryDate : null;
      }

      // Anonymous/local fallback
      final prefs = await SharedPreferences.getInstance();
      final localExpiryMs = prefs.getInt('local_pro_expiry_ms');
      if (localExpiryMs == null) return null;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(localExpiryMs);
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
      final userId = _auth.currentUser?.uid;
      final now = DateTime.now();

      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) return null;

        final proExpiry = userDoc.data()?['proExpiryDate'] as Timestamp?;
        if (proExpiry == null) return null;

        final expiryDate = proExpiry.toDate();
        if (expiryDate.isAfter(now)) {
          return userDoc.data()?['proSource'] as String? ?? 'promo_code';
        }

        return null;
      }

      // Anonymous/local fallback
      final prefs = await SharedPreferences.getInstance();
      final localExpiryMs = prefs.getInt('local_pro_expiry_ms');
      if (localExpiryMs == null) return null;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(localExpiryMs);
      return expiryDate.isAfter(now) ? 'free_trial' : null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting pro source: $e');
      }
      return null;
    }
  }
}
