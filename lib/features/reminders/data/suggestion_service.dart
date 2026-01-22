import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/suggestion_model.dart';

class SuggestionService {
  static final SuggestionService _instance = SuggestionService._internal();
  factory SuggestionService() => _instance;
  SuggestionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'suggestions';
  final String _userId = 'demo_user';

  Stream<List<Suggestion>> getSuggestionsStream() {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: _userId)
        .orderBy('nextDueAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Suggestion.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateStatus(String suggestionId, String status) async {
    await _firestore.collection(_collection).doc(suggestionId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
