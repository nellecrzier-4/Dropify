import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import '../widgets/file_actions.dart';
import '../widgets/file_tile.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';

enum _SortField { date, name, size }

/// Daftar file: semua file, satu kategori, atau hasil pencarian.
class FileListScreen extends StatefulWidget {
  final DriveController ctrl;
  final String? title;
  final FileCategory? category;
  final bool search;

  const FileListScreen({
    super.key,
    required this.ctrl,
    this.title,
    this.category,
    this.search = false,
  });

  @override
  State<FileListScreen> createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  String _query = '';
  _SortField _sort = _SortField.date;
  bool _ascending = false;
  bool _grid = false;

  List<PdItem> _items() {
    var list = widget.ctrl.files.toList();
    if (widget.category != null) {
      list = list.where((f) => f.category == widget.category).toList();
    }
    if (widget.search) {
      if (_query.trim().isEmpty) return [];
      final q = _query.trim().toLowerCase();
      list = list.where((f) => f.name.toLowerCase().contains(q)).toList();
    }

    int compare(PdItem a, PdItem b) {
      switch (_sort) {
        case _SortField.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SortField.size:
          return a.size.compareTo(b.size);
        case _SortField.date:
          return (a.date ?? DateTime(1970))
              .compareTo(b.date ?? DateTime(1970));
      }
    }

    list.sort((a, b) => _ascending ? compare(a, b) : compare(b, a));
    return list;
  }

  PopupMenuButton<_SortField> _sortMenu(AppStrings s) {
    return PopupMenuButton<_SortField>(
      color: AppColors.cardHigh,
      elevation: 0,
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      tooltip: s.sortBy,
      onSelected: (value) => setState(() {
        tapFeedback();
        if (_sort == value) {
          _ascending = !_ascending;
        } else {
          _sort = value;
          _ascending = value == _SortField.name;
        }
      }),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: _SortField.date,
          checked: _sort == _SortField.date,
          child: Text(s.sortDate),
        ),
        CheckedPopupMenuItem(
          value: _SortField.name,
          checked: _sort == _SortField.name,
          child: Text(s.sortName),
        ),
        CheckedPopupMenuItem(
          value: _SortField.size,
          checked: _sort == _SortField.size,
          child: Text(s.sortSize),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _sort,
          child: Row(
            children: [
              AnimatedRotation(
                duration: Motion.base,
                curve: Motion.spring,
                turns: _ascending ? 0 : 0.5,
                child: const Icon(Icons.arrow_upward, size: 18),
              ),
              const SizedBox(width: 8),
              Text(_ascending ? 'A → Z / kecil → besar' : 'Z → A / besar → kecil'),
            ],
          ),
        ),
      ],
      child: _CircleAction(icon: Icons.sort_rounded, onTap: null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: widget.search
                          ? _SearchField(
                              hint: s.searchHint,
                              onChanged: (v) => setState(() => _query = v),
                            )
                          : AnimatedSwitcher(
                              duration: Motion.base,
                              layoutBuilder: (current, previous) => Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  ...previous,
                                  if (current != null) current,
                                ],
                              ),
                              child: Text(
                                widget.title ?? s.allFiles,
                                key: ValueKey(widget.title ?? s.allFiles),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                    ),
                    if (!widget.search) ...[
                      const SizedBox(width: 6),
                      _sortMenu(s),
                      const SizedBox(width: 6),
                      _CircleAction(
                        icon: _grid
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        tooltip: _grid ? s.viewList : s.viewGrid,
                        onTap: () {
                          tapFeedback();
                          setState(() => _grid = !_grid);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.ctrl,
                  builder: (context, _) {
                    final items = _items();
                    final key = items.isEmpty
                        ? 'empty'
                        : (_grid ? 'grid' : 'list');
                    return AnimatedSwitcher(
                      duration: Motion.slow,
                      switchInCurve: Motion.emphasized,
                      switchOutCurve: Motion.standard,
                      child: items.isEmpty
                          ? ListView(
                              key: ValueKey(key),
                              padding:
                                  const EdgeInsets.fromLTRB(18, 10, 18, 30),
                              children: [
                                _EmptyList(
                                  message:
                                      widget.search && _query.trim().isEmpty
                                          ? s.typeFileName
                                          : s.noFiles,
                                  icon: widget.search
                                      ? Icons.search_rounded
                                      : (widget.category?.icon ??
                                          Icons.inbox_outlined),
                                ),
                              ],
                            )
                          : RefreshIndicator(
                              key: ValueKey(key),
                              onRefresh: widget.ctrl.refresh,
                              child: _grid
                                  ? GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                          18, 8, 18, 30),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 1.15,
                                      ),
                                      itemCount: items.length,
                                      itemBuilder: (_, i) => _GridTile(
                                        ctrl: widget.ctrl,
                                        item: items[i],
                                        index: i,
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                          18, 6, 18, 30),
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      itemCount: items.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (_, i) => FileTile(
                                        ctrl: widget.ctrl,
                                        item: items[i],
                                        index: i,
                                      ),
                                    ),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kolom pencarian berbentuk pill di header.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    return TextField(
      autofocus: true,
      onChanged: onChanged,
      style: TextStyle(color: AppColors.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    final button = SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Center(child: Icon(icon, color: scheme.onSurfaceVariant, size: 20))
            : InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Center(
                  child:
                      Icon(icon, color: scheme.onSurfaceVariant, size: 20),
                ),
              ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Stagger(
      child: DashedPanel(
        radius: AppRadii.xl,
        padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
        child: Column(
          children: [
            OrbIcon(icon: icon, size: 100),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.scheme.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.ctrl,
    required this.item,
    required this.index,
  });

  final DriveController ctrl;
  final PdItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final category = item.category;
    final scheme = AppColors.scheme;
    return Stagger(
      index: index,
      step: const Duration(milliseconds: 40),
      slide: 14,
      child: Pressable(
        onTap: () => downloadItem(context, ctrl, item),
        onLongPress: () => showItemActions(context, ctrl, item),
        scale: 0.96,
        child: Surface(
          radius: AppRadii.lg,
          padding: EdgeInsets.zero,
          clip: true,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlowIcon(
                  icon: category.icon,
                  size: 46,
                  color: category.color,
                ),
                const Spacer(),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: -0.1,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  formatSize(item.size),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
