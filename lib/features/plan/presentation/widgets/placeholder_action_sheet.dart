import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/plan_model.dart';
import '../../../../shared/services/ai_service.dart';
import '../../../../shared/widgets/app_card.dart';

/// プレースホルダーアクションシート
/// プレースホルダーをタップした時に表示される、文脈に応じたアクションを提供
class PlaceholderActionSheet extends ConsumerStatefulWidget {
  const PlaceholderActionSheet({
    super.key,
    required this.item,
    required this.destination,
    required this.onSelectSuggestion,
  });

  final PlanItem item;
  final String? destination;
  final Function(String name, double? lat, double? lng) onSelectSuggestion;

  @override
  ConsumerState<PlaceholderActionSheet> createState() =>
      _PlaceholderActionSheetState();
}

class _PlaceholderActionSheetState
    extends ConsumerState<PlaceholderActionSheet> {
  bool _isLoading = false;
  PlaceholderSuggestion? _suggestion;
  late PlaceholderType _type;

  @override
  void initState() {
    super.initState();
    _type = PlaceholderHelper.detectType(widget.item.location);
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);

    try {
      final aiService = ref.read(aiServiceProvider);
      final keyword = PlaceholderHelper.extractKeyword(widget.item.location);

      final suggestion = await aiService.suggestForPlaceholder(
        placeholderType: _getTypeString(),
        destination: widget.destination,
        nearbyLocation: keyword.isNotEmpty ? keyword : null,
        tripContext: widget.item.notes,
      );

      if (mounted) {
        setState(() {
          _suggestion = suggestion;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTypeString() {
    switch (_type) {
      case PlaceholderType.accommodation:
        return 'accommodation';
      case PlaceholderType.meal:
        return 'meal';
      case PlaceholderType.activity:
        return 'activity';
      case PlaceholderType.shopping:
        return 'activity';
      case PlaceholderType.transport:
        return 'activity';
      case PlaceholderType.other:
        return 'activity';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドル
          Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // ヘッダー
          _buildHeader(),

          const Divider(height: 1),

          // コンテンツ
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI提案セクション
                  _buildAISuggestions(),

                  const SizedBox(height: AppSizes.paddingL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final icon = PlaceholderHelper.getIcon(_type);
    final label = PlaceholderHelper.getLabel(_type);
    final keyword = PlaceholderHelper.extractKeyword(widget.item.location);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingS),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFFE07B4C)],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: AppSizes.paddingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  keyword.isNotEmpty ? keyword : label,
                  style: AppTypography.titleMedium,
                ),
                if (widget.destination != null)
                  Text(
                    widget.destination!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _buildAISuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(
              'AIおすすめ',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            if (!_isLoading)
              GestureDetector(
                onTap: _loadSuggestions,
                child: Text(
                  '更新',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.paddingS),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.paddingL),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
          )
        else if (_suggestion == null || _suggestion!.suggestions.isEmpty)
          _buildEmptyState()
        else
          _buildSuggestionList(),

        // Tips
        if (_suggestion?.tips != null) ...[
          const SizedBox(height: AppSizes.paddingM),
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSizes.paddingS),
                Expanded(
                  child: Text(
                    _suggestion!.tips!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 32,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            '提案を取得できませんでした',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingS),
          TextButton(onPressed: _loadSuggestions, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildSuggestionList() {
    return Column(
      children:
          _suggestion!.suggestions.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.paddingS),
              child: _SuggestionCard(
                item: item,
                type: _type,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onSelectSuggestion(item.name, null, null);
                  Navigator.pop(context);
                },
                onSearch: () {
                  HapticFeedback.lightImpact();
                  _openUrl(
                    'https://www.google.com/search?q=${Uri.encodeComponent(item.searchQuery)}',
                  );
                },
              ),
            );
          }).toList(),
    );
  }
}

/// 提案カード
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.item,
    required this.type,
    required this.onTap,
    required this.onSearch,
  });

  final SuggestionItem item;
  final PlaceholderType type;
  final VoidCallback onTap;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.type != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.type!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 価格帯または所要時間
                  if (item.priceRange != null || item.duration != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingS,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.subAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      ),
                      child: Text(
                        item.priceRange ?? item.duration ?? '',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.subAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),

              // 特徴
              if (item.features.isNotEmpty) ...[
                const SizedBox(height: AppSizes.paddingS),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children:
                      item.features.take(3).map((feature) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.border.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            feature,
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],

              const SizedBox(height: AppSizes.paddingS),

              // アクションボタン
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSearch,
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('詳しく調べる'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.paddingS,
                        ),
                        textStyle: AppTypography.labelSmall,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingS),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('これにする'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.paddingS,
                        ),
                        textStyle: AppTypography.labelSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// プレースホルダーアクションシートを表示
void showPlaceholderActionSheet({
  required BuildContext context,
  required PlanItem item,
  required String? destination,
  required Function(String name, double? lat, double? lng) onSelectSuggestion,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder:
        (context) => PlaceholderActionSheet(
          item: item,
          destination: destination,
          onSelectSuggestion: onSelectSuggestion,
        ),
  );
}
