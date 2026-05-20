import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PlanExporter {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String siteBase = "https://sportotekaapp.ru"; // для относительных preview_url

  // ===== “официальный” стиль =====
  static const double bw = 1.0;
  static const double pad = 6.0;
  static const double fs10 = 10;
  static const double fs11 = 11;
  static const double fs12 = 12;

  static const double exH = 430;
  static const double headerH = 34;

  /// ===================== PDF =====================
  static Future<Uint8List> buildPlanPdf({
    required Map<String, dynamic> header,
    required List<Map<String, dynamic>> exercises,
    required String clubName,
    required String trainerName,
    required String teamName,
    required int playersCount,
    required int durationMin,
    required String signedRole,
    required String signedBy,
    Uint8List? clubLogoBytes,
  }) async {
    final fontRegular = await _loadTtf("assets/fonts/times.ttf");
    final fontBold = await _loadTtf("assets/fonts/timesbd.ttf");

    // схемы по ids -> preview_url -> bytes (или null) + debug
    final previewsByExercise = await _loadSchemesPreviewsViaApi(exercises);

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(16, 16, 16, 16),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (ctx) {
          final out = <pw.Widget>[];

          out.add(_buildHeaderLikeSample(
            header: header,
            clubName: clubName,
            trainerName: trainerName,
            teamName: teamName,
            playersCount: playersCount,
            durationMin: durationMin,
            clubLogoBytes: clubLogoBytes,
          ));

          out.add(_buildGoalsLikeSample(header));
          out.add(_buildInventoryLikeSample(header));

          out.add(pw.SizedBox(height: 8));

          for (int i = 0; i < exercises.length; i++) {
            out.add(_buildExerciseLikeSample(
              index: i + 1,
              e: exercises[i],
              images: previewsByExercise[i],
            ));
            out.add(pw.SizedBox(height: 10));
          }

          out.add(_buildSignatureLikeSample(
            signedRole: signedRole,
            signedBy: signedBy,
          ));

          return out;
        },
      ),
    );

    return doc.save();
  }

  /// ===================== DOC (HTML .doc) =====================
  /// Чтобы ошибка пропала: метод ВОЗВРАЩАЕМ в класс.
  static Future<Uint8List> buildPlanDocHtml({
    required Map<String, dynamic> header,
    required List<Map<String, dynamic>> exercises,
    required String clubName,
    required String trainerName,
    required String teamName,
    required int playersCount,
    required int durationMin,
    required String signedRole,
    required String signedBy,
  }) async {
    String esc(String s) => s
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;");

    String g(String k) => (header[k] ?? "").toString().trim();

    final sb = StringBuffer();
    sb.writeln("""
<html>
<head>
<meta charset="utf-8">
<style>
body { font-family: "Times New Roman", serif; font-size: 12px; }
table { border-collapse: collapse; width: 100%; }
td, th { border: 1px solid #000; padding: 6px; vertical-align: top; }
.h { font-weight: 700; text-align: center; }
.gray { background: #f2f2f2; }
.small { font-size: 11px; }
</style>
</head>
<body>

<table>
<tr>
  <td class="h" colspan="4">
    Недельный цикл ${esc(g("cycle"))}<br>
    Дата: ${esc(g("date"))}
  </td>
</tr>
<tr>
  <td><b>Клуб:</b> ${esc(clubName)}</td>
  <td><b>Тренеры:</b> ${esc(trainerName)}</td>
  <td><b>Команда:</b> ${esc(teamName)}</td>
  <td><b>Продолжительность:</b> ${durationMin} мин.</td>
</tr>
<tr>
  <td colspan="2"><b>Место проведения:</b> ${esc(g("location"))}</td>
  <td colspan="2"><b>К-во игроков:</b> ${playersCount}</td>
</tr>
<tr>
  <td><b>Тема:</b></td>
  <td colspan="3"><b>${esc(g("theme"))}</b></td>
</tr>
</table>

<br>

<table>
<tr class="gray">
  <th>Техника</th><th>Тактика</th><th>Фитнес</th><th>Ментальность</th>
</tr>
<tr>
  <td>${esc(g("goal_tech"))}</td>
  <td>${esc(g("goal_tact"))}</td>
  <td>${esc(g("goal_fit"))}</td>
  <td>${esc(g("goal_ment"))}</td>
</tr>
</table>

<br>

<table>
<tr>
  <td style="width:140px;"><b>Инвентарь:</b></td>
  <td>${esc((header["equipment"] ?? "").toString())}</td>
</tr>
</table>

<br>
<h3>Упражнения</h3>
""");

    for (int i = 0; i < exercises.length; i++) {
      final e = exercises[i];
      sb.writeln("""
<table>
<tr class="gray">
  <td colspan="3"><b>${i + 1}. ${esc((e["title"] ?? "Упражнение").toString())}</b></td>
  <td style="width:160px;"><b>Продолжительность:</b> ${(e["duration_min"] ?? 0)} мин.</td>
</tr>
<tr>
  <td style="width:240px; height:180px;">
    <b>Схема/поле:</b><br>
    <span class="small">Схемы: ${esc(_schemesAsText(e["schemes"]))}</span>
  </td>
  <td colspan="3">
    <table>
      <tr class="gray">
        <th>Интенсивность</th><th>К-во повторений</th><th>Время работы</th><th>Пауза</th>
      </tr>
      <tr>
        <td>${esc((e["intensity"] ?? "").toString())}</td>
        <td>${esc((e["repetitions"] ?? "").toString())}</td>
        <td>${esc((e["work_time"] ?? "").toString())}</td>
        <td>${esc((e["pause_time"] ?? "").toString())}</td>
      </tr>
    </table>
    <br>
    <b>Организация:</b><br>${esc((e["organization"] ?? "").toString())}
    <br><br>
    <b>Тренерский акцент:</b><br>${esc((e["coach_focus"] ?? "").toString())}
  </td>
</tr>
</table>
<br>
""");
    }

    sb.writeln("""
<br>
<table>
<tr>
  <td>План-конспект составил<br>${esc(signedRole)}</td>
  <td style="text-align:right;"><b>${esc(signedBy)}</b></td>
</tr>
</table>

</body>
</html>
""");

    return Uint8List.fromList(utf8.encode(sb.toString()));
  }

  // ==========================================================
  // ======================= PDF PARTS =========================
  // ==========================================================
  static pw.Widget _buildHeaderLikeSample({
    required Map<String, dynamic> header,
    required String clubName,
    required String trainerName,
    required String teamName,
    required int playersCount,
    required int durationMin,
    Uint8List? clubLogoBytes,
  }) {
    String g(String k) => (header[k] ?? "").toString().trim();

    return pw.Table(
      border: pw.TableBorder.all(width: bw, color: PdfColors.black),
      columnWidths: {
        0: const pw.FixedColumnWidth(90),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(children: [
          pw.Container(
            height: 92,
            padding: const pw.EdgeInsets.all(6),
            alignment: pw.Alignment.center,
            child: (clubLogoBytes != null && clubLogoBytes.isNotEmpty)
                ? pw.Image(pw.MemoryImage(clubLogoBytes), fit: pw.BoxFit.contain)
                : pw.Text("ЛОГО", style: const pw.TextStyle(fontSize: fs10)),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                alignment: pw.Alignment.center,
                child: pw.Column(
                  children: [
                    pw.Text(
                      "Недельный цикл ${g("cycle")}",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fs12),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text("Дата: ${g("date")}", style: const pw.TextStyle(fontSize: fs11)),
                  ],
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(width: bw, color: PdfColors.black),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(children: [
                    _cellBold("Клуб: $clubName"),
                    _cellBold("Тренеры: $trainerName"),
                    _cellBold("Команда: $teamName"),
                  ]),
                  pw.TableRow(children: [
                    _cellBold("Место проведения:\n${g("location").isEmpty ? "—" : g("location")}"),
                    _cellBold("К-во игроков: $playersCount"),
                    _cellBold("Продолжительность: $durationMin мин."),
                  ]),
                  pw.TableRow(children: [
                    _cellBold("Тема:", centerY: true),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(pad),
                      child: pw.Text(
                        g("theme").isEmpty ? "—" : g("theme"),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fs12),
                      ),
                    ),
                    pw.Container(),
                  ]),
                ],
              ),
            ],
          ),
        ]),
      ],
    );
  }

  static pw.Widget _buildGoalsLikeSample(Map<String, dynamic> header) {
    String g(String k) => (header[k] ?? "").toString().trim();

    return pw.Table(
      border: pw.TableBorder.all(width: bw, color: PdfColors.black),
      columnWidths: {
        0: const pw.FixedColumnWidth(90),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(children: [
          _cellBold("Цели:", centerY: true),
          pw.Table(
            border: pw.TableBorder.all(width: bw, color: PdfColors.black),
            children: [
              pw.TableRow(children: [
                _cellCenterBold("Техника"),
                _cellCenterBold("Тактика"),
                _cellCenterBold("Фитнес"),
                _cellCenterBold("Ментальность"),
              ]),
              pw.TableRow(children: [
                _cellBig(g("goal_tech")),
                _cellBig(g("goal_tact")),
                _cellBig(g("goal_fit")),
                _cellBig(g("goal_ment")),
              ]),
            ],
          ),
        ]),
      ],
    );
  }

  static pw.Widget _buildInventoryLikeSample(Map<String, dynamic> header) {
    final eq = (header["equipment"] ?? "").toString().trim();
    return pw.Table(
      border: pw.TableBorder.all(width: bw, color: PdfColors.black),
      columnWidths: {0: const pw.FixedColumnWidth(110), 1: const pw.FlexColumnWidth(1)},
      children: [
        pw.TableRow(children: [
          _cellBold("Инвентарь:", centerY: true),
          _cell(eq.isEmpty ? "—" : eq),
        ]),
      ],
    );
  }

  static pw.Widget _buildExerciseLikeSample({
    required int index,
    required Map<String, dynamic> e,
    required List<_SchemeImage> images,
  }) {
    final title = (e["title"] ?? "").toString().trim();
    final dur = _asInt(e["duration_min"]);

    final intensity = (e["intensity"] ?? "").toString().trim();
    final reps = (e["repetitions"] ?? "").toString().trim();
    final work = (e["work_time"] ?? "").toString().trim();
    final pause = (e["pause_time"] ?? "").toString().trim();

    final org = (e["organization"] ?? "").toString();
    final focus = (e["coach_focus"] ?? "").toString();

    const paramsH = 95.0;
    const gap = 6.0;
    final remain = exH - headerH - pad * 2 - paramsH - gap * 2;
    final orgH = remain / 2;
    final focusH = remain / 2;

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: bw, color: PdfColors.black)),
      child: pw.Column(
        children: [
          pw.Container(
            height: headerH,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Row(
              children: [
                pw.Text(
                  "$index. ${title.isEmpty ? "Упражнение" : title}",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fs11),
                ),
                pw.Spacer(),
                pw.Text(
                  "Продолжительность: $dur мин.",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fs11),
                ),
              ],
            ),
          ),
          pw.Container(
            height: exH - headerH,
            padding: const pw.EdgeInsets.all(8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  flex: 6,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: bw, color: PdfColors.black)),
                    child: _schemeBox(images),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Container(
                        height: paramsH,
                        child: pw.Table(
                          border: pw.TableBorder.all(width: bw, color: PdfColors.black),
                          children: [
                            pw.TableRow(children: [
                              _cellCenterBold("Интенсивность"),
                              _cellCenterBold("К-во\nповторений"),
                              _cellCenterBold("Время\nработы"),
                              _cellCenterBold("Пауза"),
                            ]),
                            pw.TableRow(children: [
                              _cellCenter(intensity.isEmpty ? "—" : intensity),
                              _cellCenter(reps.isEmpty ? "—" : reps),
                              _cellCenter(work.isEmpty ? "—" : work),
                              _cellCenter(pause.isEmpty ? "—" : pause),
                            ]),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: gap),
                      pw.Container(height: orgH, child: _textBox("Организация:", org)),
                      pw.SizedBox(height: gap),
                      pw.Container(height: focusH, child: _textBox("Тренерский акцент:", focus)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _schemeBox(List<_SchemeImage> images) {
    // ✅ Если ничего не скачалось — покажем ПРИЧИНУ внутри PDF (важно!)
    if (images.isEmpty) {
      return pw.Center(
        child: pw.Text(
          "Схемы не прикреплены\nили превью недоступно",
          style: const pw.TextStyle(fontSize: fs11),
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    // Берём первую как главную
    final main = images.first;

    // Если main.bytes == null -> покажем id/url и тип, чтобы понять почему не рисуется
    if (main.bytes == null) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(10),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text("❌ Схема не загрузилась", style: pw.TextStyle(fontSize: fs12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text("id: ${main.id}", style: const pw.TextStyle(fontSize: fs11)),
            pw.SizedBox(height: 4),
            pw.Text(main.url.isEmpty ? "url: (пусто)" : "url: ${main.url}", style: const pw.TextStyle(fontSize: fs10)),
            pw.SizedBox(height: 6),
            pw.Text(
              "Чаще всего причина: WEBP/SVG или 403/HTML вместо картинки.",
              style: const pw.TextStyle(fontSize: fs10),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Image(pw.MemoryImage(main.bytes!), fit: pw.BoxFit.contain),
    );
  }

  static pw.Widget _buildSignatureLikeSample({
    required String signedRole,
    required String signedBy,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(width: bw, color: PdfColors.black),
      columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(1)},
      children: [
        pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text("План-конспект составил\n$signedRole", style: const pw.TextStyle(fontSize: fs11)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                signedBy.trim().isEmpty ? "—" : signedBy.trim(),
                style: pw.TextStyle(fontSize: fs11, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ==========================================================
  // =================== SCHEMES: API =========================
  // ==========================================================
  static Future<List<List<_SchemeImage>>> _loadSchemesPreviewsViaApi(
    List<Map<String, dynamic>> exercises,
  ) async {
    final allIds = <int>{};
    for (final e in exercises) {
      allIds.addAll(_asIntList(e["schemes"]));
    }

    if (allIds.isEmpty) {
      return List.generate(exercises.length, (_) => <_SchemeImage>[]);
    }

    final map = await _fetchPreviewsMap(allIds.toList());

    final result = <List<_SchemeImage>>[];
    for (final e in exercises) {
      final ids = _asIntList(e["schemes"]);
      final list = <_SchemeImage>[];

      for (final id in ids.take(6)) {
        final raw = (map[id] ?? "").trim();
        final abs = _absoluteUrl(raw);
        final bytes = abs.isEmpty ? null : await _downloadImageSafe(abs);
        list.add(_SchemeImage(id: id, url: abs, bytes: bytes));
      }

      result.add(list);
    }

    return result;
  }

  static Future<Map<int, String>> _fetchPreviewsMap(List<int> ids) async {
    try {
      final r = await http.post(
        Uri.parse("$apiBase/get_training_graphics_previews.php"),
        headers: {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode({"ids": ids}),
      );

      if (r.statusCode != 200) return {};
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is! Map || j["success"] != true) return {};

      final items = j["items"];
      if (items is! List) return {};

      final out = <int, String>{};
      for (final it in items) {
        if (it is Map) {
          final id = _asInt(it["id"]);
          final url = (it["preview_url"] ?? "").toString().trim();
          if (id > 0 && url.isNotEmpty) out[id] = url;
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static String _absoluteUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return "";
    if (u.startsWith("http://") || u.startsWith("https://")) return u;
    if (u.startsWith("/")) return "$siteBase$u";
    return "$siteBase/$u";
  }

  static Future<Uint8List?> _downloadImageSafe(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      final r = await http.get(
        uri,
        headers: {
          "User-Agent": "SportotekaApp/1.0",
          "Accept": "image/*,*/*;q=0.8",
        },
      );

      if (r.statusCode != 200 || r.bodyBytes.isEmpty) return null;

      // Если сервер отдаёт webp/svg — pdf пакет не отрисует.
      final ct = (r.headers["content-type"] ?? "").toLowerCase();
      if (ct.contains("image/webp") || ct.contains("image/svg")) {
        return null;
      }

      // Иногда сервер отдаёт HTML (403/redirect) — тоже не рисуем
      if (ct.contains("text/html")) return null;

      return r.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  // ==========================================================
  // ======================= CELLS ============================
  // ==========================================================
  static pw.Widget _cell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(pad),
        child: pw.Text(text.isEmpty ? "—" : text, style: const pw.TextStyle(fontSize: fs11)),
      );

  static pw.Widget _cellBold(String text, {bool centerY = false}) => pw.Container(
        padding: const pw.EdgeInsets.all(pad),
        alignment: centerY ? pw.Alignment.center : pw.Alignment.topLeft,
        child: pw.Text(text, style: pw.TextStyle(fontSize: fs11, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _cellCenter(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(pad),
        child: pw.Center(
          child: pw.Text(text.isEmpty ? "—" : text, style: const pw.TextStyle(fontSize: fs11)),
        ),
      );

  static pw.Widget _cellCenterBold(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(pad),
        child: pw.Center(
          child: pw.Text(text, style: pw.TextStyle(fontSize: fs11, fontWeight: pw.FontWeight.bold)),
        ),
      );

  static pw.Widget _cellBig(String text) => pw.Container(
        height: 78,
        padding: const pw.EdgeInsets.all(pad),
        alignment: pw.Alignment.center,
        child: pw.Text(
          text.trim().isEmpty ? "—" : text.trim(),
          style: pw.TextStyle(fontSize: fs11, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
      );

  static pw.Widget _textBox(String title, String value) {
    final v = value.trim();
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: bw, color: PdfColors.black)),
      padding: const pw.EdgeInsets.all(pad),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fs11)),
          pw.SizedBox(height: 4),
          pw.Text(v.isEmpty ? "—" : v, style: const pw.TextStyle(fontSize: fs11)),
        ],
      ),
    );
  }

  // ==========================================================
  // ======================= HELPERS ==========================
  // ==========================================================
  static Future<pw.Font> _loadTtf(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return pw.Font.ttf(data);
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = (v ?? "").toString().trim();
    return int.tryParse(s) ?? 0;
  }

  static List<int> _asIntList(dynamic v) {
    if (v == null) return <int>[];
    if (v is List) return v.map((x) => _asInt(x)).where((x) => x > 0).toList();
    final s = v.toString().trim();
    if (s.isEmpty || s == "null") return <int>[];
    if (s.startsWith("[") && s.endsWith("]")) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is List) return decoded.map((x) => _asInt(x)).where((x) => x > 0).toList();
      } catch (_) {}
    }
    return s.split(",").map((e) => int.tryParse(e.trim()) ?? 0).where((x) => x > 0).toList();
  }

  static String _schemesAsText(dynamic v) {
    if (v == null) return "";
    if (v is List) return v.map((e) => e.toString()).join(", ");
    final s = v.toString().trim();
    if (s.isEmpty || s == "null") return "";
    return s;
  }
}

class _SchemeImage {
  final int id;
  final String url;
  final Uint8List? bytes;

  _SchemeImage({required this.id, required this.url, required this.bytes});
}
