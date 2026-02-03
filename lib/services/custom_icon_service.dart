import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CustomIcon {
  final String id;
  final String imageUrl;
  final DateTime createdAt;

  CustomIcon({
    required this.id,
    required this.imageUrl,
    required this.createdAt,
  });

  factory CustomIcon.fromMap(Map<String, dynamic> map, String id) {
    return CustomIcon(
      id: id,
      imageUrl: map['imageUrl'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'imageUrl': imageUrl, 'createdAt': Timestamp.fromDate(createdAt)};
  }
}

class CustomIconService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Upload custom icon image and store metadata
  Future<CustomIcon?> uploadCustomIcon(File imageFile) async {
    try {
      if (_userId == null) return null;

      // Check file size (max 5MB)
      final fileSize = await imageFile.length();
      const maxSizeInBytes = 5 * 1024 * 1024; // 5MB
      if (fileSize > maxSizeInBytes) {
        throw Exception('File size exceeds 5MB limit');
      }

      // Generate unique ID for the icon
      final iconId = DateTime.now().millisecondsSinceEpoch.toString();

      // Get file extension from the image file
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      final extension = validExtensions.contains(fileExtension)
          ? fileExtension
          : 'jpg'; // Default to jpg if unknown

      // Upload image to Firebase Storage
      final storageRef = _storage.ref().child(
        'users/$_userId/custom_icons/$iconId.$extension',
      );

      await storageRef.putFile(imageFile);
      final imageUrl = await storageRef.getDownloadURL();

      // Store metadata in Firestore
      final customIcon = CustomIcon(
        id: iconId,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('customIcons')
          .doc(iconId)
          .set(customIcon.toMap());

      return customIcon;
    } catch (e) {
      print('Error uploading custom icon: $e');
      return null;
    }
  }

  // Get all custom icons for the current user
  Stream<List<CustomIcon>> getCustomIconsStream() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('customIcons')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CustomIcon.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // Delete custom icon
  Future<void> deleteCustomIcon(String iconId) async {
    try {
      if (_userId == null) return;

      // Get the document first to find the actual file URL
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('customIcons')
          .doc(iconId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['imageUrl'] != null) {
          // Delete from Storage using the URL reference
          final imageUrl = data['imageUrl'] as String;
          final storageRef = _storage.refFromURL(imageUrl);
          await storageRef.delete();
        }
      }

      // Delete from Firestore
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('customIcons')
          .doc(iconId)
          .delete();
    } catch (e) {
      print('Error deleting custom icon: $e');
    }
  }
}
