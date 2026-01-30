# 🚀 RevenueCat Quick Start

## Before You Begin
- [ ] Sign up at https://www.revenuecat.com
- [ ] Create a project in RevenueCat dashboard
- [ ] Get your API keys (Apple & Google)

## Setup (5 Minutes)

### 1. Update API Keys
```dart
// lib/services/revenue_cat_service.dart
static const String _appleApiKey = 'appl_xxxxx'; // Your key here
static const String _googleApiKey = 'goog_xxxxx'; // Your key here
```

### 2. Enable iOS In-App Purchase
1. Open `ios/Runner.xcworkspace` in Xcode
2. Runner target → Signing & Capabilities
3. Add "In-App Purchase" capability

### 3. Run Setup Script
```bash
./setup_revenuecat.sh
```

Or manually:
```bash
cd ios && pod install && cd ..
flutter clean && flutter pub get
```

## Quick Test

Add to any screen to verify setup:
```dart
ElevatedButton(
  onPressed: () async {
    final offerings = await RevenueCatService().getOfferings();
    print('Offerings: ${offerings?.all.keys}');
  },
  child: Text('Test RevenueCat'),
)
```

## Common Usage

### Check if User Has Premium
```dart
final isPremium = await RevenueCatService().hasActiveEntitlement('premium');
```

### Show Subscription Screen
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (context) => const SubscriptionScreen(),
));
```

### Purchase Flow
```dart
// 1. Get offerings
final offerings = await RevenueCatService().getOfferings();

// 2. Get a package
final package = offerings?.current?.availablePackages.first;

// 3. Purchase
if (package != null) {
  final customerInfo = await RevenueCatService().purchasePackage(package);
  if (customerInfo != null) {
    // Success! Check entitlements
  }
}
```

### Restore Purchases
```dart
await RevenueCatService().restorePurchases();
```

## Configure Products

### RevenueCat Dashboard
1. Go to https://app.revenuecat.com
2. **Products** → Add your App Store/Play Store products
3. **Entitlements** → Create "premium" entitlement
4. **Offerings** → Group products for display

### App Store Connect (iOS)
1. Create in-app purchase products
2. Set pricing and availability
3. Wait for "Ready to Submit" status

### Google Play Console (Android)
1. Create subscription products
2. Set pricing and benefits
3. Activate products

## Testing

### iOS Sandbox
1. App Store Connect → Users and Access → Sandbox Testers
2. Create test account
3. Sign out of real Apple ID on device
4. Test purchase with sandbox account

### Android Testing
1. Google Play Console → Add internal testers
2. Upload app to internal testing
3. Install from Play Store
4. Test with test account

## Files to Know

- `lib/services/revenue_cat_service.dart` - Main service
- `lib/features/subscription/presentation/subscription_screen.dart` - Example UI
- `REVENUECAT_SETUP.md` - Detailed guide
- `INTEGRATION_SUMMARY.md` - What was done

## Next Steps

1. ✅ Integration complete
2. ⬜ Update API keys
3. ⬜ Enable iOS capability
4. ⬜ Configure products in dashboards
5. ⬜ Test with sandbox accounts
6. ⬜ Build your subscription UI
7. ⬜ Launch! 🎉

## Need Help?

- 📖 Full docs: `REVENUECAT_SETUP.md`
- 🌐 RevenueCat: https://www.revenuecat.com/docs
- 💬 Support: support@revenuecat.com
- 📱 Community: https://www.revenuecat.com/slack

---
**Pro Tip**: Start with the example `SubscriptionScreen` and customize it for your brand!
