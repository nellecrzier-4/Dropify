import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/pd_session.dart';
import '../services/web_download_links.dart';
import '../theme/app_theme.dart';

/// Halaman resmi Pixeldrain untuk menyelesaikan verifikasi captcha.
///
/// Pengguna menyelesaikan tantangannya sendiri seperti di browser; setelah
/// selesai, cookie sesi diambil dan dipakai untuk melanjutkan unduhan.
/// Hasil verifikasi: tautan unduhan yang dipakai halaman + cookie sesinya.
class PdCaptchaResult {
  const PdCaptchaResult({this.url, this.cookie});

  final String? url;
  final String? cookie;
}

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
    ..setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: _onNavigation,
        onPageFinished: (_) => _installDownloadHook(),
      ),
    )
    ..loadRequest(
      Uri.parse('https://pixeldrain.com/u/${widget.fileId}'),
    );

  /// Tangkap tombol Download di halaman: tautannya dipakai apa adanya
  /// (termasuk token hasil captcha) bersama cookie sesi.
  NavigationDecision _onNavigation(NavigationRequest request) {
    if (WebDownloadLinks.isPixeldrainDownloadUrl(request.url)) {
      unawaited(_finishWithUrl(request.url));
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _installDownloadHook() async {
    try {
      await _web.runJavaScript('''
        (function () {
          if (window.__dropifyPdHook) return;
          window.__dropifyPdHook = true;
          document.addEventListener('click', function (ev) {
            var a = ev.target;
            while (a && a.tagName !== 'A') a = a.parentElement;
            if (!a || !a.href) return;
            if (!/\\/api\/file\//.test(a.href) && !/download/i.test(a.href)) return;
            ev.preventDefault();
            ev.stopPropagation();
            window.location.href = a.href;
          }, true);
        })();
      ''');
    } catch (_) {}
  }

  bool _busy = false;

  /// Ambil cookie lalu kembali dengan tautan yang baru saja dipakai halaman.
  Future<void> _finishWithUrl(String url) async {
    final cookie = await _cookies();
    if (!mounted) return;
    Navigator.of(context).pop(PdCaptchaResult(url: url, cookie: cookie));
  }

  Future<String?> _cookies() async {
    try {
      final cookies = await WebViewCookieManager().platform.getCookies(
        Uri.parse('https://pixeldrain.com/'),
      );
      final value = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      if (value.isNotEmpty) await PdSession.instance.save(value);
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  /// Ambil cookie pixeldrain.com dari WebView lalu kembali ke pemanggil.
  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final value = await _cookies();
      if (!mounted) return;
      Navigator.of(context).pop(PdCaptchaResult(cookie: value));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(const PdCaptchaResult());
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
                    onPressed: () =>
                        Navigator.of(context).maybePop(const PdCaptchaResult()),
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
