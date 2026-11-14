import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/kit.dart';
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
      duration: const Duration(milliseconds: 420),
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
    return Scaffold(
      body: OrbBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Breathing(child: OrbIcon(icon: Icons.cloud_rounded, size: 124)),
              const SizedBox(height: 30),
              Text(
                'Dropify',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: const WaveProgressBar(
                    value: 0,
                    indeterminate: true,
                    height: 5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
