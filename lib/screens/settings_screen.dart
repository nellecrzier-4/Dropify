import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../services/app_settings.dart';
import '../services/cache_cleaner.dart';
import '../services/native_downloads.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../utils/file_types.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'join_parts_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasFileAccess = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _loadVersion();
  }

  Future<void> _showLogs() async {
    final logs = await NativeDownloads.readLogs();
    if (!mounted) return;
    final text = logs.isEmpty ? '(log kosong)' : logs;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log aplikasi'),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Salin'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadVersion() async {
    final version = await NativeDownloads.appVersion();
    if (mounted) setState(() => _version = version);
  }

  Future<void> _checkAccess() async {
    final ok = await NativeDownloads.hasAllFilesAccess();
    if (mounted) setState(() => _hasFileAccess = ok);
  }

  Future<void> _toggleDynamic(bool value) async {
    // Cukup diterapkan langsung: warna diambil ulang dan MaterialApp rebuild.
    await ThemeController.instance.setDynamic(value);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = ThemeController.instance;
    final locale = LocaleController.instance;
    final settings = AppSettings.instance;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(title: s.settings),
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge(
                      [theme, locale, settings, DownloadHistory.instance]),
                  builder: (context, _) {
                    final scheme = AppColors.scheme;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                      children: [
                        Stagger(
                          index: 0,
                          child: SectionLabel(s.appearance),
                        ),
                        Stagger(
                          index: 1,
                          child: _Group(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 14, 14, 4),
                                child: _AppearanceSelector(
                                  value: theme.appearance,
                                  onChanged: (v) => theme.setAppearance(v),
                                ),
                              ),
                              AnimatedSize(
                                duration: Motion.base,
                                curve: Motion.emphasized,
                                alignment: Alignment.topCenter,
                                child: theme.appearance ==
                                        AppAppearance.amoled
                                    ? Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            18, 8, 18, 10),
                                        child: Text(
                                          s.amoledHint,
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      )
                                    : const SizedBox(width: double.infinity),
                              ),
                              const _RowDivider(),
                              _SettingRow(
                                icon: Icons.palette_outlined,
                                title: s.dynamicColor,
                                subtitle: s.dynamicColorHint,
                                onTap: theme.systemAccentAvailable
                                    ? () => _toggleDynamic(!theme.dynamicColor)
                                    : null,
                                trailing: Switch(
                                  value: theme.dynamicColor,
                                  onChanged: theme.systemAccentAvailable
                                      ? _toggleDynamic
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Stagger(
                          index: 2,
                          child: SectionLabel(s.language),
                        ),
                        Stagger(
                          index: 3,
                          child: _Group(
                            children: [
                              _SettingRow(
                                icon: Icons.translate_rounded,
                                title: s.languageFollowSystem,
                                subtitle: locale.deviceLanguageName,
                                selected: locale.mode == AppLanguage.system,
                                onTap: () =>
                                    locale.setMode(AppLanguage.system),
                                trailing: _CheckMark(
                                  on: locale.mode == AppLanguage.system,
                                ),
                              ),
                              const _RowDivider(),
                              _SettingRow(
                                icon: Icons.language_rounded,
                                title: s.languageEnglish,
                                selected: locale.mode == AppLanguage.english,
                                onTap: () =>
                                    locale.setMode(AppLanguage.english),
                                trailing: _CheckMark(
                                  on: locale.mode == AppLanguage.english,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Stagger(
                          index: 4,
                          child: SectionLabel(s.downloadsSection),
                        ),
                        Stagger(
                          index: 5,
                          child: _Group(
                            children: [
                              _SettingRow(
                                icon: Icons.speed_rounded,
                                title: s.connections,
                                trailing: _ValuePill(
                                  label: '${settings.connections}',
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 0, 10, 6),
                                child: Slider(
                                  value: settings.connections.toDouble(),
                                  min: 2,
                                  max: 12,
                                  divisions: 10,
                                  label:
                                      s.connectionsHint(settings.connections),
                                  onChanged: (v) =>
                                      settings.setConnections(v.round()),
                                ),
                              ),
                              const _RowDivider(),
                              _SettingRow(
                                icon: Icons.notifications_active_outlined,
                                title: s.notificationsProgress,
                                subtitle: s.notificationsProgressHint,
                                trailing: Switch(
                                  value: settings.notifications,
                                  onChanged: (v) async {
                                    await settings.setNotifications(v);
                                    if (!v) return;
                                    await NativeDownloads.requestPermissions();
                                  },
                                ),
                              ),
                              const _RowDivider(),
                              _SettingRow(
                                icon: Icons.folder_outlined,
                                title: s.saveFolder,
                                subtitle: NativeDownloads.folderPath,
                              ),
                              const _RowDivider(),
                              _SettingRow(
                                icon: _hasFileAccess
                                    ? Icons.verified_user_outlined
                                    : Icons.gpp_maybe_outlined,
                                title: s.fileAccess,
                                subtitle: _hasFileAccess
                                    ? s.fileAccessGranted
                                    : s.fileAccessMissing,
                                color: _hasFileAccess
                                    ? null
                                    : AppColors.danger,
                                subtitleColor: _hasFileAccess
                                    ? null
                                    : AppColors.danger,
                                trailing: _hasFileAccess
                                    ? null
                                    : IconButton(
                                        onPressed: () async {
                                          await NativeDownloads
                                              .requestAllFilesAccess();
                                          await _checkAccess();
                                        },
                                        icon: Icon(
                                          Icons.settings_outlined,
                                          size: 20,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        tooltip: s.openSettings,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        Stagger(
                          index: 6,
                          child: SectionLabel(s.behaviourSection),
                        ),
                        Stagger(
                          index: 7,
                          child: _Group(
                            children: [
                              _SettingRow(
                                icon: Icons.content_paste_rounded,
                                title: s.clipboardDetect,
                                subtitle: s.clipboardDetectHint,
                                trailing: Switch(
                                  value: settings.clipboardDetect,
                                  onChanged: (v) =>
                                      settings.setClipboardDetect(v),
                                ),
                              ),
                              const _RowDivider(),
                              _SettingRow(
                                icon: Icons.delete_sweep_outlined,
                                title: s.confirmDelete,
                                subtitle: s.confirmDeleteHint,
                                trailing: Switch(
                                  value: settings.confirmDelete,
                                  onChanged: (v) =>
                                      settings.setConfirmDelete(v),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Stagger(
                          index: 8,
                          child: SectionLabel(s.dataSection),
                        ),
                        Stagger(
                          index: 9,
                          child: _Group(
                            children: [
                              _SettingRow(
                                icon: Icons.history_rounded,
                                title: s.downloadHistory,
                                subtitle:
                                    '${DownloadHistory.instance.items.length}',
                                onTap: () => Navigator.push(
                                  context,
                                  SharedAxisPageRoute(
                                      builder: (_) => const HistoryScreen()),
                                ),
                                trailing: const _Chevron(),
                              ),
                              const _RowDivider(),
                              _SettingRow(
                                icon: Icons.merge_type_rounded,
                                title: s.joinParts,
                                subtitle: s.joinPartsHint,
                                onTap: () => Navigator.push(
                                  context,
                                  SharedAxisPageRoute(
                                      builder: (_) =>
                                          const JoinPartsScreen()),
                                ),
                                trailing: const _Chevron(),
                              ),
                              const _RowDivider(),
                              _SettingRow(
                                icon: Icons.cleaning_services_outlined,
                                title: s.clearCache,
                                onTap: () async {
                                  final freed =
                                      await CacheCleaner.clearTempCache();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${s.cacheCleared} · ${formatSize(freed)}'),
                                    ),
                                  );
                                },
                                trailing: const _Chevron(),
                              ),
                              const _RowDivider(),
                              _SettingRow(
                                icon: Icons.delete_forever_outlined,
                                title: s.clearHistory,
                                color: AppColors.danger,
                                onTap: () => DownloadHistory.instance.clear(),
                                trailing: const _Chevron(),
                              ),
                            ],
                          ),
                        ),
                        Stagger(
                          index: 10,
                          child: SectionLabel(s.about),
                        ),
                        Stagger(
                          index: 11,
                          child: _Group(
                            children: [
                              _SettingRow(
                                icon: Icons.info_outline_rounded,
                                title: s.appName,
                                subtitle: '${s.version} '
                                    '${_version.isEmpty ? '…' : _version}',
                              ),
                              _SettingRow(
                                icon: Icons.bug_report_outlined,
                                title: 'Log aplikasi',
                                subtitle: 'dropify.log + crash.log',
                                onTap: _showLogs,
                                trailing: const _Chevron(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu grup pengaturan M3: satu permukaan tonal dengan baris dipisah garis.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Surface(
      radius: AppRadii.xl,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: children),
    );
  }
}

/// Header layar: tombol kembali tonal + judul tebal.
class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 18, 10),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.base,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, if (current != null) current],
              ),
              child: Text(
                title,
                key: ValueKey(title),
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
          ),
        ],
      ),
    );
  }
}

/// Pemilih tampilan 3 arah M3: Terang / Gelap / AMOLED.
class _AppearanceSelector extends StatelessWidget {
  const _AppearanceSelector({required this.value, required this.onChanged});

  final AppAppearance value;
  final ValueChanged<AppAppearance> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final options = <(AppAppearance, String, IconData)>[
      (AppAppearance.light, s.themeLight, Icons.light_mode_rounded),
      (AppAppearance.dark, s.themeDark, Icons.dark_mode_rounded),
      (AppAppearance.amoled, s.themeAmoled, Icons.contrast_rounded),
    ];

    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1);

    return SegmentedButton<AppAppearance>(
      segments: [
        for (final option in options)
          ButtonSegment<AppAppearance>(
            value: option.$1,
            label: Text(
              option.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
            icon: Icon(option.$3, size: 17),
          ),
      ],
      selected: {value},
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        tapFeedback();
        onChanged(selection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 6),
        ),
        iconAlignment: IconAlignment.start,
        textStyle: WidgetStatePropertyAll(labelStyle),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 58, right: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.scheme.outlineVariant,
      ),
    );
  }
}

/// Pill nilai kecil (mis. jumlah koneksi) di sisi kanan baris.
class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.spring,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSecondaryContainer,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: Motion.base,
      curve: Motion.spring,
      scale: on ? 1 : 0.7,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: on ? 1 : 0,
        child: Icon(Icons.check_circle_rounded,
            size: 22, color: AppColors.scheme.primary),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.chevron_right_rounded,
        color: AppColors.scheme.onSurfaceVariant, size: 22);
  }
}

/// Satu baris pengaturan: ikon tonal, judul, sub-judul, dan trailing.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
    this.subtitleColor,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
  final Color? subtitleColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
      child: Row(
        children: [
          GlowIcon(
            icon: icon,
            size: 40,
            color: color ?? scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: -0.1,
                    color: color ?? AppColors.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subtitleColor ?? scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          tapFeedback();
          onTap!();
        },
        splashColor: scheme.primary.withValues(alpha: 0.08),
        highlightColor: scheme.primary.withValues(alpha: 0.05),
        child: content,
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _open(BuildContext context, DownloadRecord record) async {
    final ok = await NativeDownloads.openPath(record.path);
    if (!ok && context.mounted) {
      showAppSnack(context, '${context.s.openFileFailed} ${record.path}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(title: s.downloadHistory),
              Expanded(
                child: ListenableBuilder(
                  listenable: DownloadHistory.instance,
                  builder: (context, _) {
                    final items = DownloadHistory.instance.items;
                    return AnimatedSwitcher(
                      duration: Motion.base,
                      child: items.isEmpty
                          ? ListView(
                              key: const ValueKey('empty'),
                              padding:
                                  const EdgeInsets.fromLTRB(18, 8, 18, 24),
                              children: [
                                Stagger(
                                  child: DashedPanel(
                                    radius: AppRadii.xl,
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 30, 20, 26),
                                    child: Column(
                                      children: [
                                        const OrbIcon(
                                          icon: Icons.history_rounded,
                                          size: 96,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          s.noHistory,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors
                                                .scheme.onSurfaceVariant,
                                            fontSize: 13.5,
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
                                  const EdgeInsets.fromLTRB(18, 4, 18, 24),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final record = items[i];
                                return Stagger(
                                  index: i,
                                  step: const Duration(milliseconds: 35),
                                  child: _HistoryTile(
                                    record: record,
                                    onOpen: () => _open(context, record),
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, required this.onOpen});

  final DownloadRecord record;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = AppColors.scheme;
    final exists = File(record.path).existsSync();
    return Surface(
      radius: AppRadii.lg,
      padding: EdgeInsets.zero,
      clip: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            GlowIcon(
              icon: exists
                  ? Icons.insert_drive_file_outlined
                  : Icons.file_present_outlined,
              size: 44,
              color: exists ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: InkWell(
                onTap: onOpen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatSize(record.size)} · ${formatDate(record.time)}',
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
            ),
            PopupMenuButton<String>(
              color: AppColors.cardHigh,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              icon: Icon(Icons.more_vert_rounded,
                  color: scheme.onSurfaceVariant, size: 20),
              onSelected: (value) async {
                switch (value) {
                  case 'open':
                    onOpen();
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
                      style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
