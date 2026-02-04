import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/revenue_cat_service.dart';
import '../../../services/theme_service.dart';

class CueProPaywallScreen extends StatefulWidget {
  const CueProPaywallScreen({super.key});

  @override
  State<CueProPaywallScreen> createState() => _CueProPaywallScreenState();
}

class _CueProPaywallScreenState extends State<CueProPaywallScreen> {
  final ThemeService _themeService = ThemeService();
  
  bool _isLoading = true;
  bool _isPro = false;
  bool _isDarkMode = false;
  Color _accentColor = const Color(0xFF2D7A78);
  Offerings? _offerings;
  Package? _selectedPackage;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initialize();
  }

  Future<void> _loadTheme() async {
    final themePreference = await _themeService.getThemePreference();
    final accentColor = await _themeService.getAccentColor();

    if (mounted) {
      setState(() {
        _accentColor = accentColor;
        if (themePreference == 'system') {
          _isDarkMode =
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
        } else {
          _isDarkMode = themePreference == 'dark';
        }
      });
    }
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      final isPro = await RevenueCatService().hasCueProAccess();
      final offerings = await RevenueCatService().getOfferings();
      
      if (mounted) {
        setState(() {
          _isPro = isPro;
          _offerings = offerings;
          // Pre-select annual package as default
          _selectedPackage = offerings?.current?.availablePackages
              .firstWhere(
                (p) => p.packageType == PackageType.annual,
                orElse: () => offerings.current!.availablePackages.first,
              );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load: $e');
      }
    }
  }

  Future<void> _purchasePackage() async {
    if (_selectedPackage == null) return;

    setState(() => _isPurchasing = true);
    try {
      final customerInfo = await RevenueCatService().purchasePackage(_selectedPackage!);
      
      if (mounted) {
        if (customerInfo?.entitlements.active.containsKey('Cue Pro') ?? false) {
          _showSuccess('Welcome to Cue Pro!');
          Navigator.pop(context, true);
        } else {
          setState(() => _isPurchasing = false);
          _showError('Purchase completed but subscription not active');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        _showError('Purchase failed: $e');
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isPurchasing = true);
    try {
      final result = await RevenueCatService().restorePurchases();
      if (mounted) {
        setState(() => _isPurchasing = false);
        if (result != null && result.entitlements.active.isNotEmpty) {
          _showSuccess('Purchases restored!');
          Navigator.pop(context, true);
        } else {
          _showError('No purchases to restore');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        _showError('Restore failed: $e');
      }
    }
  }

  Future<void> _manageSubscription() async {
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      _showError('Failed to open subscription management: $e');
    }
  }


  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getPackageLabel(PackageType type) {
    switch (type) {
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.annual:
        return 'Yearly';
      case PackageType.lifetime:
        return 'Lifetime';
      default:
        return 'Subscription';
    }
  }

  String _getPackageDescription(PackageType type) {
    switch (type) {
      case PackageType.monthly:
        return 'Billed monthly • Cancel anytime';
      case PackageType.annual:
        return 'Billed annually • Cancel anytime';
      case PackageType.lifetime:
        return 'One-time purchase • Lifetime access';
      default:
        return 'Auto-renewing subscription';
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final cardColor = _isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF2D2D2D);
    final secondaryTextColor = _isDarkMode ? Colors.white70 : const Color(0xFF666666);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isPro)
            TextButton(
              onPressed: _manageSubscription,
              child: Text(
                'Manage',
                style: TextStyle(color: _accentColor),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
              ),
            )
          : _isPro
              ? _buildProStatusView(cardColor, textColor, secondaryTextColor)
              : _buildSubscribeView(cardColor, textColor, secondaryTextColor),
    );
  }

  Widget _buildProStatusView(Color cardColor, Color textColor, Color secondaryTextColor) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_rounded,
                size: 80.w,
                color: _accentColor,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'You\'re a Pro!',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'You have access to all premium features',
              style: TextStyle(
                fontSize: 16.sp,
                color: secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _manageSubscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Manage Subscription',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: _restorePurchases,
              child: Text(
                'Restore Purchases',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: _accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribeView(Color cardColor, Color textColor, Color secondaryTextColor) {
    if (_offerings?.current == null) {
      return _buildNoOfferingsView(cardColor, textColor, secondaryTextColor);
    }

    final packages = _offerings!.current!.availablePackages;
    
    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            children: [
              Icon(
                Icons.star_rounded,
                size: 48.w,
                color: _accentColor,
              ),
              SizedBox(height: 12.h),
              Text(
                'Upgrade to Pro',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Unlock unlimited reminders, advanced recurrence,\ncloud sync, and more',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Plans
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: packages.map((package) {
                final isSelected = _selectedPackage?.identifier == package.identifier;
                final isPopular = package.packageType == PackageType.annual;
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedPackage = package),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isSelected ? _accentColor : cardColor,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSelected ? _accentColor : (_isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0)),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Radio
                        Container(
                          width: 24.w,
                          height: 24.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.white : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? Colors.white : secondaryTextColor,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 12.w,
                                    height: 12.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _accentColor,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(width: 12.w),
                        // Package info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _getPackageLabel(package.packageType),
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : textColor,
                                    ),
                                  ),
                                  if (isPopular) ...[
                                    SizedBox(width: 8.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 2.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white : _accentColor,
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                      child: Text(
                                        'BEST VALUE',
                                        style: TextStyle(
                                          color: isSelected ? _accentColor : Colors.white,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                _getPackageDescription(package.packageType),
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: isSelected ? Colors.white.withOpacity(0.9) : secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Price
                        Text(
                          package.storeProduct.priceString,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Bottom CTA
        Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: _isPurchasing ? null : _purchasePackage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _accentColor.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: _isPurchasing
                      ? SizedBox(
                          width: 24.w,
                          height: 24.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Subscribe',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: _restorePurchases,
                  child: Text(
                    'Restore Purchases',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: _accentColor,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                // Selected package summary + auto-renew disclosure
                if (_selectedPackage != null) ...[
                  SizedBox(height: 6.h),
                  Text(
                    '${_getPackageLabel(_selectedPackage!.packageType)} — ${_selectedPackage!.storeProduct.priceString}\nSubscription automatically renews and will be charged to your Apple ID.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: secondaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: 8.h),
                // Terms and Privacy Links
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () async {
                        const url = 'https://cue-landing-amber.vercel.app/#terms-of-use'; // Replace with your actual terms URL
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          _showError('Could not open terms of use');
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Terms of Use',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: secondaryTextColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      ' | ',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: secondaryTextColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        const url = 'https://cue-landing-amber.vercel.app/#privacy'; // Replace with your actual privacy policy URL
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          _showError('Could not open privacy policy');
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: secondaryTextColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  'Cancel anytime from subscription settings',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoOfferingsView(Color cardColor, Color textColor, Color secondaryTextColor) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.w,
              color: secondaryTextColor,
            ),
            SizedBox(height: 16.h),
            Text(
              'No plans available',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Please check your connection and try again',
              style: TextStyle(
                fontSize: 14.sp,
                color: secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: _initialize,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
