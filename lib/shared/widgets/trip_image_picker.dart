import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_typography.dart';
import '../../features/trip/presentation/providers/trip_provider.dart';
import '../providers/firebase_providers.dart';
import 'app_icon.dart';

void showTripImagePicker(
  BuildContext context, {
  required String tripId,
  String? currentImageUrl,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TripImagePickerSheet(
      tripId: tripId,
      currentImageUrl: currentImageUrl,
    ),
  );
}

class _TripImagePickerSheet extends ConsumerWidget {
  const _TripImagePickerSheet({required this.tripId, this.currentImageUrl});
  final String tripId;
  final String? currentImageUrl;

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      final storage = ref.read(firebaseStorageProvider);
      final storageRef = storage.ref('trip_images/$tripId.jpg');
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await storageRef.getDownloadURL();
      await ref.read(tripRepositoryProvider).updateTripImageUrl(tripId, url);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('画像の設定に失敗しました'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectIcon(
    BuildContext context,
    WidgetRef ref,
    String iconName,
  ) async {
    Navigator.pop(context);
    await ref
        .read(tripRepositoryProvider)
        .updateTripImageUrl(tripId, 'icon:$iconName');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
              child: Row(
                children: [
                  Text('カバー画像を選択', style: AppTypography.titleMedium),
                  const Spacer(),
                  if (currentImageUrl != null)
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await ref
                            .read(tripRepositoryProvider)
                            .updateTripImageUrl(tripId, null);
                      },
                      child: Text(
                        'リセット',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.paddingS),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
              child: GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSizes.paddingM,
                crossAxisSpacing: AppSizes.paddingM,
                children: [
                  for (final name in TripIconAssets.all)
                    GestureDetector(
                      onTap: () => _selectIcon(context, ref, name),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: currentImageUrl == 'icon:$name'
                              ? Border.all(color: AppColors.accent, width: 2)
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            TripIconAssets.path(name),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(context, ref),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('写真から選ぶ'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.accent,
                  side: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),
          ],
        ),
      ),
    );
  }
}
