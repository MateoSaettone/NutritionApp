// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDgGGiHU6LlPQ2RODEipDXmk2uEWIxPXmI',
    appId: '1:481312750592:web:27d908a465bb71d11e2ce5',
    messagingSenderId: '481312750592',
    projectId: 'nutritionapp-9877a',
    authDomain: 'nutritionapp-9877a.firebaseapp.com',
    storageBucket: 'nutritionapp-9877a.firebasestorage.app',
    measurementId: 'G-W0ZZ0P07YL',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB1an344ejL3I42HxavedtcQZbPsN9GJr0',
    appId: '1:481312750592:android:29511c9bfc7543f01e2ce5',
    messagingSenderId: '481312750592',
    projectId: 'nutritionapp-9877a',
    storageBucket: 'nutritionapp-9877a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCLftuMFexotvppwaC52fZv_QiMLhDI98c',
    appId: '1:481312750592:ios:b77be764aa4ddd571e2ce5',
    messagingSenderId: '481312750592',
    projectId: 'nutritionapp-9877a',
    storageBucket: 'nutritionapp-9877a.firebasestorage.app',
    iosBundleId: 'com.example.nutritionapp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCLftuMFexotvppwaC52fZv_QiMLhDI98c',
    appId: '1:481312750592:ios:b77be764aa4ddd571e2ce5',
    messagingSenderId: '481312750592',
    projectId: 'nutritionapp-9877a',
    storageBucket: 'nutritionapp-9877a.firebasestorage.app',
    iosBundleId: 'com.example.nutritionapp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDgGGiHU6LlPQ2RODEipDXmk2uEWIxPXmI',
    appId: '1:481312750592:web:77396a907308670a1e2ce5',
    messagingSenderId: '481312750592',
    projectId: 'nutritionapp-9877a',
    authDomain: 'nutritionapp-9877a.firebaseapp.com',
    storageBucket: 'nutritionapp-9877a.firebasestorage.app',
    measurementId: 'G-31Q0XLKXVM',
  );
}
