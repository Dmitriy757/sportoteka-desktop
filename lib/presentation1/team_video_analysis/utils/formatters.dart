import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Formatters {
  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return "${h.toString().padLeft(2, '0')}:$m:$s";
    return "$m:$s";
  }

  static Map<String, dynamic> decodeResponse(http.Response resp) {
    try {
      final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) return j;
      return {"success": false, "data": j is List ? j : []};
    } catch (_) {
      return {"success": false};
    }
  }

  static String safeString(dynamic v) => (v ?? "").toString();
  
  static int safeInt(dynamic v) => int.tryParse(safeString(v)) ?? 0;

  static double safeDouble(dynamic v) => double.tryParse(safeString(v)) ?? 0.0;

  static String? normalizeUrl(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    return "https://sportotekaapp.ru${s.startsWith('/') ? s : '/$s'}";
  }

  static Color getEffectColor(int percent) {
    if (percent >= 80) return const Color(0xFF16A34A);
    if (percent >= 60) return const Color(0xFFEAB308);
    if (percent >= 40) return const Color(0xFFF97316);
    return const Color(0xFFDC2626);
  }

  static String formatNumber(double number, {int decimals = 1}) {
    return number.toStringAsFixed(decimals);
  }

  static String formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}