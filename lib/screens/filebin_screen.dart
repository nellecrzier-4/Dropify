import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../services/download_service.dart';
import '../services/filebin_api.dart';
import '../services/native_downloads.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';

/// Halaman Filebin: satu "bin" berperan sebagai folder berisi berkas yang
/// dibagikan lewat tautan — tanpa akun, dihapus otomatis 6 hari setelah
/// unggahan terakhir.
class FilebinScreen extends StatefulWidget {
  const FilebinScreen({super.key});

  @override
  State<FilebinScreen> createState() => _FilebinScreenState();
}

class _FilebinScreenState extends State<FilebinScreen> {
  static const String _prefsKey = 'filebin_bin';

  final FilebinApi _api = FilebinApi();
  final TextEditingController _binField = TextEditingController();

  FilebinBin? _bin;
  String? _binId;
  String? _error;
  bool _loading = false;
  bool _busy = false;
  final Map<String, double> _uploading = <String, double>{};

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _binField.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.isNotEmpty) {
        _binField.text = saved;
        await _open(saved);
      }
    } catch (_) {}
  }

  Future<void> _open([String? id]) async {
    final bin = (id ?? _binField.text).trim();
    if (bin.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _binId = bin;
    });
    try {
      final info = await _api.bin(bin);
      if (!mounted) return;
      setState(() {
        _bin = info;
        _loading = false;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, bin);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is FilebinException && e.code == 'not_found'
            ? 'Bin "$bin" tidak ditemukan.'
            : 'Gagal membuka bin: $e';
      });
    }
  }

  Future<void> _createBin() async {
    final id = FilebinApi.randomBin();
    _binField.text = id;
    await _open(id);
  }

  Future<void> _pickAndUpload() async {
    final bin = _binId;
    if (bin == null || bin.isEmpty) {
      showAppSnack(context, 'Buka atau buat bin dulu.');
      return;
    }
    final uris = await NativeDownloads.pickDocuments(multiple: true);
    if (uris == null) {
      showAppSnack(context, 'Pemilih berkas tidak tersedia di perangkat ini.');
      return;
    }
    if (uris.isEmpty) return;

    for (final uri in uris) {
      final file = await NativeDownloads.resolveDocument(uri);
      if (file == null) continue;
      if (!mounted) return;
      setState(() => _uploading[file.name] = 0);
      try {
        await _api.upload(
          bin: bin,
          file: File(file.path),
          name: file.name,
          onProgress: (sent, total) {
            if (!mounted || total <= 0) return;
            setState(() => _uploading[file.name] = sent / total);
          },
        );
      } catch (e) {
        if (mounted) {
          showAppSnack(context, 'Gagal mengunggah ${file.name}: $e');
        }
      } finally {
        if (mounted) setState(() => _uploading.remove(file.name));
      }
    }
    await _open(bin);
  }

  Future<void> _download(FilebinFile file) async {
    final bin = _binId;
    if (bin == null) return;
    final service = DownloadService.shared;
    if (service == null) {
      showAppSnack(context, 'Downloader belum siap.');
      return;
    }
    final url = FilebinApi.downloadUrl(bin, file.name);
    showAppSnack(context, context.s.downloadStartedSnack(file.name));
    await service.download(
      PdItem(name: file.name, size: file.bytes),
      urlOverride: url,
    );
  }

  Future<void> _delete(FilebinFile file) async {
    final bin = _binId;
    if (bin == null) return;
    try {
      await _api.deleteFile(bin, file.name);
      await _open(bin);
    } catch (e) {
      if (mounted) showAppSnack(context, 'Gagal menghapus: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    final schemeText = AppColors.text;
    final files = _bin?.files ?? const <FilebinFile>[];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Filebin',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Muat ulang',
                    onPressed: () => _open(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _binField,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _open(),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'nama bin (folder), mis. dropify-k3m9pq2x',
                        prefixIcon: Icon(Icons.folder_outlined, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Buka',
                    onPressed: _loading ? null : () => _open(),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : _createBin,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Bin baru'),
                  ),
                  const Spacer(),
                  if (_bin?.expires != null)
                    Text(
                      'Kedaluwarsa ${_shortDate(_bin!.expires!)}',
                      style: TextStyle(
                        color: AppColors.scheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  _error!,
                  style: TextStyle(color: AppColors.scheme.error, fontSize: 12.5),
                ),
              ),
            if (_uploading.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in _uploading.entries) ...[
                      Text(
                        '${entry.key} · ${(entry.value * 100).round()}%',
                        style: TextStyle(fontSize: 12, color: schemeText),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: entry.value.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : files.isEmpty
                      ? Center(
                          child: Text(
                            _binId == null
                                ? 'Buka bin atau buat bin baru untuk mulai.'
                                : 'Bin ini belum berisi berkas.',
                            style: TextStyle(
                              color: AppColors.scheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                          itemCount: files.length,
                          itemBuilder: (context, index) {
                            final file = files[files.length - 1 - index];
                            return Stagger(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Surface(
                                  radius: AppRadii.lg,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              file.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: schemeText,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              formatSize(file.bytes),
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color:
                                                    AppColors.scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Unduh',
                                        onPressed: () => _download(file),
                                        icon: const Icon(Icons.download_rounded),
                                      ),
                                      IconButton(
                                        tooltip: 'Hapus',
                                        onPressed: () => _delete(file),
                                        icon: const Icon(Icons.delete_outline_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _pickAndUpload,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Unggah'),
      ),
    );
  }

  static String _shortDate(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.day)}/${two(time.month)} ${two(time.hour)}:${two(time.minute)}';
  }
}
