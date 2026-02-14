import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// カスタムアイコンのタイプ
enum AppIconType {
  /// きらめき・魔法（旧: ✨）
  sparkle,

  /// 飛行機・旅行（旧: ✈️）
  travel,

  /// アクティブ・走る（旧: 🏃）
  active,

  /// のんびり・葉っぱ（旧: 🌿）
  relax,

  /// お金・コスパ（旧: 💰）
  budget,

  /// プラン・リスト（旧: 📋）
  plan,

  /// ターゲット・目標（旧: 🎯）
  target,

  /// ビーチ・海（旧: 🏝️）
  beach,

  /// 山（旧: 🏔️）
  mountain,

  /// 温泉（旧: ♨️）
  hotSpring,

  /// 神社・寺（旧: ⛩️）
  shrine,

  /// 都会・タワー（旧: 🗼）
  city,

  /// スキー・雪（旧: ⛷️）
  ski,

  /// キャンプ（旧: 🏕️）
  camp,

  /// ひらめき（旧: 💡）
  idea,

  /// グループ・人々（旧: 👥）
  group,

  /// お祝い（旧: 🎉）
  celebrate,
}

/// アプリ全体で使用するカスタムアイコンウィジェット
/// 絵文字の代わりに洗練されたデザインのアイコンを表示
class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
    required this.type,
    this.size = 24,
    this.showBackground = true,
    this.backgroundColor,
    this.iconColor,
  });

  final AppIconType type;
  final double size;
  final bool showBackground;
  final Color? backgroundColor;
  final Color? iconColor;

  /// アイコンタイプに応じたMaterial Iconを取得
  IconData get _iconData {
    return switch (type) {
      AppIconType.sparkle => Icons.auto_awesome,
      AppIconType.travel => Icons.flight_takeoff_rounded,
      AppIconType.active => Icons.directions_run_rounded,
      AppIconType.relax => Icons.spa_rounded,
      AppIconType.budget => Icons.savings_rounded,
      AppIconType.plan => Icons.checklist_rounded,
      AppIconType.target => Icons.my_location_rounded,
      AppIconType.beach => Icons.beach_access_rounded,
      AppIconType.mountain => Icons.terrain_rounded,
      AppIconType.hotSpring => Icons.hot_tub_rounded,
      AppIconType.shrine => Icons.temple_buddhist_rounded,
      AppIconType.city => Icons.location_city_rounded,
      AppIconType.ski => Icons.downhill_skiing_rounded,
      AppIconType.camp => Icons.cabin_rounded,
      AppIconType.idea => Icons.lightbulb_rounded,
      AppIconType.group => Icons.groups_rounded,
      AppIconType.celebrate => Icons.celebration_rounded,
    };
  }

  /// アイコンタイプに応じた色を取得
  Color get _defaultColor {
    return switch (type) {
      AppIconType.sparkle => const Color(0xFFE6A23C),
      AppIconType.travel => AppColors.accent,
      AppIconType.active => const Color(0xFFE57373),
      AppIconType.relax => AppColors.subAccent,
      AppIconType.budget => const Color(0xFFFFB74D),
      AppIconType.plan => AppColors.textSecondary,
      AppIconType.target => AppColors.accent,
      AppIconType.beach => const Color(0xFF4FC3F7),
      AppIconType.mountain => const Color(0xFF8D6E63),
      AppIconType.hotSpring => const Color(0xFFE57373),
      AppIconType.shrine => const Color(0xFFE57373),
      AppIconType.city => const Color(0xFF7986CB),
      AppIconType.ski => const Color(0xFF4FC3F7),
      AppIconType.camp => AppColors.subAccent,
      AppIconType.idea => const Color(0xFFFFD54F),
      AppIconType.group => AppColors.subAccent,
      AppIconType.celebrate => const Color(0xFFE6A23C),
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? _defaultColor;
    final iconSize = showBackground ? size * 0.55 : size;

    if (!showBackground) {
      return Icon(_iconData, size: iconSize, color: color);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (backgroundColor ?? color).withValues(alpha: 0.15),
            (backgroundColor ?? color).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
          color: (backgroundColor ?? color).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(child: Icon(_iconData, size: iconSize, color: color)),
    );
  }
}

/// シンプルなグラデーションアイコンバッジ
/// 小さなインジケーターとして使用
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.size = 20,
    this.color,
  });

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c, c.withValues(alpha: 0.8)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: Icon(icon, size: size * 0.55, color: Colors.white)),
    );
  }
}

/// 旅行タイプに応じたアイコンを返すヘルパー
class TripTypeIcon extends StatelessWidget {
  const TripTypeIcon({super.key, required this.title, this.size = 48});

  final String title;
  final double size;

  AppIconType get _type {
    final t = title.toLowerCase();
    if (t.contains('沖縄') || t.contains('海') || t.contains('ビーチ')) {
      return AppIconType.beach;
    }
    if (t.contains('山') || t.contains('登山') || t.contains('ハイキング')) {
      return AppIconType.mountain;
    }
    if (t.contains('温泉') || t.contains('箱根') || t.contains('草津')) {
      return AppIconType.hotSpring;
    }
    if (t.contains('京都') || t.contains('寺') || t.contains('神社')) {
      return AppIconType.shrine;
    }
    if (t.contains('東京') || t.contains('都会')) {
      return AppIconType.city;
    }
    if (t.contains('雪') || t.contains('スキー') || t.contains('スノボ')) {
      return AppIconType.ski;
    }
    if (t.contains('キャンプ') || t.contains('アウトドア')) {
      return AppIconType.camp;
    }
    return AppIconType.travel;
  }

  @override
  Widget build(BuildContext context) {
    return AppIcon(type: _type, size: size);
  }
}

/// プランタイプに応じたアイコンを返すヘルパー
class PlanTypeIcon extends StatelessWidget {
  const PlanTypeIcon({
    super.key,
    required this.title,
    this.size = 24,
    this.showBackground = true,
  });

  final String title;
  final double size;
  final bool showBackground;

  AppIconType get _type {
    if (title.contains('アクティブ')) return AppIconType.active;
    if (title.contains('のんびり')) return AppIconType.relax;
    if (title.contains('コスパ')) return AppIconType.budget;
    return AppIconType.plan;
  }

  @override
  Widget build(BuildContext context) {
    return AppIcon(type: _type, size: size, showBackground: showBackground);
  }
}
