import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
      
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
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
      return await _auth.signInWithCredential(credential);
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
      final userCredential = await _auth.signInWithCredential(credential);
      
      return GoogleSignInResult(
        status: GoogleSignInStatus.success,
        userCredential: userCredential,
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

  GoogleSignInResult({
    required this.status,
    this.userCredential,
    this.email,
    this.existingProviders,
  });
}
