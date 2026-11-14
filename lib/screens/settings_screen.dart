import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../services/app_settings.dart';
import '../services/native_downloads.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../utils/file_types.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasFileAccess = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final ok = await NativeDownloads.hasAllFilesAccess();
    if (mounted) setState(() => _hasFileAccess = ok);
  }

  Future<void> _toggleDynamic(bool value) async {
    await ThemeController.instance.setDynamic(value);
    if (value) return; // menyalakan cukup langsung diterapkan
    // Mematikan: warnanya perlu dimuat ulang dari awal -> restart aplikasi.
    NativeDownloads.restartApp();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = ThemeController.instance;
    final locale = LocaleController.instance;
    final settings = AppSettings.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.settings,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([theme, locale, settings, DownloadHistory.instance]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Section(title: s.appearance),
              _Card(
                children: [
                  SwitchListTile(
                    value: theme.dynamicColor,
                    activeColor: AppColors.primary,
                    onChanged: theme.systemAccentAvailable ? _toggleDynamic : null,
                    title: Text(s.dynamicColor),
                    subtitle: Text(s.dynamicColorHint,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ),
                  SwitchListTile(
                    value: theme.amoled,
                    activeColor: AppColors.primary,
                    onChanged: (v) => theme.setAmoled(v),
                    title: Text(s.amoledBlack),
                    subtitle: Text(s.amoledHint,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ),
                ],
              ),
              _Section(title: s.language),
              _Card(
                children: [
                  RadioListTile<AppLanguage>(
                    value: AppLanguage.system,
                    groupValue: locale.mode,
                    activeColor: AppColors.primary,
                    title: Text(s.followSystem),
                    subtitle: Text(
                      locale.locale.languageCode == 'id'
                          ? 'Bahasa Indonesia'
                          : 'English',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
                    onChanged: (v) => locale.setMode(v!),
                  ),
                  RadioListTile<AppLanguage>(
                    value: AppLanguage.english,
                    groupValue: locale.mode,
                    activeColor: AppColors.primary,
                    title: Text(s.english),
                    onChanged: (v) => locale.setMode(v!),
                  ),
                ],
              ),
              _Section(title: s.downloadsSection),
              _Card(
                children: [
                  ListTile(
                    leading: Icon(Icons.speed, color: AppColors.primary),
                    title: Text(s.connections),
                    subtitle: Slider(
                      value: settings.connections.toDouble(),
                      min: 2,
                      max: 12,
                      divisions: 10,
                      label: s.connectionsHint(settings.connections),
                      onChanged: (v) => settings.setConnections(v.round()),
                    ),
                  ),
                  SwitchListTile(
                    value: settings.notifications,
                    activeColor: AppColors.primary,
                    onChanged: (v) async {
                      await settings.setNotifications(v);
                      if (!v) return;
                      await NativeDownloads.requestPermissions();
                    },
                    title: Text(s.notificationsProgress),
                    subtitle: Text(s.notificationsProgressHint,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(s.saveFolder),
                    subtitle: Text(NativeDownloads.folderPath,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ),
                  ListTile(
                    leading: Icon(
                      _hasFileAccess
                          ? Icons.verified_user_outlined
                          : Icons.gpp_maybe_outlined,
                      color: _hasFileAccess
                          ? AppColors.primary
                          : AppColors.danger,
                    ),
                    title: Text(s.fileAccess),
                    subtitle: Text(
                      _hasFileAccess ? s.fileAccessGranted : s.fileAccessMissing,
                      style: TextStyle(
                        color:
                            _hasFileAccess ? AppColors.muted : AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                    trailing: _hasFileAccess
                        ? null
                        : TextButton(
                            onPressed: () async {
                              await NativeDownloads.requestAllFilesAccess();
                              await _checkAccess();
                            },
                            child: Text(s.openSettings),
                          ),
                  ),
                ],
              ),
              _Section(title: s.behaviourSection),
              _Card(
                children: [
                  SwitchListTile(
                    value: settings.clipboardDetect,
                    activeColor: AppColors.primary,
                    onChanged: (v) => settings.setClipboardDetect(v),
                    title: Text(s.clipboardDetect),
                    subtitle: Text(s.clipboardDetectHint,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ),
                  SwitchListTile(
                    value: settings.confirmDelete,
                    activeColor: AppColors.primary,
                    onChanged: (v) => settings.setConfirmDelete(v),
                    title: Text(s.confirmDelete),
                    subtitle: Text(s.confirmDeleteHint,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ),
                ],
              ),
              _Section(title: s.dataSection),
              _Card(
                children: [
                  ListTile(
                    leading: Icon(Icons.history, color: AppColors.primary),
                    title: Text(s.downloadHistory),
                    subtitle: Text(
                      '${DownloadHistory.instance.items.length}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.muted),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined),
                    title: Text(s.clearHistory),
                    onTap: () => DownloadHistory.instance.clear(),
                  ),
                ],
              ),
              _Section(title: s.about),
              _Card(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(s.appName),
                    subtitle: Text('${s.version} 1.0.0 (v10)',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 0, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(children: children),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _open(BuildContext context, DownloadRecord record) async {
    final ok = await NativeDownloads.openPath(record.path);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.s.openFileFailed} ${record.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.downloadHistory,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: DownloadHistory.instance,
        builder: (context, _) {
          final items = DownloadHistory.instance.items;
          if (items.isEmpty) {
            return Center(
              child: Text(s.noHistory,
                  style: const TextStyle(color: AppColors.muted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final record = items[i];
              final exists = File(record.path).existsSync();
              return ListTile(
                tileColor: AppColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                leading: Icon(
                  exists ? Icons.insert_drive_file : Icons.file_present,
                  color: exists ? AppColors.primary : AppColors.muted,
                ),
                title: Text(record.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${formatSize(record.size)} · ${formatDate(record.time)}',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12),
                ),
                trailing: PopupMenuButton<String>(
                  color: AppColors.cardHigh,
                  onSelected: (value) async {
                    switch (value) {
                      case 'open':
                        await _open(context, record);
                      case 'share':
                        await NativeDownloads.shareText(record.path);
                      case 'delete':
                        try {
                          await File(record.path).delete();
                        } catch (_) {}
                        await DownloadHistory.instance.remove(record);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'open', child: Text(s.download)),
                    PopupMenuItem(value: 'share', child: Text(s.share)),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(s.delete,
                          style: const TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
                onTap: () => _open(context, record),
              );
            },
          );
        },
      ),
    );
  }
}
