import 'package:flutter/material.dart';

import '../services/proxy_picker.dart';
import '../services/proxy_service.dart';
import '../theme/app_theme.dart';
import '../widgets/kit.dart';

/// Daftar proxy (ID/MY/SG/SG) yang bisa dicari dan dipilih satu.
class ProxyPickerScreen extends StatefulWidget {
  const ProxyPickerScreen({super.key});

  @override
  State<ProxyPickerScreen> createState() => _ProxyPickerScreenState();
}

class _ProxyPickerScreenState extends State<ProxyPickerScreen> {
  final TextEditingController _query = TextEditingController();
  List<String> _all = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ProxyCatalog.fetch(limit: 24);
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<String> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((p) => p.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    final items = _filtered;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 6),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pilih proxy',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Muat ulang',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Cari alamat proxy…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _query.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _loading
                    ? 'Mengambil daftar…'
                    : '${items.length} proxy · ketuk untuk memakai',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Gagal mengambil daftar: $_error',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.error, fontSize: 12.5),
                            ),
                          ),
                        )
                      : items.isEmpty
                          ? Center(
                              child: Text(
                                'Tidak ada proxy yang cocok.',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final proxy = items[i];
                                final selected =
                                    ProxyService.instance.current == proxy;
                                return Surface(
                                  radius: AppRadii.lg,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  onTap: () async {
                                    await ProxyService.instance.useSingle(proxy);
                                    if (context.mounted) {
                                      Navigator.of(context).pop(proxy);
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        selected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                        size: 20,
                                        color: selected
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          proxy,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
