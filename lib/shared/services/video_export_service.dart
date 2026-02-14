import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VideoExportService {
  static const _channel = MethodChannel('com.trimee.video_export');

  /// 画面録画が利用可能かチェック
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (e) {
      debugPrint('VideoExportService.isAvailable error: $e');
      return false;
    }
  }

  /// 画面録画を開始
  static Future<bool> startRecording() async {
    try {
      final result = await _channel.invokeMethod<bool>('startRecording');
      return result ?? false;
    } catch (e) {
      debugPrint('VideoExportService.startRecording error: $e');
      return false;
    }
  }

  /// 画面録画を停止し、カメラロール/ギャラリーに保存
  /// 成功時は保存先パスを返す
  static Future<String?> stopRecording() async {
    try {
      final result = await _channel.invokeMethod<String>('stopRecording');
      return result;
    } catch (e) {
      debugPrint('VideoExportService.stopRecording error: $e');
      return null;
    }
  }
}
