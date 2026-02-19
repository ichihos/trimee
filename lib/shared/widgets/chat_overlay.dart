import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimee/core/constants/app_colors.dart';
import 'package:trimee/core/constants/app_sizes.dart';
import 'package:trimee/core/constants/app_typography.dart';
import 'package:trimee/shared/models/chat_model.dart';
import 'package:trimee/shared/services/chat_service.dart';
import 'package:trimee/shared/providers/firebase_providers.dart';

/// チャット＆リアクションオーバーレイ
class ChatOverlay extends ConsumerStatefulWidget {
  const ChatOverlay({required this.tripId, required this.child, super.key});

  final String tripId;
  final Widget child;

  @override
  ConsumerState<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends ConsumerState<ChatOverlay>
    with TickerProviderStateMixin {
  bool _isChatOpen = false;
  final TextEditingController _textController = TextEditingController();
  final List<_FloatingReaction> _reactions = [];

  // ドラッグ可能な位置
  Offset? _position;
  bool _isDragging = false;

  // 導入アニメーション用
  late AnimationController _introController;
  late Animation<double> _introScaleAnimation;
  bool _showIntroTooltip = true;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _introScaleAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.elasticOut,
    );

    // 少し遅れて表示＆ハプティック
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _introController.forward();
        HapticFeedback.mediumImpact();

        // 数秒後にツールチップを消す
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() => _showIntroTooltip = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _introController.dispose();
    super.dispose();
  }

  // 初期位置を計算 (右下、ナビゲーションの上)
  Offset _getInitialPosition(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    return Offset(
      screenSize.width / 2 - 24, // 中央（ボタン幅48の半分を引く）
      screenSize.height - padding.bottom - 100, // 下端から少し上
    );
  }

  void _addReaction(String emoji) {
    setState(() {
      _reactions.add(
        _FloatingReaction(
          emoji: emoji,
          startPosition: Random().nextDouble() * 0.8 + 0.1, // 画面幅の10%〜90%の位置
          controller: AnimationController(
              duration: const Duration(seconds: 2),
              vsync: this,
            )
            ..forward().then((_) {
              _removeReaction(emoji); // 修正: インスタンス管理が必要だが一旦簡易実装
            }),
        ),
      );
    });
  }

  void _removeReaction(String emoji) {
    // 実際には特定のアニメーションが完了したものを削除する必要があります
    // ここでは簡易的に古いものを削除するロジックにするか、AnimationControllerのlistenerで削除する
  }

  void _sendReaction(String emoji) {
    ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          tripId: widget.tripId,
          content: emoji,
          type: MessageType.reaction,
        );
    // 自分の画面でも表示
    _addReaction(emoji);
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          tripId: widget.tripId,
          content: text,
          type: MessageType.text,
        );
    _textController.clear();
    // キーボードを閉じる
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // セッションがない場合はチャットUIを表示しない
    final currentUserId = ref.watch(currentUserIdProvider);
    if (currentUserId == null) {
      return widget.child;
    }

    // 新しいリアクションを監視して表示
    ref.listen(chatMessagesProvider(widget.tripId), (previous, next) {
      next.whenData((messages) {
        if (previous?.value == null) return;
        // 新着メッセージを確認
        final newMessages =
            messages
                .where((m) => !previous!.value!.any((old) => old.id == m.id))
                .toList();

        for (var msg in newMessages) {
          if (msg.type == MessageType.reaction &&
              msg.senderId != ref.read(currentUserIdProvider)) {
            _addReaction(msg.content);
            HapticFeedback.lightImpact(); // リアクション受信時もハプティック
          }
        }
      });
    });

    // 初期位置を設定
    final screenSize = MediaQuery.of(context).size;
    _position ??= _getInitialPosition(context);

    // 画面外に出ないように位置を制限（SafeArea考慮）
    final padding = MediaQuery.of(context).padding;
    final buttonSize = 48.0;
    final safeLeft = 0.0;
    final safeTop = padding.top + 8;
    final safeRight = screenSize.width - buttonSize - 8;
    final safeBottom = screenSize.height - padding.bottom - buttonSize - 8;

    final clampedPosition = Offset(
      _position!.dx.clamp(safeLeft, safeRight),
      _position!.dy.clamp(safeTop, safeBottom),
    );

    return Stack(
      children: [
        // メインコンテンツ
        widget.child,

        // リアクションアニメーション領域
        ..._reactions.map(
          (r) => _ReactionAnimation(
            reaction: r,
            onComplete: () {
              setState(() {
                _reactions.remove(r);
              });
            },
          ),
        ),

        // チャットウィンドウ
        if (_isChatOpen)
          Positioned(
            right: AppSizes.paddingM,
            left: AppSizes.paddingM,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            child: _ChatWindow(
              tripId: widget.tripId,
              controller: _textController,
              onSend: _sendMessage,
              onClose: () {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _isChatOpen = false);
              },
            ),
          ),

        // ドラッグ可能なチャットボタン & リアクション
        Positioned(
          left: clampedPosition.dx,
          top: clampedPosition.dy,
          child: GestureDetector(
            onPanStart: (_) {
              setState(() {
                _isDragging = true;
                _showIntroTooltip = false; // ドラッグしたらツールチップ消す
              });
              HapticFeedback.selectionClick();
            },
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  _position!.dx + details.delta.dx,
                  _position!.dy + details.delta.dy,
                );
              });
            },
            onPanEnd: (_) => setState(() => _isDragging = false),
            child: ScaleTransition(
              scale: _introScaleAnimation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                transform: Matrix4.identity()..scale(_isDragging ? 1.1 : 1.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 説明ツールチップ
                    if (_showIntroTooltip && !_isChatOpen)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'みんなとチャット！',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.waving_hand,
                                size: 14,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // リアクションボタンたち
                    if (!_isChatOpen && (_isDragging || _showIntroTooltip)) ...[
                      // ドラッグ中やイントロ中は常に表示（オプションで調整可）
                    ] else if (!_isChatOpen) ...[
                      // 通常時は閉じておく、あるいは常に表示するかの仕様次第
                      // ここではユーザーリクエストに合わせて常に表示に変更
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QuickReactionButton(
                            emoji: '👍',
                            onTap: () {
                              _sendReaction('👍');
                              HapticFeedback.lightImpact();
                            },
                          ),
                          const SizedBox(width: 8),
                          _QuickReactionButton(
                            emoji: '🙌',
                            onTap: () {
                              _sendReaction('🙌');
                              HapticFeedback.lightImpact();
                            },
                          ),
                          const SizedBox(width: 8),
                          _QuickReactionButton(
                            emoji: '🎉',
                            onTap: () {
                              _sendReaction('🎉');
                              HapticFeedback.lightImpact();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingS),
                    ],

                    // チャット開閉ボタン
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: _isDragging ? 0.3 : 0.15,
                            ),
                            blurRadius: _isDragging ? 12 : 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        heroTag: 'chat_toggle',
                        mini: true, // 少し大きくしてもいいかも？一旦miniのまま
                        backgroundColor: AppColors.textPrimary,
                        child: Icon(
                          _isChatOpen ? Icons.close : Icons.chat_bubble_outline,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _isChatOpen = !_isChatOpen;
                            _showIntroTooltip = false;
                          });
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ... (remaining classes: _FloatingReaction, _ReactionAnimation, _ChatWindow, _QuickReactionButton)

class _FloatingReaction {
  final String emoji;
  final double startPosition;
  final AnimationController controller;

  _FloatingReaction({
    required this.emoji,
    required this.startPosition,
    required this.controller,
  });
}

class _ReactionAnimation extends StatefulWidget {
  const _ReactionAnimation({required this.reaction, required this.onComplete});
  final _FloatingReaction reaction;
  final VoidCallback onComplete;

  @override
  State<_ReactionAnimation> createState() => _ReactionAnimationState();
}

class _ReactionAnimationState extends State<_ReactionAnimation> {
  late Animation<double> _yAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _yAnimation = Tween<double>(begin: 0, end: -300).animate(
      CurvedAnimation(
        parent: widget.reaction.controller,
        curve: Curves.easeOut,
      ),
    );
    _opacityAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: widget.reaction.controller,
        curve: const Interval(0.7, 1.0),
      ),
    );

    widget.reaction.controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.reaction.controller,
      builder: (context, child) {
        return Positioned(
          left:
              MediaQuery.of(context).size.width * widget.reaction.startPosition,
          bottom: 100 + (_yAnimation.value * -1), // 下から上に
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Text(
              widget.reaction.emoji,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        );
      },
    );
  }
}

