import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/drive_controller.dart';
import '../services/app_settings.dart';
import '../services/pd_link.dart';
import '../l10n/locale_controller.dart';
import '../services/pixeldrain_api.dart';
import '../theme/app_theme.dart';
import '../widgets/link_download_sheet.dart';
import '../widgets/transfers_sheet.dart';
import 'files_tab.dart';
import 'home_tab.dart';
import 'login_screen.dart';
import 'photos_tab.dart';

class HomeScreen extends StatefulWidget {
  final PixeldrainApi api;
  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DriveController _ctrl = DriveController(widget.api);
  int _index = 0;

  static String? _lastOfferedLink;

  @override
  void initState() {
    super.initState();
    _ctrl.refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerClipboardLink());
  }

  Future<void> _offerClipboardLink() async {
    if (!AppSettings.instance.clipboardDetect) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || text == _lastOfferedLink) return;
    if (PdLink.parse(text) == null) return;
    _lastOfferedLink = text;
    if (!mounted) return;
    final s = context.s;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.clipboardFound),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: s.download,
          onPressed: () =>
              showLinkDownloadSheet(context, _ctrl, initialLink: text),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _showAddMenu() async {
    final s = context.s;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.addNew,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.upload_file, color: AppColors.primary),
              title: Text(s.uploadFile),
              onTap: () {
                Navigator.pop(sheetContext);
                _upload();
              },
            ),
            ListTile(
              leading: Icon(Icons.link, color: AppColors.primary),
              title: Text(s.downloadFromLink),
              subtitle: Text(
                s.linkAlbumNote,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                showLinkDownloadSheet(context, _ctrl);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _upload() async {
    showTransfers(context, _ctrl, initialTab: 1);
    await _ctrl.pickAndUpload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeTab(ctrl: _ctrl, onLogout: _logout),
          FilesTab(ctrl: _ctrl),
          PhotosTab(ctrl: _ctrl),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: _FloatingNav(
                  index: _index,
                  labels: [s.home, s.files, s.photos],
                  onSelect: (i) {
                    setState(() => _index = i);
                    if (!_ctrl.loading) _ctrl.refresh();
                  },
                ),
              ),
              const SizedBox(width: 12),
              _FabCircle(onTap: _showAddMenu),
            ],
          ),
        ),
      ),
    );
  }
}


class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.index,
    required this.labels,
    required this.onSelect,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onSelect;

  static const _icons = [Icons.home_rounded, Icons.folder_rounded, Icons.photo_rounded];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.cardHigh,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _icons[i],
                        size: 22,
                        color: i == index
                            ? AppColors.onPrimary
                            : AppColors.muted,
                      ),
                      if (i == index) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.onPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

class _FabCircle extends StatelessWidget {
  const _FabCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(Icons.add, size: 30, color: AppColors.onPrimary),
      ),
    );
  }
}
