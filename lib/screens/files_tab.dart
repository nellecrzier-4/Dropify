import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../services/pixeldrain_api.dart';
import '../theme/app_theme.dart';
import '../widgets/file_tile.dart';
import 'file_list_screen.dart';

/// Tab Files: browse folder & file di filesystem Pixeldrain.
class FilesTab extends StatelessWidget {
  final DriveController ctrl;
  const FilesTab({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(context.s.files,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: FolderView(ctrl: ctrl, segments: const [], root: true)),
        ],
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
      appBar: AppBar(
        title: Text(segments.isEmpty ? context.s.files : segments.last,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: FolderView(ctrl: ctrl, segments: segments),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _askName({required String title, String initial = ''}) {
    final controller = TextEditingController(text: initial);
    final s = context.s;
    return showDialog<String>(
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
    showDialog<void>(
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(s.folderActions,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12.5)),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(s.rename),
              onTap: () async {
                Navigator.pop(sheetContext);
                final name = await _askName(
                  title: s.rename,
                  initial: item.name,
                );
                if (name == null || name.trim().isEmpty) return;
                final err =
                    await widget.ctrl.renameFsItem(item, name.trim());
                if (!mounted) return;
                if (err != null) {
                  _snack(err);
                } else {
                  await _load();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Colors.redAccent),
              title: Text(s.delete,
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final ok = await showDialog<bool>(
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        if (widget.root) await widget.ctrl.refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (widget.root)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.cloud_upload_outlined,
                    color: AppColors.primary),
              ),
              title: Text(s.allUploads,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: Text(s.allUploadsSubtitle,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12.5)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => FileListScreen(ctrl: widget.ctrl)),
              ),
            ),
          if (_proOnly)
            _ProCard(onOpenUploads: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => FileListScreen(ctrl: widget.ctrl)),
                ))
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.loadFolderError(_error!),
                      style: const TextStyle(color: AppColors.muted)),
                  TextButton(onPressed: _load, child: Text(s.retry)),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.create_new_folder_outlined,
                        size: 18),
                    label: Text(s.newFolder),
                    onPressed: _uploading ? null : _createFolder,
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.upload_file, size: 18),
                    label: Text(s.uploadHere),
                    onPressed: _uploading ? null : _uploadHere,
                  ),
                ],
              ),
            ),
          if (_items.isEmpty && _error == null && !_loading)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(s.folderEmpty,
                    style: const TextStyle(color: AppColors.muted)),
              ),
            ),
          for (final item in _items)
            FileTile(
              ctrl: widget.ctrl,
              item: item,
              onLongPress: item.isDir ? () => _folderActions(item) : null,
            ),
        ],
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_special_outlined,
                  color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(s.proFeatureTitle,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(s.proFeatureBody,
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.45)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onOpenUploads,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                shape: const StadiumBorder(),
              ),
              child: Text(s.allUploads),
            ),
          ),
        ],
      ),
    );
  }
}
