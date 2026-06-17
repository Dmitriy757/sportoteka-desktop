import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class TrainingGraphicsApi {
  static const String base = "https://sportotekaapp.ru/api";

  static Map<String, dynamic> _decode(http.Response r) {
    final body = r.body.trim();
    if (body.isEmpty) {
      return {"success": false, "message": "Empty response", "statusCode": r.statusCode};
    }
    if (body.startsWith("<") || body.contains("<br") || body.contains("<b>")) {
      return {
        "success": false,
        "message": "Server returned HTML (not JSON). Check PHP errors.",
        "raw": body.length > 2000 ? body.substring(0, 2000) : body,
        "statusCode": r.statusCode,
      };
    }
    try {
      final j = json.decode(body);
      if (j is Map<String, dynamic>) return j;
      return {"success": false, "message": "Bad JSON: not a map", "raw": body, "statusCode": r.statusCode};
    } catch (e) {
      return {"success": false, "message": "Bad JSON: $e", "raw": body, "statusCode": r.statusCode};
    }
  }

  /// list
static Future<Map<String, dynamic>> list({
  required int clubId,
  required int teamId,
  required int folderId,
}) async {
  // ✅ корень = 0
  final safeFolderId = folderId;

  final payload = <String, dynamic>{
    // club
    "club_id": clubId,
    "clubId": clubId, // ✅ совместимость

    // team
    "team_id": teamId,
    "teamId": teamId, // ✅ совместимость

    // folder
    "folder_id": safeFolderId,
    "folderId": safeFolderId, // ✅ совместимость
  };

  final r = await http.post(
    Uri.parse("$base/list_training_graphics.php"),
    headers: {"Content-Type": "application/json; charset=utf-8"},
    body: jsonEncode(payload),
  );

  // ✅ лог как у plans (очень помогает)
  // ignore: avoid_print
  print("POST $base/list_training_graphics.php");
  // ignore: avoid_print
  print("REQ: ${jsonEncode(payload)}");
  // ignore: avoid_print
  print("RES(${r.statusCode}): ${r.body}");

  return _decode(r);
}

  /// get single
  static Future<Map<String, dynamic>> get({
    required int graphicId,
  }) async {
    final r = await http.get(Uri.parse("$base/get_training_graphic.php?id=$graphicId"));
    return _decode(r);
  }

  /// ✅ SAVE (create/update)
  /// - если graphicId == null -> create
  /// - иначе -> update
  ///
  /// Требует PHP: save_training_graphic.php
  static Future<Map<String, dynamic>> save({
    required int clubId,
    required int teamId,
    required int folderId,
    required int createdBy,
    required String title,
    required String docJson,
    Uint8List? previewPngBytes,
    int? graphicId,
  }) async {
    final uri = Uri.parse("$base/save_training_graphic.php");
    final req = http.MultipartRequest("POST", uri);

    req.fields["club_id"] = clubId.toString();
    req.fields["team_id"] = teamId.toString();
    req.fields["folder_id"] = folderId.toString();
    req.fields["created_by"] = createdBy.toString();
    req.fields["title"] = title.trim();
    req.fields["doc_json"] = docJson;

    if (graphicId != null && graphicId > 0) {
      req.fields["id"] = graphicId.toString();
    }

    if (previewPngBytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          "preview",
          previewPngBytes,
          filename: "preview.png",
        ),
      );
    }

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    return _decode(resp);
  }
}
