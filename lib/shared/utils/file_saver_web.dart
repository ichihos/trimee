import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web: ファイル保存は不可、空文字を返す
Future<String> saveToFile(Uint8List bytes, String filename) async {
  // Web にはファイルシステムがないのでブラウザダウンロードを使用
  triggerBrowserDownload(bytes, filename, _mimeTypeFromFilename(filename));
  return '';
}

/// Web: ブラウザダウンロードをトリガー
void triggerBrowserDownload(Uint8List bytes, String filename, String mimeType) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

String _mimeTypeFromFilename(String filename) {
  if (filename.endsWith('.pdf')) return 'application/pdf';
  if (filename.endsWith('.png')) return 'image/png';
  return 'application/octet-stream';
}
