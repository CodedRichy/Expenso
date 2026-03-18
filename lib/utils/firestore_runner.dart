import 'package:cloud_firestore/cloud_firestore.dart';
import './app_logger.dart';

class FirestoreRunner {
  FirestoreRunner._();

  static Future<T> run<T>(
    Future<T> Function() action, {
    String name = 'FirestoreOperation',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await action();
    } on FirebaseException catch (e, st) {
      _handleFirebaseException(e, st, name, metadata);
      rethrow;
    } catch (e, st) {
      AppLogger.error(
        'Unexpected error during $name',
        name: 'FirestoreRunner',
        error: e,
        stackTrace: st,
        metadata: metadata,
      );
      rethrow;
    }
  }

  static void _handleFirebaseException(
    FirebaseException e,
    StackTrace st,
    String operationName,
    Map<String, dynamic>? metadata,
  ) {
    String message;
    switch (e.code) {
      case 'permission-denied':
        message = 'Permission denied for $operationName';
        break;
      case 'not-found':
        message = 'Document not found for $operationName';
        break;
      case 'unavailable':
        message = 'Firestore service unavailable for $operationName';
        break;
      case 'deadline-exceeded':
        message = 'Deadline exceeded for $operationName';
        break;
      default:
        message = 'FirebaseException (${e.code}) during $operationName: ${e.message}';
    }

    AppLogger.error(
      message,
      name: 'FirestoreRunner',
      error: e,
      stackTrace: st,
      metadata: {
        ...?metadata,
        'errorCode': e.code,
        'plugin': e.plugin,
      },
    );
  }
}
