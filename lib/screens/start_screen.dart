import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
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

class _BootSplash extends StatefulWidget {
  const _BootSplash({super.key});

  @override
  State<_BootSplash> createState() => _BootSplashState();
}

class _BootSplashState extends State<_BootSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.65, curve: Motion.spring),
    );
    final text = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.35, 1, curve: Motion.emphasized),
    );

    return Scaffold(
      body: OrbBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: mark,
                builder: (context, child) => Transform.scale(
                  scale: 0.55 + 0.45 * mark.value.clamp(0.0, 1.2),
                  child: Opacity(
                    opacity: mark.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
                child: const OrbIcon(icon: Icons.cloud_rounded, size: 124),
              ),
              const SizedBox(height: 26),
              AnimatedBuilder(
                animation: text,
                builder: (context, child) => Opacity(
                  opacity: text.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (1 - text.value) * 10),
                    child: child,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Dropify',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 132,
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
            ],
          ),
        ),
      ),
    );
  }
}
