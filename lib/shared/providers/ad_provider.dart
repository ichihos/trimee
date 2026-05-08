import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ad_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});
