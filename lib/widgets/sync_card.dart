import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import 'kit.dart';
import 'motion.dart';

/// Status sinkronisasi dengan Pixeldrain (data asli dari DriveController).
class SyncCard extends StatelessWidget {
  final DriveController ctrl;
  final VoidCallback onLogout;
  const SyncCard({super.key, required this.ctrl, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = AppColors.scheme;
    final syncing = ctrl.loading;
    final failed = ctrl.error != null && !syncing;

    final String title;
    final String? subtitle;
    final IconData icon;
    if (syncing) {
      title = s.syncingTitle;
      subtitle = null;
      icon = Icons.sync_rounded;
    } else if (failed) {
      title = s.syncFailedTitle;
      subtitle = ctrl.error;
      icon = Icons.sync_problem_rounded;
    } else {
      title = s.syncedTitle;
      subtitle = ctrl.lastSync == null
          ? null
          : s.filesAgo(ctrl.files.length, formatAgo(ctrl.lastSync!, s));
      icon = Icons.cloud_done_outlined;
    }

    final tint = failed ? scheme.error : scheme.primary;
    final stateKey = syncing
        ? 'syncing'
        : failed
            ? 'failed'
            : 'synced';

    return Surface(
      radius: AppRadii.xl,
      padding: EdgeInsets.zero,
      clip: true,
      onTap: syncing ? null : (ctrl.sessionExpired ? onLogout : ctrl.refresh),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GlowIcon(icon: icon, size: 42, color: tint),
                const SizedBox(width: 12),
                Expanded(
                  child: SharedAxisSwitcher(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        key: ValueKey(stateKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                          color: failed ? AppColors.danger : AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: Motion.fast,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: failed
                      ? Padding(
                          key: const ValueKey('retry'),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            ctrl.sessionExpired ? s.signIn : s.retry,
                            style: TextStyle(
                              color: AppColors.scheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Padding(
                          key: const ValueKey('chevron'),
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.chevron_right_rounded,
                              color: scheme.onSurfaceVariant, size: 22),
                        ),
                ),
              ],
            ),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.emphasized,
              alignment: Alignment.topCenter,
              child: syncing
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12, right: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: scheme.primary,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.emphasized,
              alignment: Alignment.topCenter,
              child: subtitle == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 7, left: 54, right: 6),
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: failed
                              ? AppColors.danger
                              : scheme.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
