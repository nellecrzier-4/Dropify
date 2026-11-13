import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/star_badge.dart';

class _SetupPage {
  const _SetupPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

List<_SetupPage> _pagesOf(AppStrings s) => [
      _SetupPage(
        icon: Icons.folder_copy_outlined,
        title: s.setupTitle1,
        body: s.setupBody1,
      ),
      _SetupPage(
        icon: Icons.download_for_offline_outlined,
        title: s.setupTitle2,
        body: s.setupBody2,
      ),
      _SetupPage(
        icon: Icons.notifications_active_outlined,
        title: s.setupTitle3,
        body: s.setupBody3,
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

  void _next(int count) {
    if (_index == count - 1) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 460),
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
                padding: const EdgeInsets.fromLTRB(24, 14, 12, 0),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.4),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        s.ofCount(_index + 1, pages.length),
                        key: ValueKey<int>(_index),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
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
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
                child: Column(
                  children: [
                    _Dots(count: pages.length, index: _index),
                    const SizedBox(height: 26),
                    Entrance(
                      delay: const Duration(milliseconds: 260),
                      slide: 18,
                      child: PressScale(
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => _next(pages.length),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Row(
                                key: ValueKey<bool>(isLast),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isLast ? Icons.rocket_launch : Icons.east,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(isLast ? s.start : s.next),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.downloadsFolderHint('Download/Dropify'),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
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
          offset: Offset(0, eased * 34),
          child: Transform.scale(
            scale: 1 - (eased.abs() * 0.08),
            child: Opacity(opacity: 1 - eased.abs() * 0.55, child: child),
          ),
        );
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Entrance(
                delay: const Duration(milliseconds: 60),
                slide: 16,
                child: Breathing(
                  child: StarBadge(icon: page.icon, size: 210),
                ),
              ),
              const SizedBox(height: 44),
              Entrance(
                delay: const Duration(milliseconds: 160),
                child: Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Entrance(
                delay: const Duration(milliseconds: 240),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    page.body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 15.5,
                      height: 1.5,
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
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: i == index ? 26 : 8,
            decoration: BoxDecoration(
              color: i == index ? AppColors.primary : AppColors.cardHigh,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}
