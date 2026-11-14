// Elle yazıldı (flutterfire CLI yerine): değerler android/app/google-services.json'dan.
// Firebase projesi: zarfla-37da9. Yalnız Android desteklenir.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('Zarfla is configured for Android only.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDh4G3ByFeDy70by0-qxULE2kVfGRZtRZQ',
    appId: '1:759266825187:android:409d036b5e330d50d546d6',
    messagingSenderId: '759266825187',
    projectId: 'zarfla-37da9',
    storageBucket: 'zarfla-37da9.firebasestorage.app',
  );
}
