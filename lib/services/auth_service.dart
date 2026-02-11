import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../features/notifications/notification_service.dart';
import 'local_storage_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
      final userData = <String, dynamic>{
        'email': email ?? _auth.currentUser?.email,
        'displayName': displayName ?? _auth.currentUser?.displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Only include themePreference if explicitly provided
      if (themePreference != null) {
        userData['themePreference'] = themePreference;
      }

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
          // Don't set themePreference or accentColor - onboarding will handle it
        );
      } else {
        // Returning user: just ensure doc exists
        await _ensureUserDocExists();
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

  // Sign in with Google — works for both login and signup.
  // Firebase handles everything: returns existing user or creates new one.
  Future<GoogleSignInResult> attemptGoogleSignIn() async {
    try {
      // Sign out first to force account picker
      await _googleSignIn.signOut();
      
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return GoogleSignInResult(status: GoogleSignInStatus.cancelled);
      }

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase — creates account if new, signs in if existing
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Validate email
      if (userCredential.user?.email == null || userCredential.user!.email!.isEmpty) {
        await userCredential.user?.delete();
        await _googleSignIn.signOut();
        throw 'Invalid email from Google. Please try again.';
      }
      
      final isNewUser = userCredential.additionalUserInfo?.isNewUser == true;
      
      if (isNewUser) {
        // New user: create basic doc WITHOUT onboarding data
        // OnboardingGate will route them to onboarding screens
        await createUserDocument(
          email: userCredential.user?.email,
          displayName: userCredential.user?.displayName,
        );
      }
      // For returning users: don't touch their data, OnboardingGate checks it
      
      // Register device in background
      _registerDevice();
      
      return GoogleSignInResult(
        status: GoogleSignInStatus.success,
        userCredential: userCredential,
        isNewUser: isNewUser,
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
          // Don't set themePreference or accentColor - onboarding will handle it
        );
      } else {
        // Returning user: just ensure doc exists
        await _ensureUserDocExists();
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
  // isSignUp: true for signup screen, false for login screen
  Future<AppleSignInResult> attemptAppleSignIn() async {
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

      // Sign in to Firebase — creates account if new, signs in if existing
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Validate email
      if (userCredential.user?.email == null || userCredential.user!.email!.isEmpty) {
        await userCredential.user?.delete();
        throw 'Invalid email from Apple. Please try again.';
      }

      // Update display name if available (only on first sign-in)
      if (userCredential.user != null && 
          (userCredential.user!.displayName == null || userCredential.user!.displayName!.isEmpty) &&
          appleCredential.givenName != null && appleCredential.familyName != null) {
        await userCredential.user!.updateDisplayName(
          '${appleCredential.givenName} ${appleCredential.familyName}',
        );
      }

      final isNewUser = userCredential.additionalUserInfo?.isNewUser == true;
      
      if (isNewUser) {
        await createUserDocument(
          email: userCredential.user?.email,
          displayName: userCredential.user?.displayName,
        );
      } else {
        await _ensureUserDocExists();
      }

      _registerDevice();

      return AppleSignInResult(
        status: AppleSignInStatus.success,
        userCredential: userCredential,
        isNewUser: isNewUser,
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
      // Deactivate device before signing out
      await _deactivateDevice();
      
      // Clear local storage/cache
      await _clearLocalData();
      
      // Sign out from Firebase and Google (force disconnect)
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      
      // Disconnect Google account to force account picker on next sign-in
      try {
        await _googleSignIn.disconnect();
      } catch (e) {
        // Ignore disconnect errors (user might not be signed in with Google)
        print('Google disconnect: $e');
      }
    } catch (e) {
      throw 'Failed to sign out. Please try again.';
    }
  }
  
  // Deactivate current device
  Future<void> _deactivateDevice() async {
    try {
      final notificationService = NotificationService();
      final token = notificationService.fcmToken;
      
      if (token != null) {
        await _firestore.collection('devices').doc(token).update({
          'active': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Device deactivated on sign out');
      }
    } catch (e) {
      print('⚠️ Error deactivating device: $e');
      // Don't throw - sign out should continue
    }
  }
  
  // Clear all local data on sign out or account deletion
  Future<void> _clearLocalData() async {
    try {
      final localStorage = LocalStorageService.instance;
      
      // Clear all stored preferences
      await localStorage.remove('theme_preference');
      await localStorage.remove('accent_color');
      await localStorage.remove('font_size_scale');
      await localStorage.remove('background_color');
      await localStorage.remove('text_color');
      await localStorage.remove('device_sync_onboarding_shown');
      await localStorage.remove('notification_sound');
      await localStorage.remove('nudge_message');
      
      print('✅ Local storage cleared');
    } catch (e) {
      print('⚠️ Error clearing local storage: $e');
      // Don't throw - sign out should continue
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
  
  /// Ensure user document exists for returning users.
  /// Does NOT set onboarding data — OnboardingGate handles that.
  Future<void> _ensureUserDocExists() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        // User document somehow missing, recreate basic doc
        await createUserDocument(
          email: _auth.currentUser?.email,
          displayName: _auth.currentUser?.displayName,
        );
      }
    } catch (e) {
      print('Error ensuring user doc exists: $e');
    }
  }
  
  void _registerDevice() {
    // Wait a bit longer for Firebase Auth session to be fully established
    Future.delayed(const Duration(seconds: 1), () async {
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
}

// Result class for Google Sign-In
class GoogleSignInResult {
  final GoogleSignInStatus status;
  final UserCredential? userCredential;
  final bool isNewUser;

  GoogleSignInResult({
    required this.status,
    this.userCredential,
    this.isNewUser = false,
  });
}

// Enum for Apple Sign-In status
enum AppleSignInStatus {
  success,
  cancelled,
}

// Result class for Apple Sign-In
class AppleSignInResult {
  final AppleSignInStatus status;
  final UserCredential? userCredential;
  final bool isNewUser;

  AppleSignInResult({
    required this.status,
    this.userCredential,
    this.isNewUser = false,
  });
}
