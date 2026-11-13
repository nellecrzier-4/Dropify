import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import 'wave_progress.dart';

/// Status sinkronisasi dengan Pixeldrain (data asli dari DriveController).
class SyncCard extends StatelessWidget {
  final DriveController ctrl;
  final VoidCallback onLogout;
  const SyncCard({super.key, required this.ctrl, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final syncing = ctrl.loading;
    final failed = ctrl.error != null && !syncing;

    final String title;
    final String? subtitle;
    final IconData icon;
    if (syncing) {
      title = s.syncingTitle;
      subtitle = null;
      icon = Icons.sync;
    } else if (failed) {
      title = s.syncFailedTitle;
      subtitle = ctrl.error;
      icon = Icons.sync_problem;
    } else {
      title = s.syncedTitle;
      subtitle = ctrl.lastSync == null
          ? null
          : s.filesAgo(ctrl.files.length, formatAgo(ctrl.lastSync!));
      icon = Icons.cloud_done_outlined;
    }

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: syncing ? null : (ctrl.sessionExpired ? onLogout : ctrl.refresh),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.cardHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon,
                        color: failed ? AppColors.danger : AppColors.primary,
                        size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w700)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 12.5)),
                        ],
                      ],
                    ),
                  ),
                  if (failed)
                    TextButton(
                      onPressed: ctrl.sessionExpired ? onLogout : ctrl.refresh,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(ctrl.sessionExpired ? s.signIn : s.retry),
                    )
                  else
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              if (syncing) ...[
                const SizedBox(height: 14),
                const WaveProgressBar(value: 0, indeterminate: true, height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
