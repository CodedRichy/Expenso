// Generated for Firebase (expenso-e138a). Config from CLI; Dart file created manually after FlutterFire CLI issue.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web. '
        'Use android or ios.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAwWgtnkQxTUra_Pd-UJAVW3Wx6MQAxpUQ',
    appId: '1:211875033656:android:c65dbc8db71f53b2a5eccd',
    messagingSenderId: '211875033656',
    projectId: 'expenso-e138a',
    storageBucket: 'expenso-e138a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC3XV_t3wj26zgP4IyGq5Iwq8fMcfaZxeE',
    appId: '1:211875033656:ios:cab73d7d3a1bfe86a5eccd',
    messagingSenderId: '211875033656',
    projectId: 'expenso-e138a',
    storageBucket: 'expenso-e138a.firebasestorage.app',
  );
}
