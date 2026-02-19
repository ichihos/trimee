import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/plan_model.dart';

class PlanExportService {
  static pw.Font? _cachedFont;
  static pw.Font? _cachedBoldFont;

  /// ウィジェットを画像としてキャプチャし、一時ファイルパスを返す
  static Future<String> exportAsImage(GlobalKey key) async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/plan_$timestamp.png');
    await file.writeAsBytes(pngBytes);

    return file.path;
  }

  /// プランをPDF形式で生成し、一時ファイルパスを返す
  static Future<String> exportAsPdf({
    required PlanModel plan,
    required String tripTitle,
    DateTime? startDate,
  }) async {
    // 日本語フォントをロード
    final font = await _loadJapaneseFont();
    final boldFont = await _loadJapaneseFont(bold: true);

    final pdf = pw.Document();
    final boldStyle = pw.TextStyle(font: boldFont, fontSize: 10);
    final titleStyle = pw.TextStyle(font: boldFont, fontSize: 18);
    final subtitleStyle = pw.TextStyle(font: boldFont, fontSize: 14);
    final captionStyle = pw.TextStyle(
      font: font,
      fontSize: 8,
      color: PdfColors.grey600,
    );

    // 日ごとにグループ化
    final itemsByDay = <int, List<PlanItem>>{};
    for (final item in plan.items) {
      itemsByDay.putIfAbsent(item.day, () => []).add(item);
    }
    final days = itemsByDay.keys.toList()..sort();

    // accentカラー
    const accent = PdfColor.fromInt(0xFFC4785B);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader(
          tripTitle: tripTitle,
          planTitle: plan.title,
          description: plan.description,
          startDate: startDate,
          days: days,
          titleStyle: titleStyle,
          subtitleStyle: subtitleStyle,
          captionStyle: captionStyle,
          accent: accent,
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'trimeeで作成  |  ${context.pageNumber} / ${context.pagesCount}',
            style: captionStyle,
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          for (final day in days) {
            final dayItems = itemsByDay[day]!
              ..sort((a, b) => a.time.compareTo(b.time));

            // 日付ヘッダー
            String dayLabel = '$day日目';
            if (startDate != null) {
              final date = startDate.add(Duration(days: day - 1));
              const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
              dayLabel +=
                  '  ${date.month}/${date.day}（${weekdays[date.weekday - 1]}）';
            }

            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 16, bottom: 8),
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  dayLabel,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 11,
                    color: PdfColors.white,
                  ),
                ),
              ),
            );

            // アイテム
            for (final item in dayItems) {
              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 4),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // 時刻
                      pw.SizedBox(
                        width: 50,
                        child: pw.Text(
                          item.time,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 11,
                            color: accent,
                          ),
                        ),
                      ),
                      // 縦線
                      pw.Container(
                        width: 2,
                        height: 30,
                        margin:
                            const pw.EdgeInsets.symmetric(horizontal: 8),
                        color: accent,
                      ),
                      // 内容
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.location, style: boldStyle),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 2),
                                child:
                                    pw.Text(item.notes!, style: captionStyle),
                              ),
                          ],
                        ),
                      ),
                      // 所要時間
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          '${item.durationMinutes}分',
                          style: captionStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }

          return widgets;
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/plan_$timestamp.pdf');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  static pw.Widget _buildPdfHeader({
    required String tripTitle,
    required String planTitle,
    String? description,
    DateTime? startDate,
    required List<int> days,
    required pw.TextStyle titleStyle,
    required pw.TextStyle subtitleStyle,
    required pw.TextStyle captionStyle,
    required PdfColor accent,
  }) {
    String? dateRange;
    if (startDate != null && days.isNotEmpty) {
      final endDate = startDate.add(Duration(days: days.last - 1));
      dateRange =
          '${startDate.month}/${startDate.day} - ${endDate.month}/${endDate.day}';
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(tripTitle, style: titleStyle),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Text(planTitle, style: subtitleStyle.copyWith(color: accent)),
              if (dateRange != null) ...[
                pw.SizedBox(width: 12),
                pw.Text(dateRange, style: captionStyle),
              ],
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(description, style: captionStyle),
          ],
        ],
      ),
    );
  }

  /// NotoSansJPフォントをダウンロードしてキャッシュ、pdf用Fontとして返す
  static Future<pw.Font> _loadJapaneseFont({bool bold = false}) async {
    // キャッシュチェック
    if (bold && _cachedBoldFont != null) return _cachedBoldFont!;
    if (!bold && _cachedFont != null) return _cachedFont!;

    try {
      final dir = await getApplicationSupportDirectory();
      final weight = bold ? 'Bold' : 'Regular';
      final cacheFile = File('${dir.path}/NotoSansJP-$weight.ttf');

      // キャッシュ済みファイルがあればそれを使用
      if (cacheFile.existsSync()) {
        final bytes = await cacheFile.readAsBytes();
        final font = pw.Font.ttf(ByteData.sublistView(bytes));
        if (bold) {
          _cachedBoldFont = font;
        } else {
          _cachedFont = font;
        }
        return font;
      }

      // Google Fonts CDNからダウンロード
      final weightValue = bold ? '700' : '400';
      final url = Uri.parse(
        'https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@$weightValue&display=swap',
      );

      final client = HttpClient();
      final cssRequest = await client.getUrl(url);
      cssRequest.headers.set('User-Agent', 'Mozilla/5.0');
      final cssResponse = await cssRequest.close();
      final css = await cssResponse.transform(const SystemEncoding().decoder).join();

      // CSSからフォントURLを抽出
      final fontUrlMatch = RegExp(r'url\((https://[^)]+\.ttf)\)').firstMatch(css);
      if (fontUrlMatch == null) {
        // OTF形式も試す
        final otfMatch = RegExp(r'url\((https://[^)]+\.otf)\)').firstMatch(css);
        if (otfMatch == null) {
          return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
        }
        final fontUrl = Uri.parse(otfMatch.group(1)!);
        final fontRequest = await client.getUrl(fontUrl);
        final fontResponse = await fontRequest.close();
        final fontBytes = await _collectBytes(fontResponse);
        await cacheFile.writeAsBytes(fontBytes);
        final font = pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(fontBytes)));
        if (bold) {
          _cachedBoldFont = font;
        } else {
          _cachedFont = font;
        }
        client.close();
        return font;
      }

      final fontUrl = Uri.parse(fontUrlMatch.group(1)!);
      final fontRequest = await client.getUrl(fontUrl);
      final fontResponse = await fontRequest.close();
      final fontBytes = await _collectBytes(fontResponse);
      await cacheFile.writeAsBytes(fontBytes);
      client.close();

      final font = pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(fontBytes)));
      if (bold) {
        _cachedBoldFont = font;
      } else {
        _cachedFont = font;
      }
      return font;
    } catch (e) {
      debugPrint('Error loading Japanese font: $e');
      return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
    }
  }

  static Future<List<int>> _collectBytes(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return bytes;
  }
}
