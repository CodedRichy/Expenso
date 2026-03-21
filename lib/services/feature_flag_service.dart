import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../repositories/cycle_repository.dart';

/// Service to manage experimental features and access control.
/// Features can be restricted to specific user IDs (creators/beta testers).
/// Now dynamic: Status is fetched from Firestore 'users' collection.
class FeatureFlagService extends ChangeNotifier {
  FeatureFlagService._();

  static final FeatureFlagService _instance = FeatureFlagService._();
  static FeatureFlagService get instance => _instance;

  bool _isBeta = false;
  bool _isCreator = false;
  bool _initialized = false;

  /// User IDs of the primary creators. 
  /// These users always have access to all experimental features.
  static const Set<String> _creatorUserIds = {
    '605oNyF1miUumLGMgEnaGGD0Lyh2', // App creator
  };

  /// Returns true if the service has finished its initial fetch.
  bool get isInitialized => _initialized;

  /// Returns true if the current user is a creator.
  bool get isCreator => _isCreator;

  /// Returns true if the current user is a beta tester or creator.
  bool get isBetaTester => _isBeta || _isCreator;

  /// Load status from Firestore.
  Future<void> refresh() async {
    final uid = CycleRepository.instance.currentUserId;
    if (uid.isEmpty) {
      _isBeta = false;
      _isCreator = false;
      _initialized = true;
      notifyListeners();
      return;
    }

    _isCreator = _creatorUserIds.contains(uid);

    try {
      final data = await Supabase.instance.client.from('users').select('is_beta').eq('id', uid).maybeSingle();
      if (data != null) {
        _isBeta = data['is_beta'] == true;
      } else {
        _isBeta = false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FeatureFlagService: refresh failed: $e');
      // Keep previous state or fall back to false
    }

    _initialized = true;
    notifyListeners();
  }

  // --- Feature Toggles ---

  /// OCR Receipt Scanning feature (Camera icon in Magic Bar).
  bool get canUseOCR => isBetaTester;

  /// High-rate Experimental NLP (e.g. more advanced expense extraction).
  bool get canUseExperimentalNLP => isBetaTester;
}
