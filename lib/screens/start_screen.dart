import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/star_badge.dart';
import '../widgets/wave_progress.dart';
import 'login_screen.dart';
import 'setup_screen.dart';

/// Menentukan layar pertama: setup (sekali saja) atau login.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  static const _prefKey = 'setup_done';

  bool? _setupDone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _setupDone = prefs.getBool(_prefKey) ?? false);
  }

  Future<void> _finishSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    if (mounted) setState(() => _setupDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final done = _setupDone;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: done == null
          ? const _BootSplash(key: ValueKey('boot'))
          : done
              ? const LoginScreen(key: ValueKey('login'))
              : SetupScreen(key: const ValueKey('setup'), onDone: _finishSetup),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StarBadge(icon: Icons.cloud_outlined, size: 150),
            SizedBox(height: 36),
            SizedBox(
              width: 160,
              child: WaveProgressBar(value: 0, indeterminate: true),
            ),
            SizedBox(height: 14),
            Text('Dropify',
                style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }
}
