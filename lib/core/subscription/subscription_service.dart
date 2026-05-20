import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'subscription_access.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/core/subscription/subscription_activation_service.dart';

class SubscriptionService {
  static const String _base = 'https://sportotekaapp.ru/api';
  static const String _getSubscriptionUrl = '$_base/get_user_subscription.php';

  static Map<String, dynamic> _decode(http.Response resp) {
    final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();

    if (body.startsWith('<')) {
      debugPrint('Subscription API returned HTML: $body');
      return {
        "success": false,
        "message": "Server returned HTML instead of JSON"
      };
    }

    try {
      final jsonData = json.decode(body);
      if (jsonData is Map<String, dynamic>) return jsonData;
      return {"success": false, "message": "Invalid JSON"};
    } catch (e) {
      debugPrint('Subscription JSON parse error: $e; body=$body');
      return {"success": false, "message": "JSON parse error: $e"};
    }
  }

  static Future<SubscriptionAccess> getUserSubscription({
    required int userId,
    required String role,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse(_getSubscriptionUrl),
        body: {
          'user_id': userId.toString(),
          'role': role,
        },
      );

      final data = _decode(resp);

      if (data['success'] == true && data['subscription'] is Map) {
        return SubscriptionAccess.fromJson(
          Map<String, dynamic>.from(data['subscription']),
        );
      }

      debugPrint('Subscription API unsuccessful: $data');
      return SubscriptionAccess.free();
    } catch (e) {
      debugPrint('Subscription request failed: $e');
      return SubscriptionAccess.free();
    }
  }
}