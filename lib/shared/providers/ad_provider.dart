import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ad_service.dart';
import '../services/rewarded_ad_manager.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});

final rewardedAdManagerProvider = Provider<RewardedAdManager>((ref) {
  final adService = ref.watch(adServiceProvider);
  return RewardedAdManager(adService);
});
