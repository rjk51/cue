# 🧪 Testing RevenueCat - Step by Step Guide

## Current Status
✅ RevenueCat SDK integrated  
✅ Pods installed  
✅ API key configured (`test_MpMYAkZJHyTvuynILFqEaRPUJgm`)  
⚠️ Need to configure dashboard and test purchases

---

## Part 1: RevenueCat Dashboard Setup (10 minutes)

### Step 1: Create Products in Dashboard
Go to: https://app.revenuecat.com/projects/cue/products

1. **Click "Add Product"** for each:
   
   **Monthly Product:**
   - Product ID: `monthly`
   - Type: Subscription
   - Platform: iOS & Android

   **Yearly Product:**
   - Product ID: `yearly`
   - Type: Subscription
   - Platform: iOS & Android

   **Lifetime Product:**
   - Product ID: `lifetime`
   - Type: Non-Subscription (one-time purchase)
   - Platform: iOS & Android

### Step 2: Create Entitlement
Go to: https://app.revenuecat.com/projects/cue/entitlements

1. Click **"New Entitlement"**
2. Name: `Cue Pro`
3. Identifier: `Cue Pro` (must match exactly)
4. Add all 3 products (monthly, yearly, lifetime) to this entitlement

### Step 3: Create Offering
Go to: https://app.revenuecat.com/projects/cue/offerings

1. Click **"New Offering"**
2. Identifier: `default`
3. Make it the **current offering**
4. Add 3 packages:
   - **Monthly Package**: Product → monthly
   - **Annual Package**: Product → yearly
   - **Lifetime Package**: Product → lifetime

### Step 4: Configure Paywall (Optional for native UI)
Go to: https://app.revenuecat.com/projects/cue/paywalls

1. Create a new paywall template
2. Link it to the "default" offering
3. Customize the design (colors, text, images)
4. Save and publish

---

## Part 2: App Store Connect Setup (5 minutes)

### Configure In-App Purchases
Go to: https://appstoreconnect.apple.com

1. Select your app (Cue)
2. Go to **"In-App Purchases"**
3. Create 3 products (if not already created):

   **Monthly Subscription:**
   - Product ID: `monthly`
   - Type: Auto-Renewable Subscription
   - Subscription Group: Create "Cue Pro" group
   - Price: Your chosen price
   - Subscription Duration: 1 month

   **Yearly Subscription:**
   - Product ID: `yearly`
   - Same group as monthly
   - Price: Your chosen price
   - Subscription Duration: 1 year

   **Lifetime Purchase:**
   - Product ID: `lifetime`
   - Type: Non-Consumable
   - Price: Your chosen price

4. **Important**: Add at least 1 screenshot for each product
5. Submit for review (can test before approval)

---

## Part 3: iOS Sandbox Testing (Main Testing)

### Step 1: Create Sandbox Test Account
Go to: https://appstoreconnect.apple.com/access/testers

1. Click **"Sandbox Testers"**
2. Click **"+"** to add tester
3. Fill in details:
   - Email: Create a NEW email (doesn't need to be real)
   - Password: Create strong password
   - First/Last Name: Test User
   - Country: Your country
4. Save and remember this email/password!

### Step 2: Configure Your iPhone
On your test iPhone:

1. **Sign OUT of regular App Store:**
   - Settings → [Your Name] → Media & Purchases → Sign Out
   
2. **DO NOT sign in with sandbox account yet**
   - The app will prompt you when making a purchase

3. **Clear existing data (optional):**
   - Settings → General → iPhone Storage → Cue → Delete App
   - Reinstall from Xcode

### Step 3: Run the App from Xcode

```bash
# In your terminal
cd /Users/user91/Desktop/Work/cue
flutter run --release
# OR
flutter build ios && open ios/Runner.xcworkspace
# Then run from Xcode
```

### Step 4: Test the Paywall

**In your app:**

1. **Navigate to paywall screen**
   ```dart
   // Add a button somewhere in your app (e.g., settings):
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => CueProPaywallScreen(),
     ),
   );
   ```

2. **View the paywall:**
   - Should see your 3 products (monthly, yearly, lifetime)
   - Prices should display correctly
   - See RevenueCat native UI (if configured)

3. **Make a test purchase:**
   - Tap on any product (e.g., "Monthly")
   - iOS will prompt: "Sign in to use Sandbox Environment"
   - Enter your **sandbox test email/password**
   - Approve the purchase (it's free in sandbox!)
   
4. **Check the result:**
   - App should show success
   - Check if `hasCueProAccess()` returns `true`
   - Premium features should unlock

### Step 5: Verify in Dashboard
Go back to: https://app.revenuecat.com/customers

- Should now see 1 customer in Sandbox
- Click on customer to see:
  - Active entitlements
  - Purchase history
  - Subscription status

---

## Part 4: Quick Code Tests

### Test 1: Check Pro Access
Add this to any screen:

```dart
FloatingActionButton(
  onPressed: () async {
    final hasPro = await RevenueCatService().hasCueProAccess();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Has Pro: $hasPro')),
    );
  },
  child: Icon(Icons.check),
)
```

### Test 2: Show Offerings
```dart
FloatingActionButton(
  onPressed: () async {
    final offerings = await RevenueCatService().getOfferings();
    print('Current offering: ${offerings?.current?.identifier}');
    print('Packages: ${offerings?.current?.availablePackages.length}');
  },
  child: Icon(Icons.list),
)
```

### Test 3: Check Customer Info
```dart
FloatingActionButton(
  onPressed: () async {
    final info = await RevenueCatService().getCustomerInfo();
    print('Active entitlements: ${info?.entitlements.active.keys}');
  },
  child: Icon(Icons.person),
)
```

---

## Part 5: Testing Scenarios

### ✅ Scenario 1: Fresh Install Purchase
1. Delete app from device
2. Reinstall via Xcode
3. Open paywall
4. Purchase monthly subscription
5. Verify `hasCueProAccess()` returns true
6. Check premium features work

### ✅ Scenario 2: Restore Purchases
1. Delete app from device
2. Reinstall via Xcode
3. Don't purchase anything
4. Tap "Restore Purchases" button
5. Should restore previous subscription
6. Verify access is restored

### ✅ Scenario 3: Customer Center
1. Navigate to Customer Center screen:
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => CustomerCenterScreen(),
     ),
   );
   ```
2. View subscription status
3. Test "Manage Subscription" button
4. Should open iOS subscription management

### ✅ Scenario 4: Feature Gating
1. Wrap a feature with `CueProGate`:
   ```dart
   CueProGate(
     child: Text('Premium Feature!'),
   )
   ```
2. Without subscription: Should show upgrade prompt
3. After purchase: Should show premium content

---

## Part 6: Add Test Buttons to Your App

Add this to your home screen or settings temporarily:

```dart
// lib/features/home/presentation/home_screen.dart
// Add to your build method:

