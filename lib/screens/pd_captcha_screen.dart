import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/pd_session.dart';
import '../theme/app_theme.dart';

/// Halaman resmi Pixeldrain untuk menyelesaikan verifikasi captcha.
///
/// Pengguna menyelesaikan tantangannya sendiri seperti di browser; setelah
/// selesai, cookie sesi diambil dan dipakai untuk melanjutkan unduhan.
class PdCaptchaScreen extends StatefulWidget {
  const PdCaptchaScreen({super.key, required this.fileId});

  final String fileId;

  @override
  State<PdCaptchaScreen> createState() => _PdCaptchaScreenState();
}

class _PdCaptchaScreenState extends State<PdCaptchaScreen> {
  late final WebViewController _web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(AppColors.bg)
    ..loadRequest(
      Uri.parse('https://pixeldrain.com/u/${widget.fileId}'),
    );

  bool _busy = false;

  /// Ambil cookie pixeldrain.com dari WebView lalu kembali ke pemanggil.
  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final cookies =
          await WebViewCookieManager().platform.getCookies(
        Uri.parse('https://pixeldrain.com/'),
      );
      final value = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      await PdSession.instance.save(value);
      if (!mounted) return;
      Navigator.of(context).pop(value.isNotEmpty);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(false),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verifikasi Pixeldrain',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _finish,
                    child: const Text('Selesai'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text(
                'Selesaikan verifikasi di halaman ini, lalu tekan Selesai. '
                'Unduhan akan dilanjutkan dengan sesi yang kamu buat.',
                style: TextStyle(
                  color: AppColors.scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.xl),
                ),
                child: WebViewWidget(controller: _web),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
