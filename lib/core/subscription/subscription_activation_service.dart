import 'dart:convert';
import 'package:http/http.dart' as http;

class SubscriptionActivationService {
  static const String _base = 'https://sportotekaapp.ru/api';
  static const String _url = '$_base/set_user_subscription.php';

  static Future<Map<String, dynamic>> activatePlan({
    required int userId,
    required String role,
    required String planCode,
    required bool isYearly,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        body: {
          "user_id": userId.toString(),
          "role": role,
          "plan_code": planCode,
          "billing_period": isYearly ? "yearly" : "monthly",
          "is_active": "1",
        },
      );

      final body = utf8.decode(response.bodyBytes);
      final jsonData = json.decode(body);

      if (jsonData is Map<String, dynamic>) {
        return jsonData;
      }

      return {"success": false, "message": "Invalid response"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }
}