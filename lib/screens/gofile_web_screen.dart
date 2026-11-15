import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../services/download_service.dart';
import '../services/pixeldrain_api.dart';
import '../services/web_download_links.dart';
import '../theme/app_theme.dart';
import '../widgets/kit.dart';

/// Gofile di dalam aplikasi: memakai sesi web resmi mereka, tapi tampilan
/// diselaraskan dengan tema aplikasi (warna, radius, header sendiri).
///
/// Unduhan yang dimulai dari halaman Gofile tidak diserahkan ke downloader
/// browser WebView, melainkan diteruskan ke [DownloadService] aplikasi:
/// - `WebView.setDownloadListener` Android (lewat `NavigationDelegate
///   .onNavigationRequest` di webview_flutter_android) menangkap tautan berkas
///   maupun respons `Content-Disposition: attachment`.
/// - Kait JavaScript kecil di halaman menangkap klik `<a download>` dan
///   `window.open` untuk URL yang sama, sekaligus memberi nama berkas asli.
///
/// Hasilnya tampil di pill progres HomeTab dan sheet Transfers, dengan
/// notifikasi sistem dari TransferService seperti unduhan Pixeldrain.
class GofileWebScreen extends StatefulWidget {
  const GofileWebScreen({super.key, this.url, this.token});

  final String? url;

  /// Token akun Gofile dari app; dipakai untuk login di web supaya sesi yang
  /// terbuka adalah akun pengguna, bukan akun guest.
  final String? token;

  @override
  State<GofileWebScreen> createState() => _GofileWebScreenState();
}

class _GofileWebScreenState extends State<GofileWebScreen> {
  /// Kanal JS → Dart untuk tautan unduhan (lebih akurat daripada URL saja).
  static const String _jsChannel = 'DropifyWebDownload';

  late final WebViewController _web;

  /// Dipakai hanya kalau layar ini dibuka tanpa DriveController.
  DownloadService? _ownDownloads;

  /// URL yang sudah diteruskan, supaya satu klik tidak masuk dua kali
  /// (DownloadListener + kait JS).
  final Set<String> _handled = <String>{};

  /// Unduhan masuk ke service milik layar utama supaya pill HomeTab dan sheet
  /// Transfers menampilkannya; kalau belum ada, pakai instance sendiri.
  DownloadService get _downloads {
    final shared = DownloadService.shared;
    return shared ?? (_ownDownloads ??= DownloadService(PixeldrainApi()));
  }

