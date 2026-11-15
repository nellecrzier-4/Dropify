// Harness pratinjau: merender layar jadi PNG supaya perubahan visual bisa
// diperiksa tanpa perangkat. Jalankan:
//   PREVIEW=1 flutter test test/preview_test.dart --update-goldens
// Hasilnya ada di test/goldens/ (tidak disimpan di repo).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dropify/controllers/drive_controller.dart';
import 'package:dropify/models/pd_item.dart';
import 'package:dropify/screens/files_tab.dart';
import 'package:dropify/screens/home_screen.dart';
import 'package:dropify/screens/home_tab.dart';
import 'package:dropify/screens/login_screen.dart';
import 'package:dropify/screens/settings_screen.dart';
import 'package:dropify/screens/setup_screen.dart';
import 'package:dropify/screens/start_screen.dart';
import 'package:dropify/services/pixeldrain_api.dart';
import 'package:dropify/theme/app_theme.dart';
import 'package:dropify/widgets/anim.dart';
import 'package:dropify/widgets/kit.dart';

/// Folder font bawaan Flutter SDK; `flutter test` mengekspor FLUTTER_ROOT.
String get _fontDir {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      Platform.environment['FLUTTER_SDK'] ??
      '';
  return '$root/bin/cache/artifacts/material_fonts';
}

Future<void> _loadFonts() async {
  final roboto = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]) {
    final file = File('$_fontDir/$f');
    if (file.existsSync()) {
      roboto.addFont(
        Future.value(ByteData.sublistView(await file.readAsBytes())),
      );
    }
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons');
  final iconFile = File('$_fontDir/MaterialIcons-Regular.otf');
  if (iconFile.existsSync()) {
    icons.addFont(
      Future.value(ByteData.sublistView(await iconFile.readAsBytes())),
    );
    await icons.load();
  }
}

Widget _app(Widget home, AppAppearance appearance) {
  // Bayangan asli (bukan kotak solid) supaya pratinjau sama dengan perangkat.
  debugDisableShadows = false;
  final base = buildTheme(appearance);
  WidgetStateProperty<TextStyle?>? btn(TextStyle? t) =>
      WidgetStatePropertyAll(t?.copyWith(fontFamily: 'Roboto'));
  final theme = base.copyWith(
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.copyWith(
        textStyle: btn(base.textButtonTheme.style?.textStyle?.resolve({})),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        textStyle: btn(base.filledButtonTheme.style?.textStyle?.resolve({})),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        textStyle: btn(base.outlinedButtonTheme.style?.textStyle?.resolve({})),
      ),
    ),
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: home,
  );
}

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget home,
  AppAppearance appearance, {
  double scrollBy = 0,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(home, appearance));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 300));

  if (scrollBy != 0) {
    await tester.drag(find.byType(ListView).first, Offset(0, -scrollBy));
    await tester.pump(const Duration(milliseconds: 400));
  }

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
  debugDisableShadows = true;
}

DriveController _fakeController() {
  final ctrl = DriveController(PixeldrainApi());
  final now = DateTime.now();
  ctrl.username = 'jennifer';
  ctrl.loaded = true;
  ctrl.lastSync = now;
  ctrl.files = [
    PdItem(
      name: 'Holiday in Bali.mp4',
      size: 248 * 1024 * 1024,
      mime: 'video/mp4',
      date: now.subtract(const Duration(hours: 2)),
    ),
    PdItem(
      name: 'Project Skripsi.zip',
      size: 1200 * 1024 * 1024,
      mime: 'application/zip',
      date: now.subtract(const Duration(days: 1)),
    ),
    PdItem(
      name: 'IMG_2481.jpg',
      size: 4 * 1024 * 1024 + 600 * 1024,
      mime: 'image/jpeg',
      date: now.subtract(const Duration(days: 2)),
    ),
    PdItem(
      name: 'Laporan Q3.pdf',
      size: 2 * 1024 * 1024,
      mime: 'application/pdf',
      date: now.subtract(const Duration(days: 3)),
    ),
    PdItem(
      name: 'Assets',
      isDir: true,
      date: now.subtract(const Duration(days: 4)),
    ),
  ];
  return ctrl;
}

