import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../services/pd_link.dart';
import '../theme/app_theme.dart';
import 'transfers_sheet.dart';

/// Bottom sheet untuk mengunduh file orang lain lewat link Pixeldrain.
Future<void> showLinkDownloadSheet(
  BuildContext context,
  DriveController ctrl, {
  String? initialLink,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _LinkSheet(ctrl: ctrl, initialLink: initialLink),
    ),
  );
}

class _LinkSheet extends StatefulWidget {
  const _LinkSheet({required this.ctrl, this.initialLink});

  final DriveController ctrl;
  final String? initialLink;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initialLink ?? '');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim();
    if (value == null || value.isEmpty) return;
    setState(() {
      _text.text = value;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final s = context.s;
    final link = PdLink.parse(_text.text);
    if (link == null) {
      setState(() => _error = s.invalidLink);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      PdItem item;
      if (link.isFile) {
        final info = await widget.ctrl.api.getFileInfo(link.id);
        if (!mounted) return;
        if (info == null) {
          setState(() {
            _busy = false;
            _error = s.linkNotFound;
          });
          return;
        }
        item = PdItem(
          id: link.id,
          name: (info['name'] ?? link.id).toString(),
          size: (info['size'] as num?)?.toInt() ?? 0,
          mime: (info['mime_type'] ?? '').toString(),
        );
      } else {
        item = PdItem(name: '${link.id}.zip');
      }

      final task = await widget.ctrl.downloads.download(
        item,
        urlOverride: link.bypassUrl,
      );
      if (!mounted) return;
      Navigator.pop(context);

      if (task != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.download} ${task.name}'),
            action: SnackBarAction(
              label: s.downloads,
              onPressed: () => showTransfers(context, widget.ctrl),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.link, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  s.downloadFromLink,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              s.linkAlbumNote,
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              autofocus: true,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: s.linkHint,
                prefixIcon: const Icon(Icons.public, size: 20),
                suffixIcon: TextButton(
                  onPressed: _paste,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(s.paste),
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text(s.download),
            ),
          ],
        ),
      ),
    );
  }
}
