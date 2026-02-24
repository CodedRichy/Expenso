import 'package:flutter/foundation.dart';

enum SyncStatus {
  synced,
  syncing,
  offline,
  error,
}

class SyncStatusService extends ChangeNotifier {
  SyncStatusService._internal();

  static final SyncStatusService _instance = SyncStatusService._internal();
  static SyncStatusService get instance => _instance;

  SyncStatus _status = SyncStatus.synced;
  DateTime? _lastSyncTime;
  String? _lastError;

  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;

  bool get isSynced => _status == SyncStatus.synced;
  bool get isSyncing => _status == SyncStatus.syncing;
  bool get isOffline => _status == SyncStatus.offline;
  bool get hasError => _status == SyncStatus.error;

  String get lastSyncDisplay {
    if (_lastSyncTime == null) return 'Never';
    final diff = DateTime.now().difference(_lastSyncTime!);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void markSyncing() {
    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();
  }

  void markSynced() {
    _status = SyncStatus.synced;
    _lastSyncTime = DateTime.now();
    _lastError = null;
    notifyListeners();
  }

  void markOffline() {
    _status = SyncStatus.offline;
    notifyListeners();
  }

  void markError(String error) {
    _status = SyncStatus.error;
    _lastError = error;
    notifyListeners();
  }

  void reset() {
    _status = SyncStatus.synced;
    _lastSyncTime = null;
    _lastError = null;
    notifyListeners();
  }
}
