import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../screens/files_tab.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import 'file_actions.dart';
import 'kit.dart';
import 'motion.dart';

class FileTile extends StatelessWidget {
  final DriveController ctrl;
  final PdItem item;
  final VoidCallback? onLongPress;

  /// Urutan masuk untuk animasi bertingkat.
  final int index;

  const FileTile({
    super.key,
    required this.ctrl,
    required this.item,
    this.onLongPress,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cat = item.category;
    final scheme = AppColors.scheme;
    final color = item.isDir ? scheme.primary : cat.color;
    final subtitle = item.isDir
        ? context.s.folder
        : [formatSize(item.size), formatDate(item.date)]
            .where((e) => e.isNotEmpty)
            .join(' · ');

    return Stagger(
      index: index,
      child: Surface(
        radius: AppRadii.lg,
        padding: EdgeInsets.zero,
        clip: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              tapFeedback();
              if (item.isDir) {
                Navigator.push(
                  context,
                  SharedAxisPageRoute(
                    builder: (_) =>
                        FolderScreen(ctrl: ctrl, segments: item.fsPath),
                  ),
                );
              } else {
                downloadItem(context, ctrl, item);
              }
            },
            onLongPress: onLongPress ??
                (item.isDir
                    ? null
                    : () => showItemActions(
                          context,
                          ctrl,
                          item,
                          origin: globalRectOf(context),
                        )),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: [
                  GlowIcon(
                    icon: item.isDir ? Icons.folder_rounded : cat.icon,
                    size: 44,
                    color: color,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (item.isDir)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant, size: 22),
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.more_vert_rounded,
                          color: scheme.onSurfaceVariant, size: 20),
                      onPressed: () => showItemActions(
                        context,
                        ctrl,
                        item,
                        origin: globalRectOf(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
