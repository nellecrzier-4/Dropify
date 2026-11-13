import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../models/pd_item.dart';
import '../screens/files_tab.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import 'file_actions.dart';

class FileTile extends StatelessWidget {
  final DriveController ctrl;
  final PdItem item;
  final VoidCallback? onLongPress;
  const FileTile({
    super.key,
    required this.ctrl,
    required this.item,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cat = item.category;
    final color = item.isDir ? AppColors.primary : cat.color;
    final subtitle = item.isDir
        ? 'Folder'
        : [formatSize(item.size), formatDate(item.date)]
            .where((e) => e.isNotEmpty)
            .join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(item.isDir ? Icons.folder_outlined : cat.icon,
            color: color, size: 24),
      ),
      title: Text(item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
      trailing: item.isDir
          ? const Icon(Icons.chevron_right, color: AppColors.muted)
          : IconButton(
              icon: const Icon(Icons.more_vert, color: AppColors.muted),
              onPressed: () => showItemActions(context, ctrl, item),
            ),
      onTap: () {
        if (item.isDir) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FolderScreen(ctrl: ctrl, segments: item.fsPath),
            ),
          );
        } else {
          downloadItem(context, ctrl, item);
        }
      },
      onLongPress: onLongPress ??
          (item.isDir ? null : () => showItemActions(context, ctrl, item)),
    );
  }
}
