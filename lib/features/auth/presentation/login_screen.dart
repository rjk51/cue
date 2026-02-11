import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/auth_service.dart';
import '../../../services/local_storage_service.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../home/presentation/home_screen.dart';
import '../../onboarding/presentation/device_sync_onboarding_screen.dart';
import 'signup_screen.dart';
import 'link_account_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _storage = LocalStorageService.instance;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterLogin() async {
    if (!mounted) return;

    // Check if device sync onboarding has been shown
    final hasShownSync = _storage.get<bool>('device_sync_onboarding_shown') ?? false;

    if (!hasShownSync) {
      // Show device sync onboarding first
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const DeviceSyncOnboardingScreen(),
        ),
      );
      // Mark as shown
      await _storage.set('device_sync_onboarding_shown', true);
    }

    // Navigate to home
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        await _navigateAfterLogin();
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // Login screen: isSignUp = false (don't create new accounts)
      final result = await _authService.attemptGoogleSignIn(isSignUp: false);
      
      if (result.status == GoogleSignInStatus.cancelled) {
        // User canceled
        setState(() => _isLoading = false);
        return;
      }
      
      if (result.status == GoogleSignInStatus.accountNotFound) {
        // No account exists, redirect to signup
        setState(() => _isLoading = false);
        if (mounted) {
          context.showErrorSnackbar('No account found. Please sign up first.');
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SignupScreen()),
          );
        }
        return;
      }

      if (result.status == GoogleSignInStatus.needsLinking) {
        // Account exists with email/password, need to link
        setState(() => _isLoading = false);
        
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => LinkAccountDialog(
              email: result.email!,
              onSuccess: () async {
                // Let authStateChanges StreamBuilder handle navigation
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close login screen
              },
            ),
          );
        }
        return;
      }

      // Successfully signed in with Google (existing user)
      if (mounted) {
        await _navigateAfterLogin();
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // Login screen: isSignUp = false (don't create new accounts)
      final result = await _authService.attemptAppleSignIn(isSignUp: false);
      
      if (result.status == AppleSignInStatus.cancelled) {
        // User canceled
        setState(() => _isLoading = false);
        return;
      }
      
      if (result.status == AppleSignInStatus.accountNotFound) {
        // No account exists, redirect to signup
        setState(() => _isLoading = false);
        if (mounted) {
          context.showErrorSnackbar('No account found. Please sign up first.');
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SignupScreen()),
          );
        }
        return;
      }

      if (result.status == AppleSignInStatus.needsLinking) {
        // Account exists with email/password, need to link
        setState(() => _isLoading = false);
        
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => LinkAccountDialog(
              email: result.email!,
              appleCredential: result.appleCredential,
              onSuccess: () async {
                // Let authStateChanges StreamBuilder handle navigation
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close login screen
              },
            ),
          );
        }
        return;
      }

      // Successfully signed in with Apple (existing user)
      if (mounted) {
        await _navigateAfterLogin();
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.r),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Title
                Text(
                  'Welcome back.',
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Sign in to continue to your space.',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
                SizedBox(height: 48.h),
                // Email field
                Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'jane@cue.app',
                    hintStyle: TextStyle(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[200]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[200]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFFFB4A3),
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Password field
                Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[200]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[200]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFFFB4A3),
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 48),
                // Sign In button
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB4A3),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      disabledBackgroundColor: const Color(0xFFFFB4A3).withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.r),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20.h,
                            width: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Icon(Icons.arrow_forward, size: 20.sp),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: 32.h),
                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.grey[300],
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Text(
                        'or',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.grey[300],
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32.h),
                // Social sign in buttons
                if (_isIOS) ...[
                  // Apple sign in (iOS only)
                  SizedBox(
                    width: double.infinity,
                    height: 56.h,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _handleAppleSignIn,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 20.w,
                            height: 20.h,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: FaIcon(
                              FontAwesomeIcons.apple,
                              size: 18.sp,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'Sign in with Apple',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // Google sign in (iOS)
                  SizedBox(
                    width: double.infinity,
                    height: 56.h,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 20.w,
                            height: 20.h,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: FaIcon(
                              FontAwesomeIcons.google,
                              size: 18.sp,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'Sign in with Google',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  // Google sign in (Android/web)
                  SizedBox(
                    width: double.infinity,
                    height: 56.h,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 20.w,
                            height: 20.h,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: FaIcon(
                              FontAwesomeIcons.google,
                              size: 18.sp,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'Sign in with Google',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 32.h),
                // Sign up link
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SignupScreen()),
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.black.withOpacity(0.6),
                        ),
                        children: const [
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
