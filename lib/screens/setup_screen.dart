import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../services/native_downloads.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/kit.dart';
import '../widgets/wave_progress.dart';

class _SetupPage {
  const _SetupPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.art,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget art;
}

List<_SetupPage> _pagesOf(AppStrings s) => [
      _SetupPage(
        icon: Icons.folder_copy_outlined,
        title: s.setupTitle1,
        body: s.setupBody1,
        art: const _FilesArt(),
      ),
      _SetupPage(
        icon: Icons.download_for_offline_outlined,
        title: s.setupTitle2,
        body: s.setupBody2,
        art: const _SpeedArt(),
      ),
      _SetupPage(
        icon: Icons.notifications_active_outlined,
        title: s.setupTitle3,
        body: s.setupBody3,
        art: const _ProgressArt(),
      ),
    ];

/// Onboarding singkat sebelum login.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Minta pengecualian penghemat baterai supaya unduhan/unggahan tidak
  /// dibekukan sistem beberapa menit setelah aplikasi ditinggalkan.
  Future<void> _askBackgroundPermission() async {
    if (!await NativeDownloads.isBatteryOptimized()) return;
    if (!mounted) return;
    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleController.instance.strings.allowBackgroundTitle),
        content: Text(
          LocaleController.instance.strings.allowBackgroundBody,
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocaleController.instance.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(LocaleController.instance.strings.allowBackground),
          ),
        ],
      ),
    );
    if (allow == true) await NativeDownloads.requestBatteryExemption();
  }

  Future<void> _next(int count) async {
    if (_index == count - 1) {
      await _askBackgroundPermission();
      if (mounted) widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final pages = _pagesOf(s);
    final isLast = _index == pages.length - 1;

    return Scaffold(
      body: OrbBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 14, 4),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: AppColors.glow(AppColors.accent, blur: 14, y: 5),
                      ),
                      child: const Icon(Icons.cloud_rounded,
                          size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Dropify',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: AppMotion.base,
                      child: SoftChip(
                        key: ValueKey<int>(_index),
                        label: s.ofCount(_index + 1, pages.length),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: widget.onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        visualDensity: VisualDensity.compact,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(s.skip),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _PageBody(
                    page: pages[i],
                    controller: _controller,
                    index: i,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                child: Column(
                  children: [
                    _Dots(count: pages.length, index: _index),
                    const SizedBox(height: 24),
                    Entrance(
                      delay: const Duration(milliseconds: 220),
                      slide: 16,
                      child: PrimaryButton(
                        label: isLast ? s.start : s.next,
                        icon: isLast
                            ? Icons.rocket_launch_rounded
                            : Icons.arrow_forward_rounded,
                        onPressed: () => _next(pages.length),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.downloadsFolderHint('Download/Dropify'),
                      style: TextStyle(color: AppColors.muted, fontSize: 11.5),
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

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.page,
    required this.controller,
    required this.index,
  });

  final _SetupPage page;
  final PageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        var delta = 0.0;
        if (controller.hasClients && controller.position.haveDimensions) {
          delta = (controller.page ?? index.toDouble()) - index;
        }
        final eased = delta.clamp(-1.0, 1.0);
        return Transform.translate(
          offset: Offset(0, eased * 30),
          child: Transform.scale(
            scale: 1 - (eased.abs() * 0.06),
            child: Opacity(opacity: 1 - eased.abs() * 0.55, child: child),
          ),
        );
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Entrance(
                delay: const Duration(milliseconds: 60),
                slide: 14,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: page.art,
                ),
              ),
              const SizedBox(height: 34),
              Entrance(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 29,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Entrance(
                delay: const Duration(milliseconds: 220),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: Text(
                    page.body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 14.5,
                      height: 1.55,
                    ),
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

/// Peringkat kartu mini per halaman — memberi gambaran nyata isi aplikasi.
class _FilesArt extends StatelessWidget {
  const _FilesArt();

  @override
  Widget build(BuildContext context) {
    return Surface(
      radius: AppRadii.xl,
      elevation: SurfaceElevation.lg,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashedPanel(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                OrbIcon(icon: Icons.folder_copy_rounded, size: 62),
                const SizedBox(height: 6),
                Text(
                  'Dropify',
                  style: TextStyle(
                    color: AppColors.mutedStrong,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MiniFile(
            icon: Icons.movie_outlined,
            color: AppColors.videos,
            name: 'Holiday.mp4',
            meta: '248 MB',
          ),
          const SizedBox(height: 8),
          _MiniFile(
            icon: Icons.folder_zip_outlined,
            color: AppColors.archives,
            name: 'Project.zip',
            meta: '1.2 GB',
          ),
          const SizedBox(height: 8),
          _MiniFile(
            icon: Icons.image_outlined,
            color: AppColors.images,
            name: 'IMG_2481.jpg',
            meta: '4.6 MB',
          ),
        ],
      ),
    );
  }
}

class _MiniFile extends StatelessWidget {
  const _MiniFile({
    required this.icon,
    required this.color,
    required this.name,
    required this.meta,
  });

  final IconData icon;
  final Color color;
  final String name;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlowIcon(icon: icon, size: 38, color: color, glow: false),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                meta,
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Icon(Icons.check_rounded, size: 16, color: AppColors.muted),
      ],
    );
  }
}

class _SpeedArt extends StatelessWidget {
  const _SpeedArt();

  @override
  Widget build(BuildContext context) {
    return HeroSurface(
      radius: AppRadii.xl,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: const Color(0xFF9CCBFF)),
              const SizedBox(width: 5),
              Text(
                context.s.connectionsBadge(8),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  context.s.liveBadge,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '12.4',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 46,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  'MB/s',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: const WaveProgressBar(value: 0.64, height: 8),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Holiday.mp4',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '64%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressArt extends StatelessWidget {
  const _ProgressArt();

  @override
  Widget build(BuildContext context) {
    return Surface(
      radius: AppRadii.xl,
      elevation: SurfaceElevation.lg,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: StatRow(
                  icon: Icons.speed_rounded,
                  value: '12.4 MB/s',
                  label: context.s.speedLabel,
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: AppColors.divider,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatRow(
                  icon: Icons.timer_outlined,
                  value: '00:12',
                  label: context.s.timeLeftLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ProgressRow(label: 'Holiday.mp4', value: 0.82, color: AppColors.videos),
          const SizedBox(height: 10),
          _ProgressRow(label: 'Project.zip', value: 0.46, color: AppColors.archives),
          const SizedBox(height: 10),
          _ProgressRow(label: 'IMG_2481.jpg', value: 1, color: AppColors.images),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            color: color,
            backgroundColor: AppColors.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.cardHigh,
          ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            height: 7,
            width: i == index ? 24 : 7,
            decoration: BoxDecoration(
              color: i == index
                  ? AppColors.accent
                  : AppColors.text.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
      ],
    );
  }
}
