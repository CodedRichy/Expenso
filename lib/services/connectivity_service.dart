import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum ConnectivityStatus {
  online,
  offline,
  unknown,
}

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;

  ConnectivityService._internal() {
    _startPeriodicCheck();
  }

  ConnectivityStatus _status = ConnectivityStatus.unknown;
  ConnectivityStatus get status => _status;
  bool get isOnline => _status == ConnectivityStatus.online;
  bool get isOffline => _status == ConnectivityStatus.offline;

  Timer? _periodicTimer;

  void _startPeriodicCheck() {
    _checkConnectivity();
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    final wasOffline = _status == ConnectivityStatus.offline;
    
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _status = ConnectivityStatus.online;
      } else {
        _status = ConnectivityStatus.offline;
      }
    } on SocketException catch (_) {
      _status = ConnectivityStatus.offline;
    } on TimeoutException catch (_) {
      _status = ConnectivityStatus.offline;
    } catch (_) {
      _status = ConnectivityStatus.offline;
    }

    if (wasOffline && _status == ConnectivityStatus.online) {
      debugPrint('ConnectivityService: Back online');
    } else if (!wasOffline && _status == ConnectivityStatus.offline) {
      debugPrint('ConnectivityService: Gone offline');
    }
    
    notifyListeners();
  }

  Future<void> checkNow() async {
    await _checkConnectivity();
  }

  void markOffline() {
    if (_status != ConnectivityStatus.offline) {
      _status = ConnectivityStatus.offline;
      notifyListeners();
    }
  }

  void markOnline() {
    if (_status != ConnectivityStatus.online) {
      _status = ConnectivityStatus.online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
