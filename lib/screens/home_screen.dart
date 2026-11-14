import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../services/app_settings.dart';
import '../services/pd_link.dart';
import '../services/pixeldrain_api.dart';
import '../theme/app_theme.dart';
import '../widgets/kit.dart';
import '../widgets/link_download_sheet.dart';
import '../widgets/motion.dart';
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
      SharedAxisPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _showAddMenu() async {
    final s = context.s;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AddMenuSheet(
        title: s.addNew,
        children: [
          _SheetAction(
            icon: Icons.upload_file_rounded,
            title: s.uploadFile,
            onTap: () {
              Navigator.pop(sheetContext);
              _upload();
            },
          ),
          _SheetAction(
            icon: Icons.link_rounded,
            title: s.downloadFromLink,
            subtitle: s.linkAlbumNote,
            onTap: () {
              Navigator.pop(sheetContext);
              showLinkDownloadSheet(context, _ctrl);
            },
          ),
        ],
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
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Semua elemen mengapung di atas konten: nav pill benar-benar memblur
      // daftar file yang lewat di belakangnya, bukan latar kosong.
      body: Stack(
        children: [
          Positioned.fill(
            child: AuroraBackground(
              child: AnimatedIndexedStack(
                index: _index,
                children: [
                  HomeTab(ctrl: _ctrl, onLogout: _logout),
                  FilesTab(ctrl: _ctrl),
                  PhotosTab(ctrl: _ctrl),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassNav(
                  index: _index,
                  onTap: (i) {
                    setState(() => _index = i);
                    // Segarkan saat pindah tab supaya upload baru langsung terlihat.
                    if (!_ctrl.loading) _ctrl.refresh();
                  },
                  items: [
                    GlassNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: s.home,
                    ),
                    GlassNavItem(
                      icon: Icons.folder_open_rounded,
                      activeIcon: Icons.folder_rounded,
                      label: s.files,
                    ),
                    GlassNavItem(
                      icon: Icons.photo_library_outlined,
                      activeIcon: Icons.photo_library_rounded,
                      label: s.photos,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 92 + safeBottom,
            child: _AddFab(onTap: _showAddMenu),
          ),
        ],
      ),
    );
  }
}

/// Tombol aksi melayang M3: tonal (primary container), sudut 18, bayangan
/// lembut, dan mengecil saat ditekan.
class _AddFab extends StatelessWidget {
  const _AddFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.md - 2),
          boxShadow: AppColors.shadowMd,
        ),
        child: Icon(
          Icons.add_rounded,
          size: 28,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Panel bawah M3: drag handle & sudut 32 dari tema, judul tebal, baris berikon.
class _AddMenuSheet extends StatelessWidget {
  const _AddMenuSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
        child: Row(
          children: [
            GlowIcon(
              icon: icon,
              size: 44,
              color: AppColors.scheme.primary,
            ),
            const SizedBox(width: 14),
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
                      color: AppColors.text,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.scheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
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
