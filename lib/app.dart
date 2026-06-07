import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_settings_controller.dart';
import 'core/design_tokens.dart';
import 'core/document_file_service.dart';
import 'features/library/library_controller.dart';
import 'features/shell/app_shell.dart';

class JianxiReaderApp extends StatelessWidget {
  const JianxiReaderApp({super.key, this.documentService, this.settings});

  final DocumentLibraryService? documentService;
  final AppSettingsController? settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsController>(
          create: (_) => settings ?? (AppSettingsController()..load()),
        ),
        ChangeNotifierProvider<LibraryController>(
          create: (_) => LibraryController(
            documentService: documentService ?? const DocumentFileService(),
          )..loadDocuments(),
        ),
      ],
      child: Consumer<AppSettingsController>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: '简兮阅读器',
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            themeAnimationDuration: AppMotion.normal,
            themeAnimationCurve: AppMotion.standard,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
