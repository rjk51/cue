import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing tutorial state and progression
class TutorialService {
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Tutorial flags
  static const String tutorialCompletedKey = 'tutorialCompleted';
  static const String homeFabShownKey = 'homeFabTutorialShown';
  static const String homeCueCardShownKey = 'homeCueCardTutorialShown';
  static const String homeSnoozeShownKey = 'homeSnoozeTutorialShown';
  static const String homeDoneShownKey = 'homeDoneTutorialShown';
  static const String homeNotesShownKey = 'homeNotesTutorialShown';
  static const String homeFlipShownKey = 'homeFlipTutorialShown';
  static const String createRepeatShownKey = 'createRepeatTutorialShown';
  static const String createAutoSnoozeShownKey =
      'createAutoSnoozeTutorialShown';

  /// Get tutorial state for the current user
  Future<Map<String, bool>> getTutorialState() async {
    final userId = _userId;
    if (userId == null) {
      return _getDefaultTutorialState();
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return _getDefaultTutorialState();
      }

      final data = doc.data();
      if (data == null) {
        return _getDefaultTutorialState();
      }

      // Extract tutorial flags, defaulting to false if not present
      return {
        tutorialCompletedKey: data[tutorialCompletedKey] ?? false,
        homeFabShownKey: data[homeFabShownKey] ?? false,
        homeCueCardShownKey: data[homeCueCardShownKey] ?? false,
        homeSnoozeShownKey: data[homeSnoozeShownKey] ?? false,
        homeDoneShownKey: data[homeDoneShownKey] ?? false,
        homeNotesShownKey: data[homeNotesShownKey] ?? false,
        homeFlipShownKey: data[homeFlipShownKey] ?? false,
        createRepeatShownKey: data[createRepeatShownKey] ?? false,
        createAutoSnoozeShownKey: data[createAutoSnoozeShownKey] ?? false,
      };
    } catch (e) {
      print('Error getting tutorial state: $e');
      return _getDefaultTutorialState();
    }
  }

  /// Get specific tutorial flag value
  Future<bool> getTutorialFlag(String key) async {
    final state = await getTutorialState();
    return state[key] ?? false;
  }

  /// Mark a tutorial step as shown
  Future<void> markTutorialShown(String key) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        key: true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error marking tutorial shown: $e');
    }
  }

  /// Mark multiple tutorial steps as shown
  Future<void> markMultipleTutorialsShown(List<String> keys) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      for (final key in keys) {
        updateData[key] = true;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .set(updateData, SetOptions(merge: true));
    } catch (e) {
      print('Error marking tutorials shown: $e');
    }
  }

  /// Mark the entire tutorial as completed
  Future<void> completeTutorial() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        tutorialCompletedKey: true,
        homeFabShownKey: true,
        homeCueCardShownKey: true,
        homeSnoozeShownKey: true,
        homeDoneShownKey: true,
        homeNotesShownKey: true,
        homeFlipShownKey: true,
        createRepeatShownKey: true,
        createAutoSnoozeShownKey: true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error completing tutorial: $e');
    }
  }

  /// Reset tutorial state (for testing or user-requested reset)
  Future<void> resetTutorial() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        tutorialCompletedKey: false,
        homeFabShownKey: false,
        homeCueCardShownKey: false,
        homeSnoozeShownKey: false,
        homeDoneShownKey: false,
        homeNotesShownKey: false,
        homeFlipShownKey: false,
        createRepeatShownKey: false,
        createAutoSnoozeShownKey: false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error resetting tutorial: $e');
    }
  }

  /// Check if user should see the initial FAB tutorial
  Future<bool> shouldShowFabTutorial() async {
    final state = await getTutorialState();
    return !(state[homeFabShownKey] ?? false);
  }

  /// Check if user should see cue card tutorial (after first reminder created)
  Future<bool> shouldShowCueCardTutorial() async {
    final state = await getTutorialState();
    return (state[homeFabShownKey] ?? false) &&
        !(state[homeCueCardShownKey] ?? false);
  }

  /// Check if user should see create reminder screen tutorials
  Future<bool> shouldShowCreateReminderTutorials() async {
    final state = await getTutorialState();
    return !(state[createRepeatShownKey] ?? false) ||
        !(state[createAutoSnoozeShownKey] ?? false);
  }

  Map<String, bool> _getDefaultTutorialState() {
    return {
      tutorialCompletedKey: false,
      homeFabShownKey: false,
      homeCueCardShownKey: false,
      homeSnoozeShownKey: false,
      homeDoneShownKey: false,
      homeNotesShownKey: false,
      homeFlipShownKey: false,
      createRepeatShownKey: false,
      createAutoSnoozeShownKey: false,
    };
  }

  /// Stream tutorial state changes
  Stream<Map<String, bool>> watchTutorialState() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value(_getDefaultTutorialState());
    }

    return _firestore.collection('users').doc(userId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) {
        return _getDefaultTutorialState();
      }

      final data = snapshot.data();
      if (data == null) {
        return _getDefaultTutorialState();
      }

      return {
        tutorialCompletedKey: data[tutorialCompletedKey] ?? false,
        homeFabShownKey: data[homeFabShownKey] ?? false,
        homeCueCardShownKey: data[homeCueCardShownKey] ?? false,
        homeSnoozeShownKey: data[homeSnoozeShownKey] ?? false,
        homeDoneShownKey: data[homeDoneShownKey] ?? false,
        homeNotesShownKey: data[homeNotesShownKey] ?? false,
        homeFlipShownKey: data[homeFlipShownKey] ?? false,
        createRepeatShownKey: data[createRepeatShownKey] ?? false,
        createAutoSnoozeShownKey: data[createAutoSnoozeShownKey] ?? false,
      };
    });
  }
}