class _ChatWindow extends ConsumerWidget {
  const _ChatWindow({
    required this.tripId,
    required this.controller,
    required this.onSend,
    required this.onClose,
  });

  final String tripId;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(chatMessagesProvider(tripId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingM,
              vertical: AppSizes.paddingS,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusL),
              ),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('チャット', style: AppTypography.titleMedium),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // メッセージリスト
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                final textMessages =
                    messages.where((m) => m.type == MessageType.text).toList();
                if (textMessages.isEmpty) {
                  return Center(
                    child: Text(
                      'まだメッセージはありません',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  itemCount: textMessages.length,
                  itemBuilder: (context, index) {
                    final msg = textMessages[index];
                    final isMe = msg.senderId == currentUserId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment:
                            isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        children: [
                          // 投稿者名（他人のメッセージのみ）
                          if (!isMe && msg.senderName != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 2,
                                left: 4,
                              ),
                              child: Text(
                                msg.senderName!,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isMe
                                      ? AppColors.accent
                                      : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg.content,
                              style: TextStyle(
                                color:
                                    isMe ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('エラー: $err')),
            ),
          ),

          // 入力エリア
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingS),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'メッセージを入力...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send_rounded, size: 22),
                  color: AppColors.accent,
                  onPressed: onSend,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickReactionButton extends StatelessWidget {
  const _QuickReactionButton({required this.emoji, required this.onTap});
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
      ),
    );
  }
}
