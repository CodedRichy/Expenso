import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../repositories/cycle_repository.dart';

/// Handles profile image uploads to Firebase Storage.
/// Path: users/{userId}/avatar.jpg (matches rule users/{userId}/{allPaths=**}).
class ProfileService {
  ProfileService._();

  static final ProfileService _instance = ProfileService._();

  static ProfileService get instance => _instance;

  Future<String?> uploadAvatar(String uid, File file) async {
    if (uid.isEmpty) return null;
    final path = 'users/$uid/avatar.jpg';
    try {
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));
      final downloadUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);
      await CycleRepository.instance.updateCurrentUserPhotoURL(downloadUrl);
      return downloadUrl;
    } catch (e, st) {
      debugPrint('ProfileService.uploadAvatar failed: $e');
      if (kDebugMode) debugPrint(st.toString());
      return null;
    }
  }

  Future<String?> uploadAvatarBytes(String uid, List<int> bytes) async {
    if (uid.isEmpty) return null;
    final path = 'users/$uid/avatar.jpg';
    try {
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(path, Uint8List.fromList(bytes), fileOptions: const FileOptions(upsert: true));
      final downloadUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);
      await CycleRepository.instance.updateCurrentUserPhotoURL(downloadUrl);
      return downloadUrl;
    } catch (e, st) {
      debugPrint('ProfileService.uploadAvatarBytes failed: $e');
      if (kDebugMode) debugPrint(st.toString());
      return null;
    }
  }
}
