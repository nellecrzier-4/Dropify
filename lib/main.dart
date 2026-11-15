import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/locale_controller.dart';
import 'screens/start_screen.dart';
import 'services/app_settings.dart';
import 'services/cache_cleaner.dart';
import 'services/diagnostics.dart';
import 'services/proxy_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Catat error & kejadian penting ke Download/Dropify/dropify.log.
  Diagnostics.instance.install();
  Diagnostics.instance.log('app', 'start');
  // Edge-to-edge: konten menggambar di belakang status bar & navigation bar.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await LocaleController.instance.load();
  await ThemeController.instance.load();
  // Status bar mengikuti tampilan aktif (Terang / Gelap / AMOLED).
  SystemChrome.setSystemUIOverlayStyle(
    ThemeController.instance.systemOverlayStyle,
  );
  await AppSettings.instance.load();
  await ProxyService.instance.load();
  await DownloadHistory.instance.load();
  // Berkas yang selesai tanpa aplikasi (mis. lewat DownloadManager) tetap
  // muncul di riwayat saat aplikasi dibuka.
  unawaited(
    DownloadHistory.instance.syncFolder('/storage/emulated/0/Download/Dropify'),
  );
  // Bersihkan sisa potongan upload dari sesi sebelumnya.
  unawaited(CacheCleaner.clearUploadParts());
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
        theme: buildTheme(themeController.appearance),
        locale: controller.locale,
        supportedLocales: const [Locale('en'), Locale('id')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => LocaleScope(
          strings: controller.strings,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: themeController.systemOverlayStyle,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const StartScreen(),
      ),
    );
  }
}
