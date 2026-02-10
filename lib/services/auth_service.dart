import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../features/notifications/notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if email already exists and get auth methods
  Future<List<String>> getAuthMethodsForEmail(String email) async {
    try {
      return await _auth.fetchSignInMethodsForEmail(email);
    } catch (e) {
      return [];
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _registerDevice();
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await credential.user?.updateDisplayName(fullName);
      
      // Create user document in Firestore
      await createUserDocument(
        email: email,
        displayName: fullName,
      );
      
      _registerDevice();
      
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Create or update user document in Firestore.
  ///
  /// Called after user signup to initialize their document.
  Future<void> createUserDocument({
    String? email,
    String? displayName,
    String? themePreference,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final userData = {
        'email': email ?? _auth.currentUser?.email,
        'displayName': displayName ?? _auth.currentUser?.displayName,
        'themePreference': themePreference ?? 'light',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).set(
            userData,
            SetOptions(merge: true),
          );
    } catch (e) {
      print('Error creating user document: $e');
      // Don't throw - user can still use the app
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Create user document if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await createUserDocument(
          email: userCredential.user?.email,
          displayName: userCredential.user?.displayName,
          themePreference: 'light',
        );
        // Set default accent color for new users
        await _setDefaultAccentColorIfNeeded();
      } else {
        // For returning users, ensure they have onboarding data
        await _ensureOnboardingDataExists();
      }
      
      _registerDevice();

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Sign out from Google if there was an error
      await _googleSignIn.signOut();
      throw _handleAuthException(e);
    } catch (e) {
      await _googleSignIn.signOut();
      throw 'Google Sign-In failed. Please try again.';
    }
  }

  // Attempt Google sign-in and check for account conflicts
  Future<GoogleSignInResult> attemptGoogleSignIn() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        return GoogleSignInResult(status: GoogleSignInStatus.cancelled);
      }

      final email = googleUser.email;

      // Check if an account already exists with this email
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
      
      if (signInMethods.isNotEmpty && !signInMethods.contains('google.com')) {
        // Account exists with different provider (e.g., email/password)
        // Sign out from Google for now
        await _googleSignIn.signOut();
        return GoogleSignInResult(
          status: GoogleSignInStatus.needsLinking,
          email: email,
          existingProviders: signInMethods,
        );
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      // This will either sign in existing user or create new account
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Create user document if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await createUserDocument(
          email: userCredential.user?.email,
          displayName: userCredential.user?.displayName,
          themePreference: 'light',
        );
        // Set default accent color for new users
        await _setDefaultAccentColorIfNeeded();
      } else {
        // For returning users, ensure they have onboarding data
        await _ensureOnboardingDataExists();
      }
      
      return GoogleSignInResult(
        status: GoogleSignInStatus.success,
        userCredential: userCredential,
        isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
      );
    } on FirebaseAuthException catch (e) {
      await _googleSignIn.signOut();
      throw _handleAuthException(e);
    } catch (e) {
      await _googleSignIn.signOut();
      throw 'Google Sign-In failed. Please try again.';
    }
  }

  // Link Google account to existing user (requires password verification)
  Future<UserCredential> linkGoogleToExistingAccount({
    required String email,
    required String password,
  }) async {
    try {
      // First, verify the password
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get Google credentials
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw 'Google Sign-In was canceled.';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final googleCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Link the Google credential to the existing user
      final linkedCredential = await credential.user!.linkWithCredential(googleCredential);
      
      return linkedCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        throw 'Google account is already linked to this account.';
      } else if (e.code == 'credential-already-in-use') {
        throw 'This Google account is already linked to another user.';
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to link Google account. Please try again.';
    }
  }

  // Check if user has Google provider linked
  bool hasGoogleProvider(User user) {
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  // Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
    try {
      // Request credential for the currently signed in Apple account
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create an OAuthCredential from the credential returned by Apple
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with the Apple credential
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Update display name if available (only on first sign-in)
      if (userCredential.user != null && 
          (userCredential.user!.displayName == null || userCredential.user!.displayName!.isEmpty) &&
          appleCredential.givenName != null && appleCredential.familyName != null) {
        await userCredential.user!.updateDisplayName(
          '${appleCredential.givenName} ${appleCredential.familyName}',
        );
      }

      // Create user document if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await createUserDocument(
          email: userCredential.user?.email,
          displayName: userCredential.user?.displayName,
          themePreference: 'light',
        );
        // Set default accent color for new users
        await _setDefaultAccentColorIfNeeded();
      } else {
        // For returning users, ensure they have onboarding data
        await _ensureOnboardingDataExists();
      }
      
      _registerDevice();

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // User canceled the sign-in
        return null;
      }
      throw 'Apple Sign-In failed. Please try again.';
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Apple Sign-In failed. Please try again.';
    }
  }

  // Attempt Apple sign-in and check for account conflicts
  Future<AppleSignInResult> attemptAppleSignIn() async {
    try {
      // Request credential for the currently signed in Apple account
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Check if an account already exists with this email
      if (appleCredential.email != null) {
        final signInMethods = await _auth.fetchSignInMethodsForEmail(appleCredential.email!);
        
        if (signInMethods.isNotEmpty && !signInMethods.contains('apple.com')) {
          // Account exists with different provider (e.g., email/password, Google)
          return AppleSignInResult(
            status: AppleSignInStatus.needsLinking,
            email: appleCredential.email!,
            existingProviders: signInMethods,
            appleCredential: appleCredential,
          );
        }
      }

      // Create an OAuthCredential from the credential returned by Apple
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with the Apple credential
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Update display name if available (only on first sign-in)
      if (userCredential.user != null && 
          (userCredential.user!.displayName == null || userCredential.user!.displayName!.isEmpty) &&
          appleCredential.givenName != null && appleCredential.familyName != null) {
        await userCredential.user!.updateDisplayName(
          '${appleCredential.givenName} ${appleCredential.familyName}',
        );
      }

      // Create user document if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await createUserDocument(
          email: userCredential.user?.email,
          displayName: userCredential.user?.displayName,
          themePreference: 'light',
        );
        // Set default accent color for new users
        await _setDefaultAccentColorIfNeeded();
      } else {
        // For returning users, ensure they have onboarding data
        await _ensureOnboardingDataExists();
      }

      return AppleSignInResult(
        status: AppleSignInStatus.success,
        userCredential: userCredential,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AppleSignInResult(status: AppleSignInStatus.cancelled);
      }
      throw 'Apple Sign-In failed. Please try again.';
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Apple Sign-In failed. Please try again.';
    }
  }

  // Link Apple account to existing user
  Future<UserCredential> linkAppleToExistingAccount({
    required String email,
    required String password,
    required AuthorizationCredentialAppleID appleCredential,
  }) async {
    try {
      // First, verify the password
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create OAuth credential from Apple
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Link the Apple credential to the existing user
      final linkedCredential = await credential.user!.linkWithCredential(oauthCredential);
      
      return linkedCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        throw 'Apple account is already linked to this account.';
      } else if (e.code == 'credential-already-in-use') {
        throw 'This Apple account is already linked to another user.';
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to link Apple account. Please try again.';
    }
  }

  // Check if user has Apple provider linked
  bool hasAppleProvider(User user) {
    return user.providerData.any((info) => info.providerId == 'apple.com');
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw 'Failed to sign out. Please try again.';
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
  
  /// Set default accent color if not already set.
  /// Used for new users during Google/Apple sign-in.
  Future<void> _setDefaultAccentColorIfNeeded() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()?['accentColor'] == null) {
        // Set default coral color (#FFB4A3) = 0xFFFFB4A3
        await _firestore.collection('users').doc(userId).update({
          'accentColor': 0xFFFFB4A3,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error setting default accent color: $e');
      // Don't throw - this is optional
    }
  }

  /// Ensure returning users have onboarding data.
  /// For existing Google/Apple users who may have incomplete onboarding.
  Future<void> _ensureOnboardingDataExists() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        final hasTheme = data?['themePreference'] != null;
        final hasColor = data?['accentColor'] != null;
        
        // If user doesn't have complete onboarding data, set defaults
        if (!hasTheme || !hasColor) {
          final updates = <String, dynamic>{
            'updatedAt': FieldValue.serverTimestamp(),
          };
          
          if (!hasTheme) {
            updates['themePreference'] = 'light';
          }
          
          if (!hasColor) {
            // Set default coral color (#FFB4A3) = 0xFFFFB4A3
            updates['accentColor'] = 0xFFFFB4A3;
          }
          
          await _firestore.collection('users').doc(userId).update(updates);
          print('✅ Set default onboarding data for returning user');
        }
      } else {
        // User document doesn't exist, create it with defaults
        await createUserDocument(
          email: _auth.currentUser?.email,
          displayName: _auth.currentUser?.displayName,
          themePreference: 'light',
        );
        await _setDefaultAccentColorIfNeeded();
      }
    } catch (e) {
      print('Error ensuring onboarding data: $e');
      // Don't throw - user can still use the app
    }
  }
  
  void _registerDevice() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        final notificationService = NotificationService();
        await notificationService.ensureDeviceRegistered();
        print('✅ Device registered after login');
      } catch (e) {
        print('❌ Error registering device: $e');
      }
    });
  }
}

// Enum for Google Sign-In status
enum GoogleSignInStatus {
  success,
  cancelled,
  needsLinking,
}

// Result class for Google Sign-In
class GoogleSignInResult {
  final GoogleSignInStatus status;
  final UserCredential? userCredential;
  final String? email;
  final List<String>? existingProviders;
  final bool isNewUser;

  GoogleSignInResult({
    required this.status,
    this.userCredential,
    this.email,
    this.existingProviders,
    this.isNewUser = false,
  });
}

// Enum for Apple Sign-In status
enum AppleSignInStatus {
  success,
  cancelled,
  needsLinking,
}

// Result class for Apple Sign-In
class AppleSignInResult {
  final AppleSignInStatus status;
  final UserCredential? userCredential;
  final String? email;
  final List<String>? existingProviders;
  final AuthorizationCredentialAppleID? appleCredential;

  AppleSignInResult({
    required this.status,
    this.userCredential,
    this.email,
    this.existingProviders,
    this.appleCredential,
  });
}
