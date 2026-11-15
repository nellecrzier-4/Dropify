import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../services/pixeldrain_api.dart';
import '../theme/app_theme.dart';
import '../widgets/file_tile.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'file_list_screen.dart';

/// Tab Files: browse folder & file di filesystem Pixeldrain.
class FilesTab extends StatefulWidget {
  final DriveController ctrl;
  const FilesTab({super.key, required this.ctrl});

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
            child: Stagger(
              child: Text(
                context.s.files,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
          Expanded(
            child: FolderView(
              ctrl: widget.ctrl,
              segments: const [],
              root: true,
            ),
          ),
        ],
      ),
    );
  }
}

class FolderView extends StatefulWidget {
  final DriveController ctrl;
  final List<String> segments;
  final bool root;
  const FolderView({
    super.key,
    required this.ctrl,
    required this.segments,
    this.root = false,
  });

  @override
  State<FolderView> createState() => _FolderViewState();
}

class _FolderViewState extends State<FolderView> {
  List<PdItem> _items = const [];
  String? _error;
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _proOnly =>
      _error != null && _error!.toLowerCase().contains('pro');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.ctrl.api.listDir(widget.segments);
      list.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      _items = list;
    } on PixeldrainException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message) {
    showAppSnack(context, message);
  }

  Future<String?> _askName({required String title, String initial = ''}) {
    final controller = TextEditingController(text: initial);
    final s = context.s;
    return showExpressiveDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: s.folderName),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(s.create),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder() async {
    final name = await _askName(title: context.s.newFolder);
    if (name == null || name.trim().isEmpty) return;
    final err = await widget.ctrl.createFolder(widget.segments, name.trim());
    if (!mounted) return;
    if (err != null) {
      _snack(err);
    } else {
      await _load();
    }
  }

  Future<void> _uploadHere() async {
    final s = context.s;
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null || !mounted) return;

    setState(() => _uploading = true);
    showExpressiveDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(s.uploadingFiles)),
          ],
        ),
      ),
    );

    String? lastError;
    for (final file in res.files) {
      final path = file.path;
      if (path == null) continue;
      final err = await widget.ctrl.uploadToFolder(
        widget.segments,
        path,
        file.name,
      );
      if (err != null) lastError = err;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _uploading = false);
    if (lastError != null) _snack(lastError);
    await _load();
  }

  Future<void> _folderActions(PdItem item) async {
    final s = context.s;
    await showExpressiveSheet<void>(
      context: context,
      builder: (sheetContext) => _FolderSheet(
        item: item,
        onRename: () async {
          Navigator.pop(sheetContext);
          final name = await _askName(title: s.rename, initial: item.name);
          if (name == null || name.trim().isEmpty) return;
          final err = await widget.ctrl.renameFsItem(item, name.trim());
          if (!mounted) return;
          if (err != null) {
            _snack(err);
          } else {
            await _load();
          }
        },
        onDelete: () async {
          Navigator.pop(sheetContext);
          final ok = await showExpressiveDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: Text(s.deleteFolderTitle),
              content: Text(s.deleteFolderBody(item.name)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: Text(s.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: Text(s.delete),
                ),
              ],
            ),
          );
          if (ok != true) return;
          final err = await widget.ctrl.deleteFsItem(item);
          if (!mounted) return;
          if (err != null) {
            _snack(err);
          } else {
            await _load();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final loading = _loading && _items.isEmpty;

    return AnimatedSwitcher(
      duration: Motion.base,
      switchInCurve: Motion.emphasized,
      switchOutCurve: Motion.standard,
      child: loading
          ? const Center(
              key: ValueKey('loading'),
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              key: const ValueKey('content'),
              onRefresh: () async {
                await _load();
                if (widget.root) await widget.ctrl.refresh();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                children: [
                  if (widget.root)
                    Stagger(
                      child: _AllUploadsCard(
                        onTap: () => Navigator.push(
                          context,
                          SharedAxisPageRoute(
                              builder: (_) => FileListScreen(ctrl: widget.ctrl)),
                        ),
                      ),
                    ),
                  if (widget.root) const SizedBox(height: 12),
                  if (_proOnly)
                    _ProCard(
                      onOpenUploads: () => Navigator.push(
                        context,
                        SharedAxisPageRoute(
                            builder: (_) => FileListScreen(ctrl: widget.ctrl)),
                      ),
                    )
                  else if (_error != null)
                    _ErrorPanel(
                      message: s.loadFolderError(_error!),
                      onRetry: _load,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            SoftChip(
                              icon: Icons.create_new_folder_outlined,
                              label: s.newFolder,
                              onTap: _uploading ? null : _createFolder,
                            ),
                            const SizedBox(width: 8),
                            SoftChip(
                              icon: Icons.upload_file_rounded,
                              label: s.uploadHere,
                              onTap: _uploading ? null : _uploadHere,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_items.isEmpty && _error == null && !_loading)
                    _EmptyFolder(onUpload: _uploading ? null : _uploadHere),
                  for (var i = 0; i < _items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FileTile(
                        ctrl: widget.ctrl,
                        item: _items[i],
                        index: i + 1,
                        onLongPress: _items[i].isDir
                            ? () => _folderActions(_items[i])
                            : null,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Kartu "semua upload": tile tonal + judul + chevron.
class _AllUploadsCard extends StatelessWidget {
  const _AllUploadsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = AppColors.scheme;
    return Surface(
      radius: AppRadii.xl,
      padding: EdgeInsets.zero,
      clip: true,
      onTap: () {
        tapFeedback();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
        child: Row(
          children: [
            GlowIcon(
              icon: Icons.cloud_upload_outlined,
              size: 44,
              color: scheme.primary,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.allUploads,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.allUploadsSubtitle,
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
            Icon(Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Empty state folder: panel bergaris putus + orb ikon.
class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder({required this.onUpload});

  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Stagger(
      index: 2,
      child: DashedPanel(
        radius: AppRadii.xl,
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: [
            OrbIcon(icon: Icons.folder_open_rounded, size: 100),
            const SizedBox(height: 16),
            Text(
              s.folderEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.scheme.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            SoftChip(
              icon: Icons.upload_file_rounded,
              label: s.uploadHere,
              color: AppColors.scheme.primary,
              selected: true,
              onTap: onUpload,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Stagger(
      index: 2,
      child: DashedPanel(
        radius: AppRadii.xl,
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
        color: AppColors.scheme.outlineVariant,
        child: Column(
          children: [
            OrbIcon(
              icon: Icons.cloud_off_rounded,
              size: 76,
              color: AppColors.danger,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            SoftChip(
              icon: Icons.refresh_rounded,
              label: s.retry,
              color: AppColors.scheme.primary,
              selected: true,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({required this.onOpenUploads});

  final VoidCallback onOpenUploads;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = AppColors.scheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Surface(
        radius: AppRadii.xl,
        color: AppColors.scheme.secondaryContainer,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GlowIcon(
                  icon: Icons.folder_special_outlined,
                  size: 42,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    s.proFeatureTitle,
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              s.proFeatureBody,
              style: TextStyle(
                color: scheme.onSecondaryContainer.withValues(alpha: 0.82),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpenUploads,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSecondaryContainer,
                  shape: const StadiumBorder(),
                ),
                child: Text(s.allUploads),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet aksi folder M3: judul file, lalu baris berikon.
class _FolderSheet extends StatelessWidget {
  const _FolderSheet({
    required this.item,
    required this.onRename,
    required this.onDelete,
  });

  final PdItem item;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = AppColors.scheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GlowIcon(
                  icon: Icons.folder_rounded,
                  size: 44,
                  color: scheme.primary,
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
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.folderActions,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SheetRow(
              icon: Icons.drive_file_rename_outline_rounded,
              label: s.rename,
              onTap: onRename,
            ),
            _SheetRow(
              icon: Icons.delete_outline_rounded,
              label: s.delete,
              color: AppColors.danger,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        child: Row(
          children: [
            GlowIcon(
              icon: icon,
              size: 40,
              color: color ?? AppColors.scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color ?? AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class FolderScreen extends StatelessWidget {
  final DriveController ctrl;
  final List<String> segments;
  const FolderScreen({super.key, required this.ctrl, required this.segments});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 18, 6),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        segments.isEmpty ? context.s.files : segments.last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: FolderView(ctrl: ctrl, segments: segments)),
            ],
          ),
        ),
      ),
    );
  }
}
