import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/iap_service.dart';

/// IAPサービスプロバイダー
final iapServiceProvider = Provider<IAPService>((ref) {
  return IAPService();
});