  String get _startUrl => widget.token != null && widget.token!.isNotEmpty
      ? 'https://gofile.io/login/${widget.token}'
      : (widget.url ?? 'https://gofile.io/');

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
      ..addJavaScriptChannel(_jsChannel, onMessageReceived: _onJsMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _onPageFinished(),
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(_startUrl));
  }

  @override
  void dispose() {
    _ownDownloads?.dispose();
    super.dispose();
  }

  Future<void> _onPageFinished() async {
    await _applyTheme();
    await _installDownloadHooks();
  }

  /// Selaraskan tampilan Gofile dengan tema aplikasi: warna permukaan, sudut
  /// membulat, font, dan sembunyikan elemen navigasi mereka yang redundan.
  Future<void> _applyTheme() async {
    final scheme = AppColors.scheme;
    String hex(Color c) =>
        '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    final css = '''
      :root { color-scheme: ${AppColors.isDark ? 'dark' : 'light'}; }
      body { background: ${hex(AppColors.bg)} !important;
             color: ${hex(scheme.onSurface)} !important;
             font-family: -apple-system, Roboto, sans-serif !important; }
      header, nav, [data-nav], .sidebar { background: transparent !important; }
      .panel, .card, [class*="rounded"] {
        border-radius: 28px !important;
        background: ${hex(scheme.surfaceContainerLow)} !important;
        border-color: ${hex(scheme.outlineVariant)} !important;
      }
      a, button, [role="button"] { border-radius: 999px !important; }
      .btn-primary, [class*="primary"] {
        background: ${hex(scheme.primary)} !important;
        color: ${hex(scheme.onPrimary)} !important;
      }
    ''';
    await _web.runJavaScript('''
      (function() {
        var style = document.getElementById('dropify-theme');
        if (!style) {
          style = document.createElement('style');
          style.id = 'dropify-theme';
          document.head.appendChild(style);
        }
        style.textContent = `$css`;
      })();
    ''');
  }

  /// Kait unduhan di halaman: klik tautan berkas dan `window.open` dikirim ke
  /// Dart. Tidak menyentuh apa pun yang bukan tautan berkas Gofile.
  Future<void> _installDownloadHooks() async {
    const script = r'''
      (function () {
        if (window.__dropifyDownloadHooks) return;
        window.__dropifyDownloadHooks = true;

        function send(url, name) {
          try {
            DropifyWebDownload.postMessage(JSON.stringify({
              url: String(url || ''),
              name: name ? String(name) : ''
            }));
          } catch (e) {}
        }

        function isFileUrl(url) {
          if (!/^https?:\/\//i.test(url || '')) return false;
          if (/gofile\.io\/download/i.test(url)) return true;
          return /[?&]download(=|&|$)/i.test(url);
        }

        function anchorOf(node) {
          while (node && node.tagName !== 'A') node = node.parentElement;
          return node;
        }

        document.addEventListener('click', function (event) {
          var a = anchorOf(event.target);
          if (!a || !a.href) return;
          if (!a.hasAttribute('download') && !isFileUrl(a.href)) return;
          if (/^(blob|data):/i.test(a.href)) return;
          event.preventDefault();
          event.stopPropagation();
          send(a.href, a.getAttribute('download') || a.getAttribute('title') || '');
        }, true);

        var open = window.open;
        window.open = function (url) {
          if (typeof url === 'string' && isFileUrl(url)) {
            send(url, '');
            return null;
          }
          return open.apply(window, arguments);
        };
      })();
    ''';
    try {
      await _web.runJavaScript(script);
    } catch (_) {
      // Halaman belum siap / JS dimatikan; jalur DownloadListener tetap jalan.
    }
  }

  /// Dipanggil webview_flutter_android untuk setiap navigasi bingkai utama —
  /// termasuk awal unduhan dari `DownloadListener`.
  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    if (WebDownloadLinks.isGofileDownloadUrl(request.url)) {
      unawaited(_startDownload(request.url));
      // Jangan muat berkasnya di WebView; biarkan halaman tetap terbuka.
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _onJsMessage(JavaScriptMessage message) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final url = (data['url'] ?? '').toString();
    if (!WebDownloadLinks.isDownloadable(url)) return;
    unawaited(_startDownload(url, preferredName: (data['name'] ?? '').toString()));
  }

  /// Teruskan URL berkas ke DownloadService aplikasi.
  Future<void> _startDownload(String url, {String? preferredName}) async {
    if (!WebDownloadLinks.isDownloadable(url)) return;
    if (!_handled.add(url)) return;
    // DownloadListener dan kait JS bisa melaporkan klik yang sama; setelah
    // beberapa detik URL dilepas lagi supaya bisa diunduh ulang.
    Timer(const Duration(seconds: 4), () => _handled.remove(url));

    final s = context.s;
    final name = WebDownloadLinks.fileNameFromUrl(url, preferred: preferredName);
    final headers = await _cookieHeaders(url);

    if (!mounted) return;
    HapticFeedback.selectionClick();
    showAppSnack(context, s.downloadStartedSnack(name));

    final task = await _downloads.download(
      PdItem(name: name, size: 0),
      urlOverride: url,
      headers: headers,
    );

    if (!mounted) return;
    if (task == null || task.status == DownloadStatus.error) {
      showAppSnack(
        context,
        s.downloadFailedSnack(name, task?.error ?? s.downloadFailed),
      );
    }
  }

  /// Cookie sesi WebView (login Gofile) ikut dikirim ke permintaan unduhan,
  /// supaya berkas akun — bukan hanya tautan guest — bisa diambil.
  Future<Map<String, String>> _cookieHeaders(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return const {};
    try {
      final cookies = await WebViewCookieManager().platform.getCookies(uri);
      if (cookies.isEmpty) return const {};
      return {
        'Cookie': cookies.map((c) => '${c.name}=${c.value}').join('; '),
      };
    } catch (_) {
      return const {};
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
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gofile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => _web.reload(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
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
