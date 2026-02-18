import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../repositories/cycle_repository.dart';

/// Handles profile image uploads to Firebase Storage.
/// Path: users/{userId}/avatar.jpg (matches rule users/{userId}/{allPaths=**}).
class ProfileService {
  ProfileService._();

  static final ProfileService _instance = ProfileService._();

  static ProfileService get instance => _instance;

  /// Uploads [file] as the avatar for [uid]. Path: users/$uid/avatar.jpg.
  /// On success updates CycleRepository with the download URL. Returns the URL or null.
  /// Throws [Exception] with a descriptive message on Firebase storage errors.
  Future<String?> uploadAvatar(String uid, File file) async {
    if (uid.isEmpty) return null;
    final ref = FirebaseStorage.instance.ref().child('users').child(uid).child('avatar.jpg');
    try {
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      await CycleRepository.instance.updateCurrentUserPhotoURL(downloadUrl);
      return downloadUrl;
    } on FirebaseException catch (e, st) {
      debugPrint('ProfileService.uploadAvatar FirebaseException: ${e.code} ${e.message}');
      if (kDebugMode) debugPrint(st.toString());
      final message = _messageForStorageCode(e.code);
      throw Exception(message);
    } catch (e, st) {
      debugPrint('ProfileService.uploadAvatar failed: $e');
      if (kDebugMode) debugPrint(st.toString());
      return null;
    }
  }

  /// Uploads avatar from raw [bytes]. Path: users/$uid/avatar.jpg.
  /// On success updates CycleRepository. Throws [Exception] on Firebase errors.
  Future<String?> uploadAvatarBytes(String uid, List<int> bytes) async {
    if (uid.isEmpty) return null;
    final ref = FirebaseStorage.instance.ref().child('users').child(uid).child('avatar.jpg');
    try {
      await ref.putData(Uint8List.fromList(bytes));
      final downloadUrl = await ref.getDownloadURL();
      await CycleRepository.instance.updateCurrentUserPhotoURL(downloadUrl);
      return downloadUrl;
    } on FirebaseException catch (e, st) {
      debugPrint('ProfileService.uploadAvatarBytes FirebaseException: ${e.code} ${e.message}');
      if (kDebugMode) debugPrint(st.toString());
      throw Exception(_messageForStorageCode(e.code));
    } catch (e, st) {
      debugPrint('ProfileService.uploadAvatarBytes failed: $e');
      if (kDebugMode) debugPrint(st.toString());
      return null;
    }
  }

  static String _messageForStorageCode(String code) {
    switch (code) {
      case 'object-not-found':
        return 'Storage path not found. Ensure rules allow users/{userId}/** for authenticated users.';
      case 'unauthorized':
      case 'permission-denied':
        return 'Storage access denied. Check security rules for users/{userId}/**.';
      default:
        return 'Storage error ($code). Enable Firebase Storage and allow users/{userId}/** for authenticated users.';
    }
  }
}
