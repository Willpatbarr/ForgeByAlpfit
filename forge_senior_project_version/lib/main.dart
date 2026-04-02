import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'register_web_image_picker_stub.dart'
    if (dart.library.html) 'register_web_image_picker.dart' as web_picker;

import 'app/app.dart';
import 'app/auth_state.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  web_picker.registerWebImagePicker();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  AuthStateNotifier.instance.startListening();

  runApp(const MyApp());
}
