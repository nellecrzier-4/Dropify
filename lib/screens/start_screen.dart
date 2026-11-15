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
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Motion.emphasized,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
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
    with TickerProviderStateMixin {
  /// 0–0.62 ikon masuk (skala + putar sedikit), 0.35–0.85 nama muncul,
  /// 0.75–1 garis & denyut mereda — lalu layar berganti.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1750),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.62, curve: Motion.spring),
    );
    final ring = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.18, 0.9, curve: Motion.emphasized),
    );
    final name = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.38, 0.86, curve: Motion.emphasized),
    );
    final tagline = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 1, curve: Motion.emphasized),
    );

    return Scaffold(
      body: OrbBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _pulse]),
            builder: (context, _) {
              final beat = 1 + 0.035 * (0.5 - ((_pulse.value - 0.5).abs()));
              return Transform.scale(
                scale: beat * (1 + 0.02 * (1 - _intro.value)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Dua cincin yang tumbuh & memudar berurutan.
                          for (final delay in const [0.0, 0.18])
                            Transform.scale(
                              scale: 0.6 + 0.75 * ring.value + delay,
                              child: Opacity(
                                opacity: (1 - ring.value).clamp(0.0, 1.0) * 0.5,
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.scheme.primary
                                          .withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Transform.rotate(
                            angle: (1 - mark.value) * -0.22,
                            child: Transform.scale(
                              scale: 0.45 + 0.55 * mark.value,
                              child: Opacity(
                                opacity: mark.value.clamp(0.0, 1.0),
                                child: const OrbIcon(
                                  icon: Icons.cloud_rounded,
                                  size: 118,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: name.value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, (1 - name.value) * 14),
                        child: Text(
                          'Dropify',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: tagline.value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, (1 - tagline.value) * 10),
                        child: Text(
                          'Pixeldrain di saku',
                          style: TextStyle(
                            color: AppColors.scheme.onSurfaceVariant,
                            fontSize: 12.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: 132,
                      child: Opacity(
                        opacity: tagline.value.clamp(0.0, 1.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: const WaveProgressBar(
                            value: 0,
                            indeterminate: true,
                            height: 5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