Column(
  children: [
    // Existing UI...
    
    // TEST BUTTONS (Remove in production!)
    if (kDebugMode) ...[
      ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CueProPaywallScreen(),
            ),
          );
        },
        child: Text('🧪 Test Paywall'),
      ),
      ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerCenterScreen(),
            ),
          );
        },
        child: Text('🧪 Test Customer Center'),
      ),
      ElevatedButton(
        onPressed: () async {
          final hasPro = await RevenueCatService().hasCueProAccess();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasPro ? '✅ Has Cue Pro Access' : '❌ No Access',
              ),
            ),
          );
        },
        child: Text('🧪 Check Access'),
      ),
    ],
  ],
)
```

---

## Common Testing Issues & Solutions

### Issue: "No offerings available"
**Cause**: Products not configured in RevenueCat dashboard  
**Fix**: 
1. Complete Part 1 above (create products, entitlement, offering)
2. Wait 5-10 minutes for sync
3. Force close app and reopen

### Issue: "Sandbox login doesn't work"
**Cause**: Already signed into production App Store  
**Fix**:
1. Settings → Media & Purchases → Sign Out
2. DON'T sign back in
3. Let the app prompt you during purchase

### Issue: "Purchase button does nothing"
**Cause**: Products not in App Store Connect  
**Fix**:
1. Complete Part 2 above
2. Ensure product IDs match exactly: `monthly`, `yearly`, `lifetime`
3. Wait for App Store Connect to sync (~30 min)

### Issue: "Can't see purchase in RevenueCat dashboard"
**Cause**: Looking at Production instead of Sandbox  
**Fix**:
1. Make sure you're on the "Sandbox" tab
2. Filter by "Made Sandbox Purchase"
3. Refresh the page

### Issue: "Invalid Product IDs"
**Cause**: Mismatch between code, RevenueCat, and App Store Connect  
**Fix**: Verify all 3 places use exact same IDs:
- Code: `lib/services/revenue_cat_service.dart`
- RevenueCat: Products page
- App Store Connect: In-App Purchases page

---

## Expected Results After Testing

✅ **You should see:**
- Paywall displays with 3 products
- Prices show correctly
- Can complete purchase with sandbox account
- `hasCueProAccess()` returns `true` after purchase
- Customer appears in RevenueCat dashboard (Sandbox tab)
- Restore purchases works
- Customer Center shows subscription status
- Feature gating works (premium content shows after purchase)

---

## Next Steps After Successful Testing

1. ✅ Test all scenarios above
2. ✅ Verify dashboard shows customers
3. ✅ Test on multiple devices
4. ✅ Test Android (similar process with Google Play Console)
5. ⚠️ Replace test API key with production key
6. ⚠️ Submit app for review
7. ⚠️ Test with TestFlight before production release

---

## Quick Start: Minimum Test

**Don't want to read everything? Do this:**

1. **Dashboard** (https://app.revenuecat.com):
   - Create 3 products: `monthly`, `yearly`, `lifetime`
   - Create entitlement: `Cue Pro`
   - Create offering: `default` with all 3 products

2. **App Store Connect**:
   - Create same 3 products
   - Create sandbox test account

3. **iPhone**:
   - Sign out of App Store (Settings → Media & Purchases)
   - Run app from Xcode

4. **In App**:
   - Add test button that opens `CueProPaywallScreen()`
   - Tap product → Sign in with sandbox account → Purchase
   - Check if premium features unlock

5. **Verify**:
   - Check RevenueCat dashboard (Sandbox tab)
   - Should see 1 customer with active subscription

---

## 🆘 Need Help?

**RevenueCat Support:**
- Docs: https://www.revenuecat.com/docs
- Community: https://www.revenuecat.com/slack
- Email: support@revenuecat.com

**Debug Logs:**
Add this to see RevenueCat logs:
```dart
// In main.dart initialization
await Purchases.setLogLevel(LogLevel.debug);
```

---

**Ready to test! Start with Part 1 (Dashboard Setup) and work your way down.** 🚀
