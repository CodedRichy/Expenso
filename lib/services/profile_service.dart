import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Handles profile image uploads to Firebase Storage.
/// Path: users/{uid}/avatar.jpg
class ProfileService {
  ProfileService._();

  static final ProfileService _instance = ProfileService._();

  static ProfileService get instance => _instance;

  static const String _avatarFileName = 'avatar.jpg';

  /// Uploads [file] as the avatar for [uid]. Returns the download URL, or null on failure.
  Future<String?> uploadAvatar(String uid, File file) async {
    if (uid.isEmpty) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('users').child(uid).child(_avatarFileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e, st) {
      debugPrint('ProfileService.uploadAvatar failed: $e');
      if (kDebugMode) debugPrint(st.toString());
      return null;
    }
  }

  /// Uploads avatar from raw [bytes]. Returns the download URL, or null on failure.
  Future<String?> uploadAvatarBytes(String uid, List<int> bytes) async {
    if (uid.isEmpty) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('users').child(uid).child(_avatarFileName);
      await ref.putData(Uint8List.fromList(bytes));
      return await ref.getDownloadURL();
    } catch (e, st) {
      debugPrint('ProfileService.uploadAvatarBytes failed: $e');
      if (kDebugMode) debugPrint(st.toString());
      return null;
    }
  }
}
