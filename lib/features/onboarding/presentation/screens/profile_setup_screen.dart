import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/user_profile_model.dart';
import '../../../../shared/providers/user_profile_provider.dart';

/// プロフィール設定画面（初回質問）
/// 名前はチームごとに設定するため、ここでは年代・性別・旅行スタイルのみ収集
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // 入力値（名前はチームごとに設定するため、ここでは収集しない）
  AgeRange? _selectedAgeRange;
  Gender? _selectedGender;
  final Set<TravelStyle> _selectedTravelStyles = {};

  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // プログレスインジケーター（2ステップに変更）
            _buildProgressIndicator(),

            // ページビュー
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [_buildAgeGenderPage(), _buildTravelStylePage()],
              ),
            ),

            // ナビゲーションボタン
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Row(
        children: List.generate(2, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 1 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accent : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAgeGenderPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.paddingL),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.accent,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingL),
          Center(
            child: Text(
              'あなたのことを\n教えてください',
              style: AppTypography.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSizes.paddingS),
          Center(
            child: Text(
              'AIがより良いプランを提案するために参考にします',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSizes.paddingXL),
          Text('年代を教えてください', style: AppTypography.titleLarge),
          const SizedBox(height: AppSizes.paddingM),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            children:
                AgeRange.values.map((age) {
                  final isSelected = _selectedAgeRange == age;
                  return ChoiceChip(
                    label: Text(age.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedAgeRange = selected ? age : null;
                      });
                    },
                    selectedColor: AppColors.accent.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.accent,
                    labelStyle: TextStyle(
                      color:
                          isSelected ? AppColors.accent : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: AppSizes.paddingXL),
          Text('性別を教えてください', style: AppTypography.titleLarge),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            '任意です（回答しないも選べます）',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            children:
                Gender.values.map((gender) {
                  final isSelected = _selectedGender == gender;
                  return ChoiceChip(
                    label: Text(gender.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedGender = selected ? gender : null;
                      });
                    },
                    selectedColor: AppColors.accent.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.accent,
                    labelStyle: TextStyle(
                      color:
                          isSelected ? AppColors.accent : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelStylePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.paddingL),
          Text('あなたの旅行スタイルは？', style: AppTypography.titleLarge),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            '複数選択できます（AIプランの参考にします）',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingL),
          ...TravelStyle.values.map((style) {
            final isSelected = _selectedTravelStyles.contains(style);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.paddingS),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTravelStyles.remove(style);
                    } else {
                      _selectedTravelStyles.add(style);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                child: Container(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppColors.accent.withValues(alpha: 0.1)
                            : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppColors.accent
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppColors.accent
                                    : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child:
                            isSelected
                                ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.white,
                                )
                                : null,
                      ),
                      const SizedBox(width: AppSizes.paddingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              style.label,
                              style: AppTypography.titleSmall.copyWith(
                                color:
                                    isSelected
                                        ? AppColors.accent
                                        : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              style.description,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    // 最初のページ: 年代が選択されていれば進める
    final canProceed = _currentPage == 0 ? _selectedAgeRange != null : true;

    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('戻る'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: ElevatedButton(
              onPressed:
                  canProceed && !_isLoading ? () => _onNextPressed() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(52),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        _currentPage < 1 ? '次へ' : '始める',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onNextPressed() async {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // プロフィールを保存（名前は空で保存、チームごとに設定）
      setState(() => _isLoading = true);

      try {
        final success = await ref
            .read(profileControllerProvider.notifier)
            .saveProfile(
              displayName: '', // 名前はチームごとに設定
              ageRange: _selectedAgeRange,
              gender: _selectedGender,
              travelStyles: _selectedTravelStyles.toList(),
            );

        if (mounted) {
          if (success) {
            if (widget.from != null) {
              context.go(widget.from!);
            } else {
              context.go('/');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('プロフィールの保存に失敗しました'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
              ),
            );
          }
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
