import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/trip_member_model.dart';
import '../../../../shared/models/trip_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../shared/widgets/name_input_dialog.dart';
import '../providers/trip_provider.dart';

const _uuid = Uuid();

/// メンバー待機画面
class MemberLobbyScreen extends ConsumerStatefulWidget {
  const MemberLobbyScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<MemberLobbyScreen> createState() => _MemberLobbyScreenState();
}

class _MemberLobbyScreenState extends ConsumerState<MemberLobbyScreen> {
  bool _hasCheckedName = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserInfo();
    });
  }

  Future<void> _checkUserInfo() async {
    if (_hasCheckedName) return;
    _hasCheckedName = true;

    final tripAsync = ref.read(tripDetailProvider(widget.tripId));
    final trip = tripAsync.valueOrNull;
    final userId = ref.read(currentUserIdProvider);

    if (userId != null && trip != null) {
      final existingMember = trip.memberDetails[userId];
      if (existingMember != null && existingMember.displayName.isNotEmpty) {
        return;
      }
    }

    final result = await collectUserInfo(context, ref);
    if (result == null && mounted) {
      context.go('/');
      return;
    }

    if (result != null && userId != null && mounted) {
      final member = TripMember(
        userId: userId,
        displayName: result.name,
        departurePoint: result.departurePoint,
        joinedAt: DateTime.now(),
      );
      await ref
          .read(tripControllerProvider.notifier)
          .updateMemberDetails(widget.tripId, userId, member);
    }
  }

  void _copyInviteLink() {
    final link = 'https://trimee-ai.com/join/${widget.tripId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('招待リンクをコピーしました'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
      ),
    );
  }

  void _startPlanning() {
    HapticFeedback.mediumImpact();
    context.go('/trip/${widget.tripId}');
  }

  Future<void> _showAddMemberDialog() async {
    final nameController = TextEditingController();
    final departureController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'メンバーを追加',
                    style: AppTypography.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.paddingS),
                  Text(
                    'セッションに参加できないメンバーを追加します',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.paddingL),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '名前',
                      hintText: '例: たろう',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  TextField(
                    controller: departureController,
                    decoration: const InputDecoration(
                      labelText: '出発地点（任意）',
                      hintText: '例: 東京駅',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingL),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('キャンセル'),
                        ),
                      ),
                      const SizedBox(width: AppSizes.paddingM),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('名前を入力してください')),
                              );
                              return;
                            }
                            Navigator.pop(context, {
                              'name': name,
                              'departure': departureController.text.trim(),
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                          ),
                          child: const Text(
                            '追加',
                            style: TextStyle(color: Colors.white),
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

    if (result != null && mounted) {
      final personalLinkId = _uuid.v4().substring(0, 8);
      final memberId = 'manual_$personalLinkId';
      final member = TripMember(
        userId: memberId,
        displayName: result['name']!,
        departurePoint:
            result['departure']!.isNotEmpty ? result['departure'] : null,
        isManual: true,
        personalLinkId: personalLinkId,
        joinedAt: DateTime.now(),
      );

      await ref
          .read(tripControllerProvider.notifier)
          .updateMemberDetails(widget.tripId, memberId, member);

      if (mounted) {
        _showPersonalLinkDialog(member);
      }
    }
  }

  void _showPersonalLinkDialog(TripMember member) {
    final link =
        'https://trimee-ai.com/join/${widget.tripId}/${member.personalLinkId}';
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${member.displayName}さんの招待リンク'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'このリンクを共有してください。次回以降はこのリンクで参加できます。',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          link,
                          style: AppTypography.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: link));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('リンクをコピーしました')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: tripAsync.when(
          data: (trip) {
            if (trip == null) {
              return const Center(child: Text('旅行が見つかりません'));
            }
            return _buildContent(trip);
          },
          loading:
              () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
          error: (e, _) => Center(child: Text('エラー: $e')),
        ),
      ),
    );
  }

  Widget _buildContent(TripModel trip) {
    final allMembers = trip.memberDetails.values.toList();
    final manualMembers = allMembers.where((m) => m.isManual).toList();
    final regularMembers = allMembers.where((m) => !m.isManual).toList();

    // memberDetailsにないmembersリストのIDも考慮（ロード中のメンバー）
    final detailIds = trip.memberDetails.keys.toSet();
    final unregisteredIds =
        trip.members.where((id) => !detailIds.contains(id)).toList();
    final totalCount =
        regularMembers.length + manualMembers.length + unregisteredIds.length;

    return Column(
      children: [
        // ヘッダー
        Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Text(
                  trip.title,
                  style: AppTypography.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            child: Column(
              children: [
                const SizedBox(height: AppSizes.paddingXL),
                // アイコン
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent, Color(0xFFE07B4C)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.group_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingL),

                Text('メンバーを招待', style: AppTypography.headlineSmall),
                const SizedBox(height: AppSizes.paddingS),

                Text(
                  '$totalCount人が参加中',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXL),

                // 招待リンクボタン
                OutlinedButton.icon(
                  onPressed: _copyInviteLink,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('招待リンクをコピー'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingXL,
                      vertical: AppSizes.paddingM,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // トリップID表示
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingM,
                    vertical: AppSizes.paddingS,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ID: ',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SelectableText(
                        trip.id,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSizes.paddingS),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: trip.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('トリップIDをコピーしました'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ホーム画面の「参加」から入力して参加できます',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // メンバーを追加ボタン
                TextButton.icon(
                  onPressed: _showAddMemberDialog,
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('メンバーを追加'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: AppSizes.paddingXL),
                const Divider(),
                const SizedBox(height: AppSizes.paddingM),

                // 参加メンバー一覧
                _MemberList(
                  trip: trip,
                  allMembers: [...manualMembers, ...regularMembers],
                  unregisteredIds: unregisteredIds,
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),

        // 開始ボタン
        Container(
          padding: EdgeInsets.only(
            left: AppSizes.paddingL,
            right: AppSizes.paddingL,
            top: AppSizes.paddingM,
            bottom: MediaQuery.of(context).padding.bottom + AppSizes.paddingM,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startPlanning,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                  child: Text(
                    '始める',
                    style: AppTypography.button.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingXS),
              Text('後からメンバーを追加できます', style: AppTypography.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberList extends ConsumerWidget {
  const _MemberList({
    required this.trip,
    required this.allMembers,
    required this.unregisteredIds,
  });

  final TripModel trip;
  final List<TripMember> allMembers;
  final List<String> unregisteredIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCount = allMembers.length + unregisteredIds.length;
    if (totalCount == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '参加メンバー',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.paddingM),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCount,
          separatorBuilder:
              (_, __) => const SizedBox(height: AppSizes.paddingS),
          itemBuilder: (context, index) {
            if (index < allMembers.length) {
              final member = allMembers[index];
              final isCreator = member.userId == trip.createdBy;
              return _MemberTile(
                member: member,
                tripId: member.isManual ? trip.id : null,
                joinedViaLink: !member.isManual && !isCreator,
              );
            }
            final userId = unregisteredIds[index - allMembers.length];
            return _MemberTile(
              member: TripMember(
                userId: userId,
                displayName: '読み込み中...',
                joinedAt: DateTime.now(),
              ),
              joinedViaLink: true,
            );
          },
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    this.tripId,
    this.joinedViaLink = false,
  });

  final TripMember member;
  final String? tripId;
  final bool joinedViaLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.accent.withValues(alpha: 0.1),
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: AppColors.accent),
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        style: AppTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (joinedViaLink) ...[
                      const SizedBox(width: AppSizes.paddingXS),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'リンクで参加',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (member.departurePoint != null)
                  Text(
                    member.departurePoint!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (member.isManual && tripId != null)
            IconButton(
              onPressed: () {
                final link =
                    'https://trimee-ai.com/join/$tripId/${member.personalLinkId}';
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${member.displayName}さんのリンクをコピーしました'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.share_outlined),
              tooltip: '個別リンクをコピー',
            ),
        ],
      ),
    );
  }
}
