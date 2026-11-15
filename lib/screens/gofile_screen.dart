import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/gofile_controller.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../services/download_service.dart';
import '../services/gofile_api.dart';
import '../services/pixeldrain_api.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';

/// Layar akun Gofile: login (email → tautan masuk) lalu daftar file akun.
class GofileScreen extends StatefulWidget {
  const GofileScreen({super.key, this.controller, this.folderId, this.title});

  final GofileController? controller;
  final String? folderId;
  final String? title;

  @override
  State<GofileScreen> createState() => _GofileScreenState();
}

class _GofileScreenState extends State<GofileScreen> {
  late final GofileController _ctrl = widget.controller ?? GofileController();
  late final DownloadService _downloads = DownloadService(PixeldrainApi());

  final _email = TextEditingController();
  final _token = TextEditingController();

  bool _ownController = false;
  bool _loadingFolder = false;
  List<GofileEntry>? _folderEntries;
  String? _folderError;

  @override
  void initState() {
    super.initState();
    _ownController = widget.controller == null;
    if (widget.folderId == null) _ctrl.load();
  }

  @override
  void dispose() {
    if (_ownController) _ctrl.dispose();
    _downloads.dispose();
    _email.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _openFolder(GofileEntry entry) async {
    await Navigator.of(context).push(
      SharedAxisPageRoute<void>(
        builder: (_) => GofileScreen(
          controller: _ctrl,
          folderId: entry.id,
          title: entry.name,
        ),
      ),
    );
  }

  Future<void> _loadFolder() async {
    setState(() {
      _loadingFolder = true;
      _folderError = null;
    });
    try {
      final entries = await _ctrl.folder(widget.folderId!);
      if (mounted) setState(() => _folderEntries = entries);
    } catch (e) {
      if (mounted) setState(() => _folderError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingFolder = false);
    }
  }

  Future<void> _download(GofileEntry entry) async {
    final s = context.s;
    if (entry.link == null || entry.link!.isEmpty) {
      showAppSnack(context, s.downloadFailedSnack(entry.name, 'link'));
      return;
    }
    HapticFeedback.selectionClick();
    final task = await _downloads.download(
      PdItem(name: entry.name, size: entry.size, mime: ''),
      urlOverride: entry.link,
    );
    if (!mounted) return;
    if (task == null || task.status == DownloadStatus.error) {
      showAppSnack(
        context,
        s.downloadFailedSnack(entry.name, task?.error ?? 'gagal'),
      );
    } else {
      showAppSnack(context, s.downloadingSnack(entry.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final isRoot = widget.folderId == null;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                title: widget.title ?? 'Gofile',
                onBack: isRoot ? null : () => Navigator.of(context).maybePop(),
                action: _ctrl.loggedIn
                    ? IconButton(
                        tooltip: s.logout,
                        onPressed: () async {
                          await _ctrl.logout();
                          if (isRoot && mounted) setState(() {});
                        },
                        icon: const Icon(Icons.logout_rounded),
                      )
                    : null,
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: _ctrl,
                  builder: (context, _) {
                    if (!_ctrl.loggedIn) {
                      return _LoginBody(
                        controller: _ctrl,
                        email: _email,
                        token: _token,
                      );
                    }
                    return _FileBody(
                      controller: _ctrl,
                      folderId: widget.folderId,
                      folderTitle: widget.title,
                      entries: _folderEntries,
                      loadingFolder: _loadingFolder,
                      folderError: _folderError,
                      onLoadFolder: _loadFolder,
                      onOpenFolder: _openFolder,
                      onDownload: _download,
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

class _Header extends StatelessWidget {
  const _Header({required this.title, this.onBack, this.action});

  final String title;
  final VoidCallback? onBack;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          if (onBack != null)
            IconButton.filledTonal(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            GlowIcon(
              icon: Icons.folder_shared_rounded,
              size: 44,
              color: AppColors.scheme.primary,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody({
    required this.controller,
    required this.email,
    required this.token,
  });

  final GofileController controller;
  final TextEditingController email;
  final TextEditingController token;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = AppColors.scheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
      children: [
        Stagger(
          index: 0,
          child: Surface(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.gofileIntro,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: s.gofileEmailHint,
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: s.gofileSendLink,
                  icon: Icons.send_rounded,
                  loading: controller.loading,
                  onPressed: () => controller.sendLoginLink(email.text),
                ),
                if (controller.linkSent) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Text(
                      s.gofileLinkSent,
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Stagger(
          index: 1,
          child: Surface(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: token,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: s.gofilePasteHint,
                    prefixIcon: const Icon(Icons.key_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: s.signIn,
                  tonal: true,
                  icon: Icons.login_rounded,
                  onPressed: () => controller.useToken(token.text),
                ),
                const SizedBox(height: 10),
                Text(
                  s.gofileGuestNote,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (controller.error != null) ...[
          const SizedBox(height: 14),
          Text(
            controller.error!,
            style: TextStyle(color: scheme.error, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _FileBody extends StatelessWidget {
  const _FileBody({
    required this.controller,
    required this.folderId,
    required this.folderTitle,
    required this.entries,
    required this.loadingFolder,
    required this.folderError,
    required this.onLoadFolder,
    required this.onOpenFolder,
    required this.onDownload,
  });

  final GofileController controller;
  final String? folderId;
  final String? folderTitle;
  final List<GofileEntry>? entries;
  final bool loadingFolder;
  final String? folderError;
  final VoidCallback onLoadFolder;
  final ValueChanged<GofileEntry> onOpenFolder;
  final ValueChanged<GofileEntry> onDownload;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = AppColors.scheme;
    final list = folderId == null ? controller.entries : (entries ?? const []);
    final loading = folderId == null ? controller.loading : loadingFolder;

    return RefreshIndicator(
      onRefresh: () async {
        if (folderId == null) {
          await controller.refresh();
        } else {
          onLoadFolder();
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          if (folderId == null) ...[
            Surface(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  GlowIcon(
                    icon: Icons.cloud_rounded,
                    size: 46,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.account?.email.isNotEmpty == true
                              ? controller.account!.email
                              : s.gofileSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatSize(controller.account?.storage ?? 0)} · '
                          '${controller.account?.tier ?? 'guest'}',
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
            ),
            const SizedBox(height: 10),
          ],
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: DashedPanel(
                child: Column(
                  children: [
                    const OrbIcon(icon: Icons.cloud_off_rounded, size: 88),
                    const SizedBox(height: 12),
                    Text(
                      folderError ?? s.gofileEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    if (folderError != null) ...[
                      const SizedBox(height: 10),
                      TextButton(onPressed: onLoadFolder, child: Text(s.retry)),
                    ],
                  ],
                ),
              ),
            )
          else
            for (var i = 0; i < list.length; i++)
              Stagger(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Surface(
                    radius: AppRadii.lg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    onTap: list[i].isDir
                        ? () => onOpenFolder(list[i])
                        : () => onDownload(list[i]),
                    child: Row(
                      children: [
                        GlowIcon(
                          icon: list[i].isDir
                              ? Icons.folder_rounded
                              : Icons.insert_drive_file_rounded,
                          size: 44,
                          color: list[i].isDir
                              ? scheme.primary
                              : AppColors.other,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                list[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                list[i].isDir
                                    ? 'Folder'
                                    : formatSize(list[i].size),
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          list[i].isDir
                              ? Icons.chevron_right_rounded
                              : Icons.download_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
