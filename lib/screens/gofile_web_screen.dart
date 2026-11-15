import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';

/// Gofile di dalam aplikasi: memakai sesi web resmi mereka, tapi tampilan
/// diselaraskan dengan tema aplikasi (warna, radius, header sendiri).
class GofileWebScreen extends StatefulWidget {
  const GofileWebScreen({super.key, this.url});

  final String? url;

  @override
  State<GofileWebScreen> createState() => _GofileWebScreenState();
}

class _GofileWebScreenState extends State<GofileWebScreen> {
  late final WebViewController _web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(AppColors.bg)
    ..setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) => _applyTheme(),
      ),
    )
    ..loadRequest(Uri.parse(widget.url ?? 'https://gofile.io/'));

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
