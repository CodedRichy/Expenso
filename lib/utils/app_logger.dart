import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel { info, warning, error, success, debug }

class AppLogger {
  AppLogger._();

  static void log(
    String message, {
    LogLevel level = LogLevel.info,
    String name = 'Expenso',
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    // Only log in debug mode for now, but use developer.log for better tool integration
    if (!kDebugMode && level == LogLevel.debug) return;

    final emoji = _getEmoji(level);
    final timestamp = DateTime.now().toIso8601String().split('T').last.split('.').first;
    final logMessage = '$emoji [$timestamp] $message';

    developer.log(
      logMessage,
      name: name,
      level: _getPriority(level),
      error: error,
      stackTrace: stackTrace,
    );

    if (kDebugMode && metadata != null) {
      debugPrint('   Metadata: $metadata');
    }
  }

  static void info(String message, {String name = 'Expenso', Map<String, dynamic>? metadata}) =>
      log(message, level: LogLevel.info, name: name, metadata: metadata);

  static void success(String message, {String name = 'Expenso', Map<String, dynamic>? metadata}) =>
      log(message, level: LogLevel.success, name: name, metadata: metadata);

  static void warning(String message, {String name = 'Expenso', Map<String, dynamic>? metadata}) =>
      log(message, level: LogLevel.warning, name: name, metadata: metadata);

  static void error(
    String message, {
    String name = 'Expenso',
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) =>
      log(message,
          level: LogLevel.error,
          name: name,
          error: error,
          stackTrace: stackTrace,
          metadata: metadata);

  static void debug(String message, {String name = 'Expenso', Map<String, dynamic>? metadata}) =>
      log(message, level: LogLevel.debug, name: name, metadata: metadata);

  static String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.success:
        return '✅';
      case LogLevel.debug:
        return '🔍';
    }
  }

  static int _getPriority(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return 0;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.success:
        return 0;
      case LogLevel.debug:
        return 0;
    }
  }
}
