import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/env_config.dart';
import 'core/errors/exceptions.dart';
import 'injection.dart';

Future<void> main() async {
  // Requis avant `dotenv.load`, qui lit le `.env` via le bundle d'assets.
  WidgetsFlutterBinding.ensureInitialized();

  final EnvConfig config;
  try {
    config = await EnvConfig.load();
  } on ConfigurationException catch (error) {
    runApp(ConfigurationErrorApp(message: error.message));
    return;
  }

  configureDependencies(config);
  runApp(const RagProspectionApp());
}
