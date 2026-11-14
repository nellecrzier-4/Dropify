import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';

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
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      color: failed ? Colors.redAccent : AppColors.muted),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w500)),
                  ),
                  if (failed)
                    Text(ctrl.sessionExpired ? s.signIn : s.retry,
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700))
                  else
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              if (syncing) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: AppColors.divider,
                    color: AppColors.primary,
                  ),
                ),
              ],
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 38),
                  child: Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13.5)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
