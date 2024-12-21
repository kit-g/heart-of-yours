import 'package:flutter/material.dart';
import 'package:heart/core/utils/firebase.dart';

import 'presentation/navigation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(const HeartApp());
}
