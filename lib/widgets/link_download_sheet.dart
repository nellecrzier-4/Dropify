import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../services/pd_link.dart';
import '../theme/app_theme.dart';
import 'kit.dart';
import 'motion.dart';
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

    final scheme = AppColors.scheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stagger(
              child: Row(
                children: [
                  GlowIcon(
                    icon: Icons.link_rounded,
                    size: 44,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.downloadFromLink,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          s.linkAlbumNote,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Stagger(
              index: 1,
              child: TextField(
                controller: _text,
                autofocus: true,
                keyboardType: TextInputType.url,
                style: TextStyle(color: AppColors.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: s.linkHint,
                  prefixIcon: const Icon(Icons.public_rounded, size: 20),
                  suffixIcon: TextButton(
                    onPressed: _paste,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.primary,
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
            ),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.emphasized,
              alignment: Alignment.topCenter,
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: scheme.onErrorContainer, size: 18),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: scheme.onErrorContainer,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Stagger(
              index: 2,
              child: PrimaryButton(
                label: s.download,
                icon: Icons.download_rounded,
                loading: _busy,
                onPressed: _busy ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
