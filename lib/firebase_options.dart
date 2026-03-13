import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
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

  static FirebaseOptions get web => const FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: 'AIzaSyAp9g83dmX1-XgNkFPzDVQo2orY9OvuLbQ'),
    appId: String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: '1:211875033656:web:2f8174003c25c7ada5eccd'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '211875033656'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'expenso-e138a'),
    authDomain: 'expenso-e138a.firebaseapp.com',
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'expenso-e138a.firebasestorage.app'),
    measurementId: 'G-1J2ZHDLG8L',
  );

  static FirebaseOptions get android => const FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY', defaultValue: 'AIzaSyAwWgtnkQxTUra_Pd-UJAVW3Wx6MQAxpUQ'),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '1:211875033656:android:c65dbc8db71f53b2a5eccd'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '211875033656'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'expenso-e138a'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'expenso-e138a.firebasestorage.app'),
  );

  static FirebaseOptions get ios => const FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY', defaultValue: 'AIzaSyC3XV_t3wj26zgP4IyGq5Iwq8fMcfaZxeE'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '1:211875033656:ios:cab73d7d3a1bfe86a5eccd'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '211875033656'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'expenso-e138a'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'expenso-e138a.firebasestorage.app'),
    iosBundleId: 'com.example.expenso',
  );
}
