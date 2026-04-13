import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/iap_constants.dart';
import '../../../../shared/providers/ad_provider.dart';
import '../../../../shared/providers/iap_provider.dart';

/// AI生成ゲートダイアログの結果
enum AiGenerationGateResult {
  /// リワード広告を視聴（3本完了でAI生成可能）
  watchedRewardAd,

  /// 課金購入（¥120）で即時生成
  purchased,

  /// キャンセル
  cancelled,
}

/// AI生成の2回目以降に表示されるゲートダイアログ
///
/// ビジネスモデル:
/// - 1回目: 無料（インタースティシャル広告付き）
/// - 2回目以降: ¥120課金 or リワード広告3本視聴
class AiGenerationGateDialog extends ConsumerStatefulWidget {
  final String tripId;

  const AiGenerationGateDialog({
    super.key,
    required this.tripId,
  });

  @override
  ConsumerState<AiGenerationGateDialog> createState() =>
      _AiGenerationGateDialogState();
}

class _AiGenerationGateDialogState
    extends ConsumerState<AiGenerationGateDialog> {
  int _watchProgress = 0;
  bool _isWatchingAd = false;
  bool _isPurchasing = false;
  String _priceDisplay = IAPConstants.aiGenerationPriceDisplay;

  // TODO: DEBUG REMOVE - 隠しデバッグコマンド用の状態
  bool _isAdPressed = false;
  bool _isPayPressed = false;
  Timer? _debugTimer;

  void _checkDebugBypass() {
    if (_isAdPressed && _isPayPressed) {
      _debugTimer ??= Timer(const Duration(seconds: 10), () {
        if (mounted && _isAdPressed && _isPayPressed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('DEBUG: AI生成をバイパスしました'),
              backgroundColor: Colors.blue,
            ),
          );
          Navigator.of(context).pop(AiGenerationGateResult.purchased);
        }
      });
    } else {
      _debugTimer?.cancel();
      _debugTimer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _loadPrice();
  }

  Future<void> _loadProgress() async {
    final manager = ref.read(rewardedAdManagerProvider);
    final progress = await manager.getWatchProgress(widget.tripId);
    if (mounted) {
      setState(() {
        _watchProgress = progress;
      });
    }
  }

  Future<void> _loadPrice() async {
    final iapService = ref.read(iapServiceProvider);
    if (iapService.isInitialized) {
      final price = await iapService.getAiGenerationPrice();
      if (mounted) {
        setState(() {
          _priceDisplay = price;
        });
      }
    }
  }

  Future<void> _watchRewardAd() async {
    setState(() {
      _isWatchingAd = true;
    });

    final manager = ref.read(rewardedAdManagerProvider);
    final earned = await manager.watchRewardAdForGeneration(widget.tripId);

    if (!mounted) return;

    if (earned) {
      // 3本視聴完了 → AI生成権獲得
      if (mounted) {
        Navigator.of(context).pop(AiGenerationGateResult.watchedRewardAd);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ 3本の広告視聴完了！AI旅程を生成します'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // まだ3本未満 → 進捗を更新して継続
      final newProgress = await manager.getWatchProgress(widget.tripId);
      if (mounted) {
        setState(() {
          _watchProgress = newProgress;
          _isWatchingAd = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('広告視聴完了！ あと${3 - newProgress}本で生成できます'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  Future<void> _purchaseAiGeneration() async {
    setState(() {
      _isPurchasing = true;
    });

    final iapService = ref.read(iapServiceProvider);

    try {
      final success = await iapService.purchaseAiGeneration();

      if (!mounted) return;

      if (success) {
        // 購入成功 → AI生成へ進む
        if (mounted) {
          Navigator.of(context).pop(AiGenerationGateResult.purchased);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ 購入完了！AI旅程を生成します'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // 購入失敗またはキャンセル
        if (mounted) {
          setState(() {
            _isPurchasing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('購入がキャンセルされました'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('購入に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    final iapService = ref.read(iapServiceProvider);

    try {
      final customerInfo = await iapService.restorePurchases();

      if (!mounted) return;

      if (customerInfo != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('購入履歴を復元しました'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('復元できる購入履歴がありません'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('復元に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = 3 - _watchProgress;

    if (kIsWeb) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TODO: DEBUG REMOVE - 隠しデバッグコマンド用のListener
              Listener(
                onPointerDown: (_) {
                  _isAdPressed = true;
                  _checkDebugBypass();
                },
                onPointerUp: (_) {
                  _isAdPressed = false;
                  _checkDebugBypass();
                },
                onPointerCancel: (_) {
                  _isAdPressed = false;
                  _checkDebugBypass();
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 32,
                    color: theme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'モバイルアプリで作成',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Web版でのAIプラン生成は初回のみ無料です。\n\n2回目以降の生成をご希望の場合は、iOSまたはAndroidアプリをダウンロードして続きをお楽しみください！',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 32),
              // TODO: DEBUG REMOVE - 隠しデバッグコマンド用のListener
              Listener(
                onPointerDown: (_) {
                  _isPayPressed = true;
                  _checkDebugBypass();
                },
                onPointerUp: (_) {
                  _isPayPressed = false;
                  _checkDebugBypass();
                },
                onPointerCancel: (_) {
                  _isPayPressed = false;
                  _checkDebugBypass();
                },
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(AiGenerationGateResult.cancelled);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('閉じる'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アイコン
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 32,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),

            // タイトル
            Text(
              'AI旅程を生成',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // 説明
            Text(
              '1回目は無料でお試しいただけましたが、\n2回目以降は下記の方法で生成できます',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // オプション1: リワード広告
            // TODO: DEBUG REMOVE - 隠しデバッグコマンド用のListener
            Listener(
              onPointerDown: (_) {
                _isAdPressed = true;
                _checkDebugBypass();
              },
              onPointerUp: (_) {
                _isAdPressed = false;
                _checkDebugBypass();
              },
              onPointerCancel: (_) {
                _isAdPressed = false;
                _checkDebugBypass();
              },
              child: _OptionCard(
                icon: Icons.play_circle_outline,
                iconColor: Colors.blue,
              title: '広告を見て生成',
              subtitle: remaining > 0
                  ? 'あと$remaining本の広告視聴で生成できます'
                  : '3本視聴完了！生成ボタンを押してください',
              badge: '$_watchProgress/3',
              badgeColor: _watchProgress >= 3 ? Colors.green : Colors.blue,
              onTap: _isWatchingAd ? null : _watchRewardAd,
              isLoading: _isWatchingAd,
            ),
            ),
            const SizedBox(height: 12),

            // オプション2: 課金購入
            // TODO: DEBUG REMOVE - 隠しデバッグコマンド用のListener
            Listener(
              onPointerDown: (_) {
                _isPayPressed = true;
                _checkDebugBypass();
              },
              onPointerUp: (_) {
                _isPayPressed = false;
                _checkDebugBypass();
              },
              onPointerCancel: (_) {
                _isPayPressed = false;
                _checkDebugBypass();
              },
              child: _OptionCard(
                icon: Icons.shopping_bag_outlined,
                iconColor: Colors.amber,
              title: '$_priceDisplayで即時生成',
              subtitle: '広告なしでスムーズに旅程作成',
              badge: _priceDisplay,
              badgeColor: Colors.amber,
              onTap: _isPurchasing ? null : _purchaseAiGeneration,
              isLoading: _isPurchasing,
            ),
            ),
            const SizedBox(height: 24),

            // 購入復元ボタン
            TextButton.icon(
              onPressed: _restorePurchases,
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('購入を復元'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),

            // キャンセルボタン
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(AiGenerationGateResult.cancelled);
              },
              child: const Text('キャンセル'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ゲートダイアログのオプションカード
class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback? onTap;
  final bool isLoading;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isEnabled
                  ? iconColor.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // アイコン
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isEnabled ? 0.1 : 0.05),
                  shape: BoxShape.circle,
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        icon,
                        color: isEnabled ? iconColor : Colors.grey,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),

              // テキスト
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isEnabled ? null : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // バッジ
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
