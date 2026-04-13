import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimee/core/constants/app_colors.dart';
import 'package:trimee/core/constants/app_sizes.dart';
import 'package:trimee/shared/models/chat_model.dart';
import 'package:trimee/shared/services/chat_service.dart';
import 'package:trimee/shared/providers/firebase_providers.dart';

/// リアクションオーバーレイ
class ChatOverlay extends ConsumerStatefulWidget {
  const ChatOverlay({required this.tripId, required this.child, super.key});

  final String tripId;
  final Widget child;

  @override
  ConsumerState<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends ConsumerState<ChatOverlay>
    with TickerProviderStateMixin {
  final List<_FloatingReaction> _reactions = [];
  bool _isExpanded = false;

  // ドラッグ可能な位置
  Offset? _position;
  bool _isDragging = false;

  // 導入アニメーション用
  late AnimationController _introController;
  late Animation<double> _introScaleAnimation;

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
      }
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    for (final r in _reactions) {
      r.controller.dispose();
    }
    super.dispose();
  }

  // 初期位置を計算 (中央下)
  Offset _getInitialPosition(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    return Offset(
      screenSize.width / 2 - 24,
      screenSize.height - padding.bottom - 100,
    );
  }

  void _addReaction(String emoji) {
    setState(() {
      _reactions.add(
        _FloatingReaction(
          emoji: emoji,
          startPosition: Random().nextDouble() * 0.8 + 0.1,
          controller: AnimationController(
              duration: const Duration(seconds: 2),
              vsync: this,
            )
            ..forward(),
        ),
      );
    });
  }

  void _sendReaction(String emoji) {
    ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          tripId: widget.tripId,
          content: emoji,
          type: MessageType.reaction,
        );
    _addReaction(emoji);
  }

  @override
  Widget build(BuildContext context) {
    // セッションがない場合はリアクションUIを表示しない
    final currentUserId = ref.watch(currentUserIdProvider);
    if (currentUserId == null) {
      return widget.child;
    }

    // 新しいリアクションを監視して表示
    ref.listen(chatMessagesProvider(widget.tripId), (previous, next) {
      next.whenData((messages) {
        if (previous?.value == null) return;
        final newMessages =
            messages
                .where((m) => !previous!.value!.any((old) => old.id == m.id))
                .toList();

        for (var msg in newMessages) {
          if (msg.type == MessageType.reaction &&
              msg.senderId != ref.read(currentUserIdProvider)) {
            _addReaction(msg.content);
            HapticFeedback.lightImpact();
          }
        }
      });
    });

    // 初期位置を設定
    final screenSize = MediaQuery.of(context).size;
    _position ??= _getInitialPosition(context);

    // 画面外に出ないように位置を制限
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
                r.controller.dispose();
                _reactions.remove(r);
              });
            },
          ),
        ),

        // ドラッグ可能なリアクションボタン
        Positioned(
          left: clampedPosition.dx,
          top: clampedPosition.dy,
          child: GestureDetector(
            onPanStart: (_) {
              setState(() => _isDragging = true);
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
                    // リアクションボタン（展開時）
                    if (_isExpanded) ...[
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

                    // リアクション開閉ボタン
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
                        heroTag: 'reaction_toggle',
                        mini: true,
                        backgroundColor: AppColors.textPrimary,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _isExpanded
                                ? Icons.close
                                : Icons.emoji_emotions_outlined,
                            key: ValueKey(_isExpanded),
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () {
                          setState(() => _isExpanded = !_isExpanded);
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
          bottom: 100 + (_yAnimation.value * -1),
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
