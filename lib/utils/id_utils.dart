/// Utility for generating consistent IDs across the application.
class IdUtils {
  IdUtils._();

  /// Generates a new cycle ID based on the current timestamp.
  /// Format: c_{timestamp_ms}
  static String generateCycleId() {
    return 'c_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Generates a temporary ID for pending members.
  /// Format: p_{timestamp_ms}
  static String generatePendingMemberId() {
    return 'p_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Returns true if the given ID looks like a Firebase Auth UID.
  /// UIDs are typically ~28 chars and do not start with our custom prefixes.
  static bool isFirebaseUid(String id) {
    return id.length >= 20 && !id.startsWith('p_') && !id.startsWith('c_');
  }
}
