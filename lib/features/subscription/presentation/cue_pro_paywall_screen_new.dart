import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/revenue_cat_service.dart';

/// Simplified Cue Pro Paywall - Features list + Bottom sheet for plans
class CueProPaywallScreen extends StatefulWidget {
  const CueProPaywallScreen({super.key});

  @override
  State<CueProPaywallScreen> createState() => _CueProPaywallScreenState();
}

class _CueProPaywallScreenState extends State<CueProPaywallScreen> {
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show pro badge when user has access
                  if (_isPro)
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 16.h,
                        horizontal: 24.w,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 24.sp,
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'You\'re a Pro member!',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Always offer the option to buy/upgrade (useful during trial)
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _showSubscriptionPlans,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Buy subscription',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _restorePurchases,
            child: Text(
              'Restore',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80.w,
                        height: 80.h,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          color: accentColor,
                          size: 48.sp,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Cue Pro',
                        style: TextStyle(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Unlock all premium features',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40.h),

                // Features List
                _buildFeature(
                  icon: Icons.notifications_active_rounded,
                  title: 'Unlimited Reminders',
                  description: 'Create as many reminders as you need',
                  isDark: isDark,
                ),
                _buildFeature(
                  icon: Icons.repeat_rounded,
                  title: 'Advanced Recurrence',
                  description: 'Set complex recurring patterns',
                  isDark: isDark,
                ),
                _buildFeature(
                  icon: Icons.palette_rounded,
                  title: 'Custom Themes',
                  description: 'Personalize your app appearance',
                  isDark: isDark,
                ),
                _buildFeature(
                  icon: Icons.cloud_sync_rounded,
                  title: 'Cloud Sync',
                  description: 'Sync across all your devices',
                  isDark: isDark,
                ),
                _buildFeature(
                  icon: Icons.attach_file_rounded,
                  title: 'Attachments',
                  description: 'Add photos and files to reminders',
                  isDark: isDark,
                ),
                _buildFeature(
                  icon: Icons.priority_high_rounded,
                  title: 'Priority Support',
                  description: 'Get help when you need it',
                  isDark: isDark,
                ),

                SizedBox(height: 100.h), // Space for button
              ],
            ),
          ),

          // Fixed Bottom Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: _isPro
                  ? Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 16.h,
                        horizontal: 24.w,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 24.sp,
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'You\'re a Pro member!',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _isLoading ? null : _showSubscriptionPlans,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing subscription plans
class _SubscriptionBottomSheet extends StatefulWidget {
  const _SubscriptionBottomSheet();

  @override
  State<_SubscriptionBottomSheet> createState() =>
      _SubscriptionBottomSheetState();
}

class _SubscriptionBottomSheetState extends State<_SubscriptionBottomSheet> {
  bool _isLoading = true;
  Offerings? _offerings;
  Package? _selectedPackage;
  bool _isPurchasing = false;

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
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _isLoading = true);
    try {
      final offerings = await RevenueCatService().getOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          // Pre-select monthly if available, otherwise fallback to first package
          final packages = offerings?.current?.availablePackages ?? [];
          _selectedPackage = packages.firstWhere(
            (pkg) => pkg.packageType == PackageType.monthly,
            orElse: () => packages.isNotEmpty ? packages.first : throw Exception('No packages'),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load plans: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _purchasePackage() async {
    if (_selectedPackage == null || _isPurchasing) return;

    setState(() => _isPurchasing = true);
    try {
      await RevenueCatService().purchasePackage(_selectedPackage!);
      
      if (mounted) {
        setState(() => _isPurchasing = false);
        
        // Close bottom sheet
        Navigator.pop(context);
        
        // Close paywall screen
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Cue Pro!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      padding: EdgeInsets.all(24.w),
      child: _isLoading
          ? SizedBox(
              height: 300.h,
              child: const Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                // Title
                Text(
                  'Choose your plan',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: 16.h),

                // Plans - show only monthly package
                if (_offerings?.current?.availablePackages != null)
                  ...(_offerings!.current!.availablePackages
                      .where((pkg) => pkg.packageType == PackageType.monthly)
                      .map((package) {
                    final isSelected = _selectedPackage == package;
                    final isYearly =
                        package.packageType == PackageType.annual;
                    
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPackage = package),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor.withOpacity(0.1)
                              : (isDark
                                  ? const Color(0xFF1A1A1A)
                                  : const Color(0xFFF5F5F5)),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: isSelected
                                ? accentColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24.w,
                              height: 24.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? accentColor
                                      : (isDark ? Colors.white : Colors.black)
                                          .withOpacity(0.3),
                                  width: 2,
                                ),
                                color: isSelected
                                    ? accentColor
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16.sp,
                                    )
                                  : null,
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        package.storeProduct.title
                                            .replaceAll('(Cue)', '')
                                            .trim(),
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      if (isYearly) ...[
                                        SizedBox(width: 8.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.w,
                                            vertical: 2.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius:
                                                BorderRadius.circular(4.r),
                                          ),
                                          child: Text(
                                            'SAVE 17%',
                                            style: TextStyle(
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    package.storeProduct.priceString ?? '',
                                    style: TextStyle(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold,
                                      color: accentColor,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    _getPackageDescription(package.packageType),
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: (isDark ? Colors.white : Colors.black)
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  })),

                SizedBox(height: 24.h),

                // Subscribe Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPurchasing ? null : _purchasePackage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      elevation: 0,
                    ),
                    child: _isPurchasing
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Subscribe',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Terms and Links
                Text(
                  'Subscription auto-renews unless cancelled. Cancel anytime in Settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.5),
                  ),
                ),

                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () async {
                        const url = 'https://cue-landing-amber.vercel.app/terms';
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open terms')),
                          );
                        }
                      },
                      child: Text(
                        'Terms of Use',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    ),
                    Text(' | ', style: TextStyle(fontSize: 12.sp, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6))),
                    TextButton(
                      onPressed: () async {
                        const url = 'https://cue-landing-amber.vercel.app/#privacy';
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open privacy policy')),
                          );
                        }
                      },
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),
              ],
            ),
    );
  }
}