Widget _shell(Widget child, {Widget? nav}) => Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: OrbBackground(child: child)),
          if (nav != null)
            Positioned(left: 0, right: 0, bottom: 0, child: nav!),
        ],
      ),
    );

Widget _tabPreview() {
  final ctrl = _fakeController();
  return _shell(
    HomeTab(ctrl: ctrl, onLogout: () {}),
    nav: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SafeArea(
        top: false,
        child: GlassNav(
          items: const [
            GlassNavItem(icon: Icons.home_outlined, label: 'Home'),
            GlassNavItem(icon: Icons.folder_open_outlined, label: 'Files'),
            GlassNavItem(icon: Icons.photo_library_outlined, label: 'Photos'),
          ],
          index: 0,
          onTap: (_) {},
        ),
      ),
    ),
  );
}

Widget _filesPreview() {
  final ctrl = _fakeController();
  return _shell(FilesTab(ctrl: ctrl));
}

/// Demo material: kartu sengaja di belakang nav pill untuk menilai blur.
Widget _navMaterial() {
  final cards = <Widget>[
    for (var i = 0; i < 14; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Surface(
          radius: AppRadii.lg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              GlowIcon(
                icon: Icons.insert_drive_file_outlined,
                size: 42,
                color: AppColors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document ${i + 1}.pdf',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '2.${i}4 MB',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
  ];
  return Scaffold(
    body: Stack(
      children: [
        Positioned.fill(
          child: OrbBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 90, 18, 0),
              child: Column(children: cards),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: GlassNav(
              items: const [
                GlassNavItem(icon: Icons.home_outlined, label: 'Home'),
                GlassNavItem(icon: Icons.folder_open_outlined, label: 'Files'),
                GlassNavItem(icon: Icons.photo_library_outlined, label: 'Photos'),
              ],
              index: 0,
              onTap: (_) {},
            ),
          ),
        ),
      ],
    ),
  );
}

// Hanya jalan kalau diminta: PREVIEW=1 flutter test … --update-goldens
bool get _enabled => Platform.environment['PREVIEW'] == '1';

void main() {
  setUpAll(() async {
    await _loadFonts();
    SharedPreferences.setMockInitialValues({'setup_done': false});
  });

  for (final appearance in [AppAppearance.light, AppAppearance.dark]) {
    final tag = appearance.name;

    testWidgets('login $tag', skip: !_enabled, (tester) async {
      await _shoot(tester, 'login_$tag', const LoginScreen(), appearance);
    });

    testWidgets('splash $tag', skip: !_enabled, (tester) async {
      await _shoot(tester, 'splash_$tag', const StartScreen(), appearance);
    });

    testWidgets('setup $tag', skip: !_enabled, (tester) async {
      await _shoot(tester, 'setup_$tag', SetupScreen(onDone: () {}), appearance);
    });

    testWidgets('home $tag', skip: !_enabled, (tester) async {
      await _shoot(
        tester,
        'home_$tag',
        HomeScreen(api: PixeldrainApi()),
        appearance,
      );
    });

    testWidgets('home tab $tag', skip: !_enabled, (tester) async {
      await _shoot(tester, 'hometab_$tag', _tabPreview(), appearance,
          scrollBy: 560);
    });

    testWidgets('files $tag', skip: !_enabled, (tester) async {
      await _shoot(tester, 'files_$tag', _filesPreview(), appearance);
    });

    testWidgets('nav material $tag', skip: !_enabled, (tester) async {
      await _shoot(tester, 'nav_material_$tag', _navMaterial(), appearance);
    });

    testWidgets('settings $tag', skip: !_enabled, (tester) async {
      await _shoot(tester, 'settings_$tag', const SettingsScreen(), appearance);
    });
  }
}
