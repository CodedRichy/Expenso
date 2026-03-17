import 'package:flutter/foundation.dart';

/// Base class for repositories providing common functionality like ChangeNotifier.
abstract class BaseRepository extends ChangeNotifier {
  void notify() => notifyListeners();
}
