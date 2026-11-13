import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import '../widgets/file_actions.dart';

class PhotosTab extends StatelessWidget {
  final DriveController ctrl;
  const PhotosTab({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final photos = ctrl.files
              .where((f) =>
                  f.category == FileCategory.images ||
                  f.mime.toLowerCase().startsWith('image/'))
              .toList()
            ..sort((a, b) =>
                (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(context.s.photos,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: ctrl.refresh,
                  child: photos.isEmpty
                      ? ListView(children: [
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(context.s.noPhotos,
                                  style: const TextStyle(
                                      color: AppColors.muted)),
                            ),
                          ),
                        ])
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                          itemCount: photos.length,
                          itemBuilder: (_, i) {
                            final p = photos[i];
                            return GestureDetector(
                              onTap: () => downloadItem(context, ctrl, p),
                              onLongPress: () => showItemActions(context, ctrl, p),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  p.thumbnailUrl,
                                  headers: ctrl.api.authHeaders,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.card,
                                    child: const Icon(Icons.broken_image_outlined,
                                        color: AppColors.muted),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
