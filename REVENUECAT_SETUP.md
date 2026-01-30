# RevenueCat Integration Guide

## Overview
RevenueCat has been successfully integrated into your Flutter app with native paywalls and customer center support.

## ✅ What's Included

### Packages Installed
- `purchases_flutter: ^9.10.8` - Core RevenueCat SDK
- `purchases_ui_flutter: ^9.10.8` - Native paywall and customer center UI

### Configuration
- **API Key**: `test_MpMYAkZJHyTvuynILFqEaRPUJgm` (test key configured)
- **Entitlement**: `Cue Pro`
- **Products**: `monthly`, `yearly`, `lifetime`

### Features Implemented
✅ SDK Initialization with Firebase Auth integration
✅ Native Paywall UI (RevenueCat's pre-built templates)
✅ Customer Center (subscription management)
✅ Entitlement checking for "Cue Pro"
✅ Product configuration (Monthly, Yearly, Lifetime)
✅ Helper widgets for gating premium features
✅ Purchase restoration
✅ Error handling

## Setup Steps

### 1. Get Your API Keys
1. Sign up for a free account at [RevenueCat](https://www.revenuecat.com/)
2. Create a new project in the RevenueCat dashboard
3. Get your API keys:
   - Navigate to Project Settings > API Keys
   - Copy your **Apple App Store** key (for iOS)
   - Copy your **Google Play Store** key (for Android)

### 2. Update API Keys
Open `lib/services/revenue_cat_service.dart` and replace the placeholder API keys:

```dart
static const String _appleApiKey = 'YOUR_APPLE_API_KEY'; // Replace this
static const String _googleApiKey = 'YOUR_GOOGLE_API_KEY'; // Replace this
```

### 3. Enable In-App Purchase Capability (iOS)
1. Open your project in Xcode: `ios/Runner.xcworkspace`
2. Select the **Runner** target
3. Go to **Signing & Capabilities**
4. Click **+ Capability**
5. Add **In-App Purchase**

### 4. Configure Products
1. In the RevenueCat dashboard, go to **Products**
2. Create your subscription or one-time purchase products
3. Link them to your App Store Connect and Google Play Console products
4. Create **Entitlements** to control access
5. Create **Offerings** to group products for display

### 5. Initialize RevenueCat
The RevenueCat SDK needs to be initialized when your app starts. Add this to your `main.dart`:

```dart
import 'services/revenue_cat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... other initializations ...
  
  // Initialize RevenueCat
  await RevenueCatService().initialize();
  
  runApp(const MyApp());
}
```

If you have user authentication, initialize with a user ID:
```dart
await RevenueCatService().initialize(userId: 'user_123');
```

## Usage Examples

### Check if User Has Active Subscription
```dart
final hasAccess = await RevenueCatService().hasActiveEntitlement('premium');
if (hasAccess) {
  // Show premium features
}
```

### Display Available Offerings
```dart
final offerings = await RevenueCatService().getOfferings();
if (offerings?.current != null) {
  final packages = offerings!.current!.availablePackages;
  // Display packages to user
  for (var package in packages) {
    print('${package.storeProduct.title} - ${package.storeProduct.priceString}');
  }
}
```

### Purchase a Package
```dart
final package = offerings?.current?.availablePackages.first;
if (package != null) {
  final customerInfo = await RevenueCatService().purchasePackage(package);
  if (customerInfo != null) {
    // Purchase successful
    final hasAccess = customerInfo.entitlements.all['premium']?.isActive ?? false;
    if (hasAccess) {
      // Grant access to premium features
    }
  }
}
```

### Restore Purchases
```dart
final customerInfo = await RevenueCatService().restorePurchases();
if (customerInfo != null) {
  // Check for active entitlements
  final hasAccess = customerInfo.entitlements.all['premium']?.isActive ?? false;
}
```

### Get Subscription Status
```dart
final status = await RevenueCatService().getSubscriptionStatus();
print('Has active subscription: ${status['hasActiveSubscription']}');
print('Entitlements: ${status['entitlements']}');
print('Expiration date: ${status['expirationDate']}');
print('Will renew: ${status['willRenew']}');
```

### Set User Attributes (for targeting)
```dart
await RevenueCatService().setUserAttributes({
  'user_type': 'premium_trial',
  'signup_date': '2026-01-29',
});

await RevenueCatService().setEmail('user@example.com');
await RevenueCatService().setDisplayName('John Doe');
```

### Login/Logout (for cross-platform support)
```dart
// When user logs in
await RevenueCatService().login('user_123');

// When user logs out
await RevenueCatService().logout();
```

## Example: Creating a Subscription Screen

```dart
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenue_cat_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Offerings? _offerings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _isLoading = true);
    final offerings = await RevenueCatService().getOfferings();
    setState(() {
      _offerings = offerings;
      _isLoading = false;
    });
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isLoading = true);
    final customerInfo = await RevenueCatService().purchasePackage(package);
    setState(() => _isLoading = false);
    
    if (customerInfo != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase successful!')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    final customerInfo = await RevenueCatService().restorePurchases();
    setState(() => _isLoading = false);
    
    if (mounted) {
      final hasAccess = customerInfo?.entitlements.all['premium']?.isActive ?? false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasAccess 
            ? 'Purchases restored!' 
            : 'No active subscriptions found'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscribe')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _offerings?.current == null
              ? const Center(child: Text('No offerings available'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _offerings!.current!.availablePackages.length,
                        itemBuilder: (context, index) {
                          final package = _offerings!.current!.availablePackages[index];
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: ListTile(
                              title: Text(package.storeProduct.title),
                              subtitle: Text(package.storeProduct.description),
                              trailing: Text(
                                package.storeProduct.priceString,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              onTap: () => _purchasePackage(package),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextButton(
                        onPressed: _restorePurchases,
                        child: const Text('Restore Purchases'),
                      ),
                    ),
                  ],
                ),
    );
  }
}
```

## Testing

### iOS Sandbox Testing
1. Create a sandbox test account in App Store Connect
2. Sign out of your real Apple ID on your device
3. Run your app and attempt a purchase
4. Use your sandbox test account when prompted

### Android Testing
1. Add test accounts in Google Play Console
2. Upload your app to internal testing track
3. Install the app from Play Store
4. Test purchases with your test account

### Testing RevenueCat Dashboard
You can see all test purchases in the RevenueCat dashboard under **Customers**.

## Common Issues

### Issue: "Purchases not configured"
**Solution**: Make sure you call `RevenueCatService().initialize()` before using any other methods.

### Issue: "No products found"
**Solution**: 
1. Verify products are created in App Store Connect / Google Play Console
2. Ensure products are linked in RevenueCat dashboard
3. Wait for products to sync (can take a few hours)

### Issue: Purchase fails silently
**Solution**: Enable debug logs in development to see detailed error messages.

## Next Steps

1. **Configure Products**: Set up your products in App Store Connect and Google Play Console
2. **Link Products**: Connect them in the RevenueCat dashboard
3. **Test Purchases**: Use sandbox/test accounts to verify everything works
4. **Implement UI**: Create your subscription/paywall screens
5. **Monitor**: Use the RevenueCat dashboard to track subscriptions and revenue

## Resources

- [RevenueCat Documentation](https://www.revenuecat.com/docs)
- [Flutter SDK Documentation](https://www.revenuecat.com/docs/flutter)
- [Sample Apps](https://github.com/RevenueCat/purchases-flutter/tree/main/revenuecat_examples)
- [Dashboard Guide](https://www.revenuecat.com/docs/getting-started)

## Support

- RevenueCat Support: support@revenuecat.com
- Community Slack: [Join here](https://www.revenuecat.com/slack)
- GitHub Issues: [Report here](https://github.com/RevenueCat/purchases-flutter/issues)
