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
                      pw.Container(
                        width: 2,
                        height: 30,
                        margin:
                            const pw.EdgeInsets.symmetric(horizontal: 8),
                        color: accent,
                      ),
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

    onProgress?.call('完了', 1.0);
    return pdf.save();
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

  /// NotoSansJPフォントをダウンロードしてメモリキャッシュ
  static Future<pw.Font> _loadJapaneseFont({bool bold = false}) async {
    if (bold && _cachedBoldFont != null) return _cachedBoldFont!;
    if (!bold && _cachedFont != null) return _cachedFont!;

    try {
      final weightValue = bold ? '700' : '400';
      final cssUrl =
          'https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@$weightValue&display=swap';

      // CSSをダウンロード
      final cssResponse = await http.get(
        Uri.parse(cssUrl),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );
      if (cssResponse.statusCode != 200) {
        return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
      }
      final css = cssResponse.body;

      // CSSからフォントURLを抽出（TTF or OTF）
      final fontUrlMatch =
          RegExp(r'url\((https://[^)]+\.(?:ttf|otf))\)').firstMatch(css);
      if (fontUrlMatch == null) {
        return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
      }

      // フォントファイルをダウンロード
      final fontResponse = await http.get(Uri.parse(fontUrlMatch.group(1)!));
      if (fontResponse.statusCode != 200) {
        return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
      }

      final font = pw.Font.ttf(
        ByteData.sublistView(fontResponse.bodyBytes),
      );
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
