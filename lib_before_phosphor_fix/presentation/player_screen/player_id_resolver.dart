import 'dart:convert';
import 'package:http/http.dart' as http;

class PlayerIdResolver {
  static Future<int> resolvePlayerId({
    required String apiBase,
    required int userId,
  }) async {
    if (userId <= 0) return 0;

    final url = Uri.parse("$apiBase/get_my_player_id.php?user_id=$userId");
    final r = await http.get(url).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return 0;

    final data = jsonDecode(r.body);
    if (data is Map && data["success"] == true) {
      return int.tryParse("${data["player_id"] ?? 0}") ?? 0;
    }
    return 0;
  }
}
