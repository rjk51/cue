import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  // RevenueCat API Keys
  // NOTE: This is a test key. Replace with production keys before release
  static const String _appleApiKey = 'test_MpMYAkZJHyTvuynILFqEaRPUJgm';
  static const String _googleApiKey = 'test_MpMYAkZJHyTvuynILFqEaRPUJgm';

  // Entitlement identifier - configured in RevenueCat dashboard
  static const String proEntitlementId = 'Cue Pro';

  // Product identifiers
  static const String monthlyProductId = 'monthly';
  static const String yearlyProductId = 'yearly';
  static const String lifetimeProductId = 'lifetime';

  bool _isConfigured = false;

  /// Initialize RevenueCat SDK
  /// Call this in your main.dart before runApp()
  Future<void> initialize({String? userId}) async {
    if (_isConfigured) {
      if (kDebugMode) {
        print('RevenueCat already configured');
      }
      return;
    }

    try {
      // Configure SDK based on platform
      final configuration = PurchasesConfiguration(
        Platform.isIOS ? _appleApiKey : _googleApiKey,
      );

      if (userId != null) {
        configuration.appUserID = userId;
      }

      // Enable debug logs in debug mode
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      await Purchases.configure(configuration);
      _isConfigured = true;

      if (kDebugMode) {
        print('RevenueCat configured successfully');
      }

      // Set up listeners
      _setupListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error configuring RevenueCat: $e');
      }
      rethrow;
    }
  }

  /// Set up purchase update listeners
  void _setupListeners() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      if (kDebugMode) {
        print('Customer info updated: ${customerInfo.entitlements.all}');
      }
      // Handle customer info updates
      // You can notify listeners or update state here
    });
  }

  /// Get current customer info
  Future<CustomerInfo> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting customer info: $e');
      }
      rethrow;
    }
  }

  /// Get available offerings
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting offerings: $e');
      }
      return null;
    }
  }

  /// Purchase a package
  Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      final purchaseResult = await Purchases.purchasePackage(package);
      if (kDebugMode) {
        print('Purchase successful: ${purchaseResult.customerInfo.entitlements.all}');
      }
      return purchaseResult.customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        if (kDebugMode) {
          print('User cancelled purchase');
        }
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        if (kDebugMode) {
          print('User not allowed to purchase');
        }
      } else {
        if (kDebugMode) {
          print('Error purchasing: $e');
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error purchasing: $e');
      }
      return null;
    }
  }

  /// Restore purchases
  Future<CustomerInfo?> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      if (kDebugMode) {
        print('Purchases restored: ${customerInfo.entitlements.all}');
      }
      return customerInfo;
    } catch (e) {
      if (kDebugMode) {
        print('Error restoring purchases: $e');
      }
      return null;
    }
  }

  /// Check if user has active entitlement
  Future<bool> hasActiveEntitlement(String entitlementId) async {
    try {
      final customerInfo = await getCustomerInfo();
      return customerInfo.entitlements.all[entitlementId]?.isActive ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking entitlement: $e');
      }
      return false;
    }
  }

  /// Check if user has Cue Pro subscription
  Future<bool> hasCueProAccess() async {
    return hasActiveEntitlement(proEntitlementId);
  }

  /// Login user (for cross-platform support)
  Future<CustomerInfo?> login(String userId) async {
    try {
      final logInResult = await Purchases.logIn(userId);
      if (kDebugMode) {
        print('User logged in: $userId');
      }
      return logInResult.customerInfo;
    } catch (e) {
      if (kDebugMode) {
        print('Error logging in: $e');
      }
      return null;
    }
  }

  /// Logout user
  Future<CustomerInfo?> logout() async {
    try {
      final customerInfo = await Purchases.logOut();
      if (kDebugMode) {
        print('User logged out');
      }
      return customerInfo;
    } catch (e) {
      if (kDebugMode) {
        print('Error logging out: $e');
      }
      return null;
    }
  }

  /// Get product information
  Future<List<StoreProduct>> getProducts(List<String> productIds) async {
    try {
      return await Purchases.getProducts(
        productIds,
        type: PurchaseType.subs,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting products: $e');
      }
      return [];
    }
  }

  /// Check subscription status
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final customerInfo = await getCustomerInfo();
      final activeEntitlements = customerInfo.entitlements.active;
      
      return {
        'hasActiveSubscription': activeEntitlements.isNotEmpty,
        'entitlements': activeEntitlements.keys.toList(),
        'expirationDate': activeEntitlements.values.isNotEmpty
            ? activeEntitlements.values.first.expirationDate
            : null,
        'willRenew': activeEntitlements.values.isNotEmpty
            ? activeEntitlements.values.first.willRenew
            : false,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting subscription status: $e');
      }
      return {
        'hasActiveSubscription': false,
        'entitlements': [],
        'expirationDate': null,
        'willRenew': false,
      };
    }
  }

  /// Present paywall (if using RevenueCat Paywalls)
  Future<void> presentPaywall() async {
    try {
      // This requires RevenueCat Paywalls feature
      // You need to configure paywalls in the RevenueCat dashboard
      await Purchases.presentCodeRedemptionSheet();
    } catch (e) {
      if (kDebugMode) {
        print('Error presenting paywall: $e');
      }
    }
  }

  /// Set user attributes for targeting
  Future<void> setUserAttributes(Map<String, String> attributes) async {
    try {
      for (var entry in attributes.entries) {
        await Purchases.setAttributes({entry.key: entry.value});
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting attributes: $e');
      }
    }
  }

  /// Set email for customer support
  Future<void> setEmail(String email) async {
    try {
      await Purchases.setEmail(email);
    } catch (e) {
      if (kDebugMode) {
        print('Error setting email: $e');
      }
    }
  }

  /// Set display name
  Future<void> setDisplayName(String displayName) async {
    try {
      await Purchases.setDisplayName(displayName);
    } catch (e) {
      if (kDebugMode) {
        print('Error setting display name: $e');
      }
    }
  }

  /// Set phone number
  Future<void> setPhoneNumber(String phoneNumber) async {
    try {
      await Purchases.setPhoneNumber(phoneNumber);
    } catch (e) {
      if (kDebugMode) {
        print('Error setting phone number: $e');
      }
    }
  }
}
