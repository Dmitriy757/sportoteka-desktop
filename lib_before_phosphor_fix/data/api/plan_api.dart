class PlanApi {
  static const String base = "https://sportotekaapp.ru/api";

  static Future<Map<String, dynamic>> getPlan(int planId) async {
    final r = await http.get(Uri.parse("$base/get_training_plan.php?plan_id=$planId"));
    return json.decode(r.body);
  }

  static Future<Map<String, dynamic>> createPlan(Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse("$base/create_training_plan.php"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(body),
    );
    return json.decode(r.body);
  }

  static Future<Map<String, dynamic>> updatePlan(Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse("$base/update_training_plan.php"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(body),
    );
    return json.decode(r.body);
  }
}
