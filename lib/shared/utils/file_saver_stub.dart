import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// ネイティブ: 一時ファイルに保存してパスを返す
Future<String> saveToFile(Uint8List bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}

/// ネイティブではブラウザダウンロードは不要
void triggerBrowserDownload(Uint8List bytes, String filename, String mimeType) {
  // no-op on native
}
