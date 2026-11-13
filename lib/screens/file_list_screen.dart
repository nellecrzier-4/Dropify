import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import '../widgets/file_actions.dart';
import '../widgets/file_tile.dart';

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
      icon: Icon(
        _ascending ? Icons.sort : Icons.sort,
        color: AppColors.muted,
      ),
      tooltip: s.sortBy,
      onSelected: (value) => setState(() {
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
              Icon(
                _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(_ascending ? 'A → Z / kecil → besar' : 'Z → A / besar → kecil'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: AppBar(
        title: widget.search
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: s.searchHint,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(widget.title ?? s.allFiles,
                style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (!widget.search) ...[
            _sortMenu(s),
            IconButton(
              tooltip: _grid ? s.viewList : s.viewGrid,
              icon: Icon(
                _grid ? Icons.view_list_outlined : Icons.grid_view_outlined,
                color: AppColors.muted,
              ),
              onPressed: () => setState(() => _grid = !_grid),
            ),
          ],
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.ctrl,
        builder: (context, _) {
          final items = _items();
          if (items.isEmpty) {
            return Center(
              child: Text(
                widget.search && _query.trim().isEmpty
                    ? s.typeFileName
                    : s.noFiles,
                style: const TextStyle(color: AppColors.muted),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: widget.ctrl.refresh,
            child: _grid
                ? GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) =>
                        FileTile(ctrl: widget.ctrl, item: items[i]),
                  ),
          );
        },
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.ctrl, required this.item});

  final DriveController ctrl;
  final PdItem item;

  @override
  Widget build(BuildContext context) {
    final category = item.category;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => downloadItem(context, ctrl, item),
        onLongPress: () => showItemActions(context, ctrl, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(category.icon, color: category.color, size: 22),
              ),
              const Spacer(),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatSize(item.size),
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
