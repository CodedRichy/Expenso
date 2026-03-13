import '../repositories/cycle_repository.dart';

/// Service to manage experimental features and access control.
/// Features can be restricted to specific user IDs (creators/beta testers).
class FeatureFlagService {
  FeatureFlagService._();

  static final FeatureFlagService _instance = FeatureFlagService._();
  static FeatureFlagService get instance => _instance;

  /// User IDs of the primary creators. 
  /// These users always have access to all experimental features.
  static const Set<String> _creatorUserIds = {
    // Add your Auth UID here (can be found in Profile -> Developer Options)
    'rishi_placeholder_uid', 
  };

  /// User IDs of invited beta testers.
  static const Set<String> _betaUserIds = {
    // Add beta tester UIDs here
  };

  /// Returns true if the current user is a creator.
  bool get isCreator {
    final uid = CycleRepository.instance.currentUserId;
    return uid.isNotEmpty && _creatorUserIds.contains(uid);
  }

  /// Returns true if the current user is a beta tester or creator.
  bool get isBetaTester {
    final uid = CycleRepository.instance.currentUserId;
    return uid.isNotEmpty && (_creatorUserIds.contains(uid) || _betaUserIds.contains(uid));
  }

  // --- Feature Toggles ---

  /// OCR Receipt Scanning feature.
  bool get canUseOCR => isBetaTester;

  /// Experimental Smart Bar improvements.
  bool get canUseExperimentalNLP => isBetaTester;

  /// Access to hidden settings/logs.
  bool get hasDeveloperMode => isCreator;
}
