import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class FileStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a file to Firebase Storage
  /// Returns a map containing the download URL and file metadata
  Future<Map<String, dynamic>> uploadFile({
    required File file,
    required String userId,
    required String reminderId,
  }) async {
    try {
      final String fileName = path.basename(file.path);
      final String fileExtension = path.extension(file.path).toLowerCase();
      final int fileSize = await file.length();
      
      // Determine file type
      String fileType = _getFileType(fileExtension);
      
      // Create a unique path for the file
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String storagePath = 'users/$userId/reminders/$reminderId/$timestamp-$fileName';
      
      // Create reference
      final Reference ref = _storage.ref().child(storagePath);
      
      // Set metadata
      final SettableMetadata metadata = SettableMetadata(
        contentType: _getContentType(fileExtension),
        customMetadata: {
          'userId': userId,
          'reminderId': reminderId,
          'originalName': fileName,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      
      // Upload file
      final UploadTask uploadTask = ref.putFile(file, metadata);
      
      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      
      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Return file info
      return {
        'url': downloadUrl,
        'name': fileName,
        'type': fileType,
        'size': fileSize,
        'extension': fileExtension,
        'storagePath': storagePath,
        'uploadedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Delete a file from Firebase Storage
  Future<void> deleteFile(String storagePath) async {
    try {
      final Reference ref = _storage.ref().child(storagePath);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Delete all attachments for a reminder
  Future<void> deleteReminderAttachments({
    required String userId,
    required String reminderId,
  }) async {
    try {
      final String folderPath = 'users/$userId/reminders/$reminderId/';
      final Reference folderRef = _storage.ref().child(folderPath);
      
      // List all files in the folder
      final ListResult result = await folderRef.listAll();
      
      // Delete each file
      for (Reference fileRef in result.items) {
        await fileRef.delete();
      }
    } catch (e) {
      // If folder doesn't exist or is empty, that's okay
      if (!e.toString().contains('object-not-found')) {
        throw Exception('Failed to delete reminder attachments: $e');
      }
    }
  }

  /// Get file type based on extension
  String _getFileType(String extension) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic', '.heif'];
    final documentExtensions = ['.pdf', '.doc', '.docx', '.txt', '.xlsx', '.xls', '.ppt', '.pptx'];
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.wmv', '.flv'];
    final audioExtensions = ['.mp3', '.wav', '.aac', '.m4a', '.flac', '.ogg'];
    
    if (imageExtensions.contains(extension)) {
      return 'image';
    } else if (documentExtensions.contains(extension)) {
      return 'document';
    } else if (videoExtensions.contains(extension)) {
      return 'video';
    } else if (audioExtensions.contains(extension)) {
      return 'audio';
    } else {
      return 'file';
    }
  }

  /// Get content type for file upload
  String _getContentType(String extension) {
    final contentTypes = {
      // Images
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.bmp': 'image/bmp',
      '.webp': 'image/webp',
      '.heic': 'image/heic',
      '.heif': 'image/heif',
      // Documents
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.txt': 'text/plain',
      '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.xls': 'application/vnd.ms-excel',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      // Videos
      '.mp4': 'video/mp4',
      '.mov': 'video/quicktime',
      '.avi': 'video/x-msvideo',
      '.mkv': 'video/x-matroska',
      // Audio
      '.mp3': 'audio/mpeg',
      '.wav': 'audio/wav',
      '.aac': 'audio/aac',
      '.m4a': 'audio/mp4',
    };
    
    return contentTypes[extension] ?? 'application/octet-stream';
  }

  /// Format file size to human-readable string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
