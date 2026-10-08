import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'injection.dart';
import 'presentation/blocs/chat/chat_bloc.dart';
import 'presentation/blocs/sources/sources_bloc.dart';
import 'presentation/blocs/sources/sources_event.dart';
import 'presentation/screens/chat_screen.dart';
import 'presentation/screens/sources_screen.dart';

class RagProspectionApp extends StatelessWidget {
  const RagProspectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Au-dessus du MaterialApp : le ChatBloc survit aux push/pop du
    // Navigator, donc l'historique est conservé en revenant de l'écran Sources.
    return BlocProvider<ChatBloc>(
      create: (_) => getIt<ChatBloc>(),
      child: MaterialApp(
        title: 'Prospection IA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: AppRoutes.chat,
        routes: {
          AppRoutes.chat: (_) => const ChatScreen(),
          AppRoutes.sources: (_) => BlocProvider<SourcesBloc>(
                create: (_) => getIt<SourcesBloc>()..add(const SourcesRequested()),
                child: const SourcesScreen(),
              ),
        },
      ),
    );
  }
}

/// Affichée à la place de l'app quand la configuration est invalide, pour
/// que l'erreur soit lisible sur l'appareil et pas seulement dans les logs.
class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_suggest_rounded, size: 48, color: AppColors.warning),
                  const SizedBox(height: 16),
                  const Text(
                    'Configuration incomplète',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
