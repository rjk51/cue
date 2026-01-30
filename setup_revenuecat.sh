#!/bin/bash

# RevenueCat Post-Integration Script
# Run this after completing the RevenueCat setup

echo "🚀 RevenueCat Post-Integration Setup"
echo "===================================="
echo ""

# Check if API keys are set
echo "📝 Checking API keys..."
if grep -q "YOUR_APPLE_API_KEY" lib/services/revenue_cat_service.dart; then
    echo "⚠️  WARNING: Apple API key not set in revenue_cat_service.dart"
    echo "   Please update _appleApiKey in lib/services/revenue_cat_service.dart"
else
    echo "✅ Apple API key appears to be set"
fi

if grep -q "YOUR_GOOGLE_API_KEY" lib/services/revenue_cat_service.dart; then
    echo "⚠️  WARNING: Google API key not set in revenue_cat_service.dart"
    echo "   Please update _googleApiKey in lib/services/revenue_cat_service.dart"
else
    echo "✅ Google API key appears to be set"
fi

echo ""
echo "📱 Installing iOS dependencies..."
cd ios
pod install
cd ..

echo ""
echo "🧹 Cleaning build..."
flutter clean

echo ""
echo "📦 Getting dependencies..."
flutter pub get

echo ""
echo "✅ Setup complete!"
echo ""
echo "⚠️  IMPORTANT NEXT STEPS:"
echo "   1. Update API keys in lib/services/revenue_cat_service.dart"
echo "   2. Open ios/Runner.xcworkspace in Xcode"
echo "   3. Enable In-App Purchase capability"
echo "   4. Configure products in RevenueCat dashboard"
echo "   5. Test with sandbox accounts"
echo ""
echo "📚 See REVENUECAT_SETUP.md for detailed instructions"
