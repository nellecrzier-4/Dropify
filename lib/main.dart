import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/locale_controller.dart';
import 'screens/start_screen.dart';
import 'services/app_settings.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge: konten menggambar di belakang status bar & navigation bar.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );
  await LocaleController.instance.load();
  await ThemeController.instance.load();
  await AppSettings.instance.load();
  await DownloadHistory.instance.load();
  runApp(const DropifyApp());
}

class DropifyApp extends StatelessWidget {
  const DropifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LocaleController.instance;
    final themeController = ThemeController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, themeController]),
      builder: (context, _) => MaterialApp(
        title: 'Dropify',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: controller.locale,
        supportedLocales: const [Locale('en'), Locale('id')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => LocaleScope(
          strings: controller.strings,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const StartScreen(),
      ),
    );
  }
}
