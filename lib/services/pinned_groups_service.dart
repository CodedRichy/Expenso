import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-specific pinned group IDs (max 3). Pinned groups appear at the top of the list.
class PinnedGroupsService extends ChangeNotifier {
  PinnedGroupsService._();

  static const String _key = 'pinned_group_ids';
  static const int _maxPinned = 3;

  static final PinnedGroupsService _instance = PinnedGroupsService._();
  static PinnedGroupsService get instance => _instance;

  List<String> _ids = [];
  List<String> get pinnedIds => List.unmodifiable(_ids);

  bool isPinned(String groupId) => _ids.contains(groupId);

  /// Load from disk. Call once at app start (e.g. from groups list).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ids = prefs.getStringList(_key) ?? [];
      if (_ids.length > _maxPinned) _ids = _ids.take(_maxPinned).toList();
      notifyListeners();
    } catch (_) {
      _ids = [];
    }
  }

  /// Toggle pin for [groupId]. If already pinned, unpin. If not pinned, add (and enforce max 3).
  Future<void> togglePin(String groupId) async {
    if (_ids.contains(groupId)) {
      _ids = _ids.where((id) => id != groupId).toList();
    } else {
      if (_ids.length >= _maxPinned) _ids = _ids.sublist(1);
      _ids = [..._ids, groupId];
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _ids);
    } catch (_) {}
    notifyListeners();
  }

  /// True if user can pin one more (fewer than 3 pinned).
  bool get canPinMore => _ids.length < _maxPinned;
}
