import 'package:flutter/material.dart';

import 'app/app.dart';

export 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFiseSchool();
  runApp(const FiseSchoolApp());
}
