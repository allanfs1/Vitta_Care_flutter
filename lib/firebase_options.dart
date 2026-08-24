import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opções do Firebase do projeto **agendaclinica-457713**.
///
/// Valores extraídos de `.specify/api-key.js` (config web). Para chaves
/// dedicadas de Android/iOS, rode `flutterfire configure` e substitua este
/// arquivo. Enquanto isso, usamos a config web como padrão multiplataforma.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAbyyNeqQVvfJQfoig75f0Vbnz-w-6MxxE',
    authDomain: 'agendaclinica-457713.firebaseapp.com',
    projectId: 'agendaclinica-457713',
    storageBucket: 'agendaclinica-457713.firebasestorage.app',
    messagingSenderId: '401017379288',
    appId: '1:401017379288:web:67f28064e7c78fd2147aad',
    measurementId: 'G-Q498WXYX31',
  );

  // Fallback: usa o mesmo App ID web até que `flutterfire configure` gere os
  // identificadores nativos específicos de cada plataforma.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAbyyNeqQVvfJQfoig75f0Vbnz-w-6MxxE',
    appId: '1:401017379288:web:67f28064e7c78fd2147aad',
    messagingSenderId: '401017379288',
    projectId: 'agendaclinica-457713',
    authDomain: 'agendaclinica-457713.firebaseapp.com',
    storageBucket: 'agendaclinica-457713.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAbyyNeqQVvfJQfoig75f0Vbnz-w-6MxxE',
    appId: '1:401017379288:web:67f28064e7c78fd2147aad',
    messagingSenderId: '401017379288',
    projectId: 'agendaclinica-457713',
    authDomain: 'agendaclinica-457713.firebaseapp.com',
    storageBucket: 'agendaclinica-457713.firebasestorage.app',
  );
}
