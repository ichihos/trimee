import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/plan_model.dart';

class PlanExportService {
  static pw.Font? _cachedFont;
  static pw.Font? _cachedBoldFont;

  /// ウィジェットを画像としてキャプチャし、PNGバイトを返す
  static Future<Uint8List> exportImageAsBytes(
    GlobalKey key, {
    double pixelRatio = 3.0,
    Function(String stage, double progress)? onProgress,
  }) async {
    onProgress?.call('画面をキャプチャ中...', 0.0);

    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;

    onProgress?.call('高解像度レンダリング中...', 0.3);
    final image = await boundary.toImage(pixelRatio: pixelRatio);

    onProgress?.call('画像を変換中...', 0.6);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    onProgress?.call('完了', 1.0);
    return pngBytes;
  }

  /// プランをPDF形式で生成し、バイトを返す
  static Future<Uint8List> exportPdfAsBytes({
    required PlanModel plan,
    required String tripTitle,
    DateTime? startDate,
    Function(String stage, double progress)? onProgress,
  }) async {
    onProgress?.call('フォントをダウンロード中...', 0.0);
    final font = await _loadJapaneseFont();
    onProgress?.call('太字フォントをロード中...', 0.2);
    final boldFont = await _loadJapaneseFont(bold: true);

    onProgress?.call('PDFを構築中...', 0.4);

    final pdf = pw.Document();

    // スタイル定義
    final boldStyle = pw.TextStyle(font: boldFont, fontSize: 10);
    final titleStyle = pw.TextStyle(font: boldFont, fontSize: 22);
    final subtitleStyle = pw.TextStyle(font: boldFont, fontSize: 13);
    final captionStyle = pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600);
    final timeStyle = pw.TextStyle(font: boldFont, fontSize: 11);

    // 日ごとにグループ化
    final itemsByDay = <int, List<PlanItem>>{};
    for (final item in plan.items) {
      itemsByDay.putIfAbsent(item.day, () => []).add(item);
    }
    final days = itemsByDay.keys.toList()..sort();

    const accent = PdfColor.fromInt(0xFFC4785B);
    const accentLight = PdfColor.fromInt(0xFFFFF3EE);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) {
          // 最初のページのみヘッダーを表示
          if (context.pageNumber > 1) return pw.SizedBox();

          String? dateRange;
          if (startDate != null && days.isNotEmpty) {
            final endDate = startDate.add(Duration(days: days.last - 1));
            const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
            final startW = weekdays[startDate.weekday - 1];
            final endW = weekdays[endDate.weekday - 1];
            dateRange =
                '${startDate.year}/${startDate.month}/${startDate.day}（$startW）'
                ' - ${endDate.month}/${endDate.day}（$endW）';
          }

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 24),
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: accentLight,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border(left: pw.BorderSide(color: accent, width: 4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(tripTitle, style: titleStyle),
                if (plan.title != tripTitle) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(plan.title, style: subtitleStyle.copyWith(color: accent)),
                ],
                if (dateRange != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: accent,
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.Text(dateRange,
                          style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.white)),
                      ),
                    ],
                  ),
                ],
                if (plan.description != null && plan.description!.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(plan.description!, style: captionStyle),
                ],
              ],
            ),
          );
        },
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('trimee しおり', style: captionStyle.copyWith(color: accent)),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: captionStyle,
              ),
            ],
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          for (final day in days) {
            final dayItems = itemsByDay[day]!
              ..sort((a, b) => a.time.compareTo(b.time));

            // Day ラベル
            String dayLabel = 'Day $day';
            if (startDate != null) {
              final date = startDate.add(Duration(days: day - 1));
              const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
              dayLabel += '  ${date.month}/${date.day}（${weekdays[date.weekday - 1]}）';
            }

            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 18, bottom: 10),
                child: pw.Row(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: accent,
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Text(dayLabel,
                        style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.white)),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        margin: const pw.EdgeInsets.only(left: 8),
                        height: 1,
                        color: PdfColors.grey300,
                      ),
                    ),
                  ],
                ),
              ),
            );

            // アイテム
            for (final item in dayItems) {
              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(8),
                    color: item.isBooked ? const PdfColor.fromInt(0xFFF0FFF0) : null,
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // 時間カラム
                      pw.SizedBox(
                        width: 48,
                        child: pw.Column(
                          children: [
                            pw.Text(item.time, style: timeStyle.copyWith(color: accent)),
                            pw.SizedBox(height: 2),
                            pw.Text('${item.durationMinutes}分', style: captionStyle),
                          ],
                        ),
                      ),
                      // タイムライン
                      pw.Container(
                        width: 2,
                        height: 36,
                        margin: const pw.EdgeInsets.symmetric(horizontal: 8),
                        decoration: pw.BoxDecoration(
                          color: accent,
                          borderRadius: pw.BorderRadius.circular(1),
                        ),
                      ),
                      // コンテンツ
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.location.isEmpty ? '（未定）' : item.location,
                              style: boldStyle,
                            ),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 3),
                                child: pw.Text(item.notes!, style: captionStyle),
                              ),
                            if (item.isBooked)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 3),
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: const PdfColor.fromInt(0xFF4CAF50),
                                    borderRadius: pw.BorderRadius.circular(8),
                                  ),
                                  child: pw.Text('予約済み',
                                    style: pw.TextStyle(font: boldFont, fontSize: 7, color: PdfColors.white)),
                                ),
                              ),
                          ],
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

    onProgress?.call('完了', 1.0);
    return pdf.save();
  }

  /// NotoSansJPフォントをダウンロードしてメモリキャッシュ
  static Future<pw.Font> _loadJapaneseFont({bool bold = false}) async {
    if (bold && _cachedBoldFont != null) return _cachedBoldFont!;
    if (!bold && _cachedFont != null) return _cachedFont!;

    try {
      final weightValue = bold ? '700' : '400';
      final cssUrl =
          'https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@$weightValue&display=swap';

      final cssResponse = await http.get(
        Uri.parse(cssUrl),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );
      if (cssResponse.statusCode != 200) {
        return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
      }
      final css = cssResponse.body;

      final fontUrlMatch =
          RegExp(r'url\((https://[^)]+\.(?:ttf|otf))\)').firstMatch(css);
      if (fontUrlMatch == null) {
        return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
      }

      final fontResponse = await http.get(Uri.parse(fontUrlMatch.group(1)!));
      if (fontResponse.statusCode != 200) {
        return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
      }

      final font = pw.Font.ttf(ByteData.sublistView(fontResponse.bodyBytes));
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
}
