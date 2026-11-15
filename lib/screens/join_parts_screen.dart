import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../services/join_service.dart';
import '../services/native_downloads.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';

class _PartGroup {
  _PartGroup(this.base, this.extension, this.files);

  final String base;
  final String extension;
  final List<File> files;

  /// Jumlah ukuran bagian yang benar-benar ada. Berkas bisa hilang (dihapus,
  /// dipindah, atau unduhan gagal) — jangan sampai layar ikut gagal dibangun.
  int get totalSize => files.fold(0, (sum, f) {
        try {
          if (!f.existsSync()) return sum;
          return sum + f.lengthSync();
        } catch (_) {
          return sum;
        }
      });

  /// true kalau semua bagian masih ada di disk.
  bool get complete => files.every((f) {
        try {
          return f.existsSync();
        } catch (_) {
          return false;
        }
      });
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

    if (await output.exists()) {
      final overwrite = await showExpressiveDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(s.joinOverwriteTitle),
          content: Text(s.joinOverwriteBody(group.outputName)),
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
      if (overwrite != true) return;
    }

    final result = await JoinService.instance.join(
      parts: group.files,
      outputPath: output.path,
      outputName: group.outputName,
      deleteParts: _deleteParts,
    );
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.joinFailedDetail(JoinService.instance.error ?? 'gagal'),
          ),
        ),
      );
      return;
    }
    showAppSnack(context, s.joinSucceeded(group.outputName));
    await _scan();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = AppColors.scheme;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 18, 10),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.joinParts,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Stagger(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: Surface(
                    radius: AppRadii.xl,
                    padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                    child: Row(
                      children: [
                        GlowIcon(
                          icon: Icons.delete_sweep_outlined,
                          size: 42,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.deletePartsAfter,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.deletePartsHint,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _deleteParts,
                          onChanged: (v) => setState(() => _deleteParts = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: JoinService.instance,
                builder: (context, _) {
                  final join = JoinService.instance;
                  if (join.status == JoinStatus.idle) {
                    return const SizedBox.shrink();
                  }
                  final scheme = AppColors.scheme;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: Surface(
                      radius: AppRadii.lg,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  join.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                join.status == JoinStatus.done
                                    ? 'selesai'
                                    : join.status == JoinStatus.error
                                        ? 'gagal'
                                        : '${(join.progress * 100).round()}%',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: join.status == JoinStatus.done
                                  ? 1
                                  : join.progress,
                              minHeight: 6,
                              backgroundColor: scheme.surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            join.status == JoinStatus.running
                                ? '${formatSize(join.doneBytes)} / '
                                    '${formatSize(join.totalBytes)}'
                                    ' · sisa ${formatEta(join.eta)} · '
                                    'tetap lanjut walau halaman ditutup'
                                : join.status == JoinStatus.done
                                    ? 'Tersimpan · ${formatSize(join.totalBytes)}'
                                    : join.error ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.base,
                  switchInCurve: Motion.emphasized,
                  switchOutCurve: Motion.standard,
                  child: _loading
                      ? const Center(
                          key: ValueKey('loading'),
                          child: CircularProgressIndicator(),
                        )
                      : _groups.isEmpty
                          ? ListView(
                              key: const ValueKey('empty'),
                              padding:
                                  const EdgeInsets.fromLTRB(18, 4, 18, 30),
                              children: [
                                Stagger(
                                  index: 1,
                                  child: DashedPanel(
                                    radius: AppRadii.xl,
                                    padding: const EdgeInsets.fromLTRB(
                                        22, 32, 22, 28),
                                    child: Column(
                                      children: [
                                        const OrbIcon(
                                          icon: Icons.merge_type_rounded,
                                          size: 100,
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          s.noPartsFound,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 13.5,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              key: const ValueKey('list'),
                              padding:
                                  const EdgeInsets.fromLTRB(18, 4, 18, 30),
                              itemCount: _groups.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final group = _groups[i];
                                return Stagger(
                                  index: i,
                                  step: const Duration(milliseconds: 45),
                                  child: Surface(
                                    radius: AppRadii.xl,
                                    padding: const EdgeInsets.fromLTRB(
                                        13, 12, 12, 12),
                                    child: Row(
                                      children: [
                                        GlowIcon(
                                          icon: Icons.merge_type_rounded,
                                          size: 44,
                                          color: scheme.primary,
                                        ),
                                        const SizedBox(width: 13),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                group.outputName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: AppColors.text,
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.1,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${group.count} ${s.parts} · '
                                                '${formatSize(group.totalSize)}'
                                                '${group.complete ? '' : ' · ada bagian hilang'}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _MergeAction(
                                          label: s.merge,
                                          onTap: _busy
                                              ? null
                                              : () => _join(group),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
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

/// Tombol gabung M3 (filled, tinggi 44); memudar saat tidak aktif.
class _MergeAction extends StatelessWidget {
  const _MergeAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return AnimatedOpacity(
      duration: Motion.fast,
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        height: 44,
        child: FilledButton(
          onPressed: onTap == null
              ? null
              : () {
                  tapFeedback();
                  onTap!.call();
                },
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
