import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/constants/iap_constants.dart';

/// RevenueCatを使ったアプリ内課金サービス
///
/// iOS、Android、Webで統一的に課金を管理
/// - 消耗型アイテム: AI生成1回分（¥120）
/// - 復元: 過去の購入履歴を復元
class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  bool _isInitialized = false;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;

  /// 初期化済みかどうか
  bool get isInitialized => _isInitialized;

  /// 現在の顧客情報
  CustomerInfo? get customerInfo => _customerInfo;

  /// RevenueCat初期化
  Future<void> initialize(String userId) async {
    if (_isInitialized) return;

    try {
      // プラットフォーム別のAPIキー
      String apiKey;
      if (kIsWeb) {
        apiKey = IAPConstants.revenueCatApiKeyWeb;
      } else if (Platform.isIOS) {
        apiKey = IAPConstants.revenueCatApiKeyIOS;
      } else if (Platform.isAndroid) {
        apiKey = IAPConstants.revenueCatApiKeyAndroid;
      } else {
        throw UnsupportedError('Unsupported platform for IAP');
      }

      // RevenueCat設定
      final configuration = PurchasesConfiguration(apiKey);

      // デバッグログ設定
      if (IAPConstants.enableDebugLogs) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      await Purchases.configure(configuration);

      // ユーザーIDを設定（匿名ユーザーの場合はデフォルトのまま）
      if (userId.isNotEmpty && !userId.startsWith('guest_')) {
        await Purchases.logIn(userId);
      }

      // 顧客情報を取得
      _customerInfo = await Purchases.getCustomerInfo();

      // オファリング（商品情報）を取得
      _offerings = await Purchases.getOfferings();

      _isInitialized = true;

      if (IAPConstants.enableDebugLogs) {
        print('[IAPService] Initialized successfully');
        print('[IAPService] User ID: $userId');
        print('[IAPService] Customer Info: ${_customerInfo?.originalAppUserId}');
      }
    } catch (e) {
      print('[IAPService] Initialization failed: $e');
      rethrow;
    }
  }

  /// AI生成商品を取得
  Future<Package?> getAiGenerationPackage() async {
    if (!_isInitialized) {
      throw StateError('IAPService is not initialized');
    }

    try {
      // オファリングを再取得（最新の価格を確保）
      _offerings = await Purchases.getOfferings();

      final offering = _offerings?.current;
      if (offering == null) {
        print('[IAPService] No current offering found');
        return null;
      }

      // 商品IDで検索
      final package = offering.availablePackages.firstWhere(
        (pkg) => pkg.storeProduct.identifier == IAPConstants.aiGenerationProductId,
        orElse: () => throw StateError('AI generation product not found'),
      );

      return package;
    } catch (e) {
      print('[IAPService] Failed to get AI generation package: $e');
      return null;
    }
  }

  /// AI生成を購入
  ///
  /// Returns:
  /// - `true`: 購入成功
  /// - `false`: 購入失敗またはキャンセル
  Future<bool> purchaseAiGeneration() async {
    if (!_isInitialized) {
      throw StateError('IAPService is not initialized');
    }

    try {
      final package = await getAiGenerationPackage();
      if (package == null) {
        print('[IAPService] Cannot purchase: package not found');
        return false;
      }

      // 購入実行
      _customerInfo = await Purchases.purchasePackage(package);

      // 購入成功確認
      final hasPurchased = _customerInfo!.entitlements.active
          .containsKey(IAPConstants.aiGenerationEntitlementId);

      if (IAPConstants.enableDebugLogs) {
        print('[IAPService] Purchase result: $hasPurchased');
        print('[IAPService] Customer Info: $_customerInfo');
      }

      return hasPurchased;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        print('[IAPService] Purchase cancelled by user');
        return false;
      }
      print('[IAPService] Purchase failed: ${e.message}');
      return false;
    } catch (e) {
      print('[IAPService] Purchase error: $e');
      return false;
    }
  }

  /// 購入を復元
  ///
  /// Returns:
  /// - 復元された顧客情報
  Future<CustomerInfo?> restorePurchases() async {
    if (!_isInitialized) {
      throw StateError('IAPService is not initialized');
    }

    try {
      _customerInfo = await Purchases.restorePurchases();

      if (IAPConstants.enableDebugLogs) {
        print('[IAPService] Purchases restored');
        print('[IAPService] Active entitlements: ${_customerInfo?.entitlements.active.keys}');
      }

      return _customerInfo;
    } catch (e) {
      print('[IAPService] Restore failed: $e');
      return null;
    }
  }

  /// AI生成の権限を持っているか確認
  ///
  /// Note: 消耗型アイテムの場合、購入後すぐに消費されるため、
  /// この関数は主に購入直後の確認用です。
  bool hasAiGenerationEntitlement() {
    if (_customerInfo == null) return false;

    return _customerInfo!.entitlements.active
        .containsKey(IAPConstants.aiGenerationEntitlementId);
  }

  /// 顧客情報を更新
  Future<void> refreshCustomerInfo() async {
    if (!_isInitialized) return;

    try {
      _customerInfo = await Purchases.getCustomerInfo();
    } catch (e) {
      print('[IAPService] Failed to refresh customer info: $e');
    }
  }

  /// ログアウト（ユーザー切り替え時）
  Future<void> logout() async {
    if (!_isInitialized) return;

    try {
      _customerInfo = await Purchases.logOut();
      if (IAPConstants.enableDebugLogs) {
        print('[IAPService] User logged out');
      }
    } catch (e) {
      print('[IAPService] Logout failed: $e');
    }
  }

  /// 価格を取得（表示用）
  Future<String> getAiGenerationPrice() async {
    try {
      final package = await getAiGenerationPackage();
      if (package != null) {
        return package.storeProduct.priceString;
      }
    } catch (e) {
      print('[IAPService] Failed to get price: $e');
    }
    return IAPConstants.aiGenerationPriceDisplay;
  }
}
