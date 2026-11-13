import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../services/native_downloads.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';

class _PartGroup {
  _PartGroup(this.base, this.extension, this.files);

  final String base;
  final String extension;
  final List<File> files;

  int get totalSize => files.fold(0, (sum, f) => sum + f.lengthSync());
  int get count => files.length;
  String get outputName => '$base$extension';
}

/// Menggabungkan file hasil upload/download multi-bagian (nama.part1.ext, ...).
class JoinPartsScreen extends StatefulWidget {
  const JoinPartsScreen({super.key});

  @override
  State<JoinPartsScreen> createState() => _JoinPartsScreenState();
}

class _JoinPartsScreenState extends State<JoinPartsScreen> {
  List<_PartGroup> _groups = const [];
  bool _loading = true;
  bool _busy = false;
  bool _deleteParts = true;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _loading = true);
    final dir = Directory(NativeDownloads.folderPath);
    final groups = <String, _PartGroup>{};

    if (await dir.exists()) {
      final regex = RegExp(r'^(.*)\.part(\d+)(\.[^.]+)?$');
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final match = regex.firstMatch(name);
        if (match == null) continue;
        final base = match.group(1) ?? '';
        final ext = match.group(3) ?? '';
        final key = '$base|$ext';
        groups.putIfAbsent(key, () => _PartGroup(base, ext, []));
        groups[key]!.files.add(entity);
      }
    }

    for (final group in groups.values) {
      group.files.sort((a, b) {
        int index(File f) {
          final m = RegExp(r'\.part(\d+)').firstMatch(f.uri.pathSegments.last);
          return int.tryParse(m?.group(1) ?? '0') ?? 0;
        }

        return index(a).compareTo(index(b));
      });
    }

    if (mounted) {
      setState(() {
        _groups = groups.values.toList()
          ..sort((a, b) => a.outputName.compareTo(b.outputName));
        _loading = false;
      });
    }
  }

  Future<void> _join(_PartGroup group) async {
    final s = context.s;
    final dir = Directory(NativeDownloads.folderPath);
    final output = File('${dir.path}/${group.outputName}');

    setState(() => _busy = true);
    try {
      if (await output.exists()) {
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(s.joinOverwriteTitle),
            content: Text('${group.outputName} ${s.joinOverwriteBody}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(s.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(s.merge),
              ),
            ],
          ),
        );
        if (overwrite != true) {
          setState(() => _busy = false);
          return;
        }
        await output.delete();
      }

      final sink = output.openWrite();
      final buffer = Uint8List(2 * 1024 * 1024);
      try {
        for (final file in group.files) {
          final input = await file.open();
          try {
            while (true) {
              final read = await input.readInto(buffer);
              if (read <= 0) break;
              sink.add(buffer.sublist(0, read));
            }
          } finally {
            await input.close();
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (_deleteParts) {
        for (final file in group.files) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }

      NativeDownloads.scanFile(output.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.joined} ${group.outputName}')),
      );
      await _scan();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s.joinFailed}: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.joinParts,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          SwitchListTile(
            value: _deleteParts,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _deleteParts = v),
            title: Text(s.deletePartsAfter),
            subtitle: Text(s.deletePartsHint,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            s.noPartsFound,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final group = _groups[i];
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: ListTile(
                              leading: Icon(Icons.merge_type,
                                  color: AppColors.primary),
                              title: Text(group.outputName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${group.count} ${s.parts} · ${formatSize(group.totalSize)}',
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 12),
                              ),
                              trailing: FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18),
                                ),
                                onPressed: _busy ? null : () => _join(group),
                                child: Text(s.merge),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
