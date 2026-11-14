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
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          onPressed: _showAddMenu,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: const Icon(Icons.add, size: 32),
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: AppColors.bg,
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              setState(() => _index = i);
              // Segarkan saat pindah tab supaya upload baru langsung terlihat.
              if (!_ctrl.loading) _ctrl.refresh();
            },
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(
                  icon: const Icon(Icons.folder_open), label: s.files),
              NavigationDestination(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: s.photos),
            ],
          ),
        ),
      ),
    );
  }
}
