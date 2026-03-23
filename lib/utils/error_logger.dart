import 'dart:io';
import 'package:flutter/foundation.dart';

/// Simple error logging utility for development
class ErrorLogger {
  static final ErrorLogger _instance = ErrorLogger._();
  static ErrorLogger get instance => _instance;
  
  ErrorLogger._();

  final List<String> _errorLogs = [];
  final int _maxLogs = 100; // Keep last 100 errors

  /// Log an error with context
  void logError(String error, {String? context, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] ERROR: $error${context != null ? ' | Context: $context' : ''}';
    
    _errorLogs.add(logEntry);
    if (_errorLogs.length > _maxLogs) {
      _errorLogs.removeAt(0);
    }

    // Print to console for development
    if (kDebugMode) {
      debugPrint('🔴 ERROR LOGGED: $error');
      if (context != null) debugPrint('📍 Context: $context');
      if (stackTrace != null) debugPrint('📋 Stack Trace:\n$stackTrace');
      debugPrint('─' * 50);
    }

    // Write to file for persistent logging
    _writeToFile(logEntry, stackTrace);
  }

  /// Log a warning
  void logWarning(String warning, {String? context}) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] WARNING: $warning${context != null ? ' | Context: $context' : ''}';
    
    if (kDebugMode) {
      debugPrint('🟡 WARNING: $warning');
      if (context != null) debugPrint('📍 Context: $context');
    }

    _writeToFile(logEntry);
  }

  /// Log info for debugging
  void logInfo(String info, {String? context}) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] INFO: $info${context != null ? ' | Context: $context' : ''}';
    
    if (kDebugMode) {
      debugPrint('💡 INFO: $info');
      if (context != null) debugPrint('📍 Context: $context');
    }

    _writeToFile(logEntry);
  }

  /// Get all recent error logs
  List<String> getErrorLogs() => List.unmodifiable(_errorLogs);

  /// Clear all logs
  void clearLogs() {
    _errorLogs.clear();
    if (kDebugMode) debugPrint('🧹 Error logs cleared');
  }

  /// Write log to file
  Future<void> _writeToFile(String logEntry, [StackTrace? stackTrace]) async {
    try {
      final file = File('error_logs.txt');
      final sink = file.openWrite(mode: FileMode.append);
      sink.writeln(logEntry);
      if (stackTrace != null) {
        sink.writeln('Stack Trace:\n$stackTrace');
      }
      sink.writeln('─' * 50);
      await sink.close();
    } catch (e) {
      // Don't let logging errors crash the app
      if (kDebugMode) debugPrint('Failed to write error log: $e');
    }
  }

  /// Get log file contents
  Future<String> getLogFileContents() async {
    try {
      final file = File('error_logs.txt');
      if (await file.exists()) {
        return await file.readAsString();
      }
      return 'No log file found.';
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }
}

/// Extension for easy error logging
extension ErrorLoggerExtension on Object {
  void logError(String error, {String? context, StackTrace? stackTrace}) {
    ErrorLogger.instance.logError(error, context: '${runtimeType}: $context', stackTrace: stackTrace);
  }

  void logWarning(String warning, {String? context}) {
    ErrorLogger.instance.logWarning(warning, context: '${runtimeType}: $context');
  }

  void logInfo(String info, {String? context}) {
    ErrorLogger.instance.logInfo(info, context: '${runtimeType}: $context');
  }
}
