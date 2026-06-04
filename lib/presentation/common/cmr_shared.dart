// lib/presentation/common/cmr_shared.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==================== ЦВЕТОВАЯ СХЕМА (общая) ====================

class CmrColors {
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF6F8FA);
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color green = Color(0xFF1F7A4D);
  static const Color greenDark = Color(0xFF1F7A4D);
  static const Color greenSoft = Color(0xFFF2F7F4);
  static const Color greenBorder = Color(0xFFD7E8DE);
  static const Color orange = Color(0xFFEA580C);
  static const Color violet = Color(0xFF7C3AED);
  static const Color red = Color(0xFFD92D20);
}

// ==================== ТЕКСТОВЫЕ СТИЛИ (общие) ====================

class CmrTextStyle {
  static TextStyle title(double size) => TextStyle(
        color: CmrColors.text,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.12,
      );

  static TextStyle section({double size = 16}) => TextStyle(
        color: CmrColors.text,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.18,
      );

  static TextStyle value(double size) => TextStyle(
        color: CmrColors.text,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.35,
      );

  static TextStyle muted(double size, {FontWeight weight = FontWeight.w600}) => TextStyle(
        color: CmrColors.muted,
        fontSize: size,
        fontWeight: weight,
        height: 1.42,
      );

  static TextStyle pill() => const TextStyle(
        color: CmrColors.text,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      );

  static TextStyle tab({bool selected = false}) => TextStyle(
        color: selected ? CmrColors.green : CmrColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      );

  static TextStyle action({bool danger = false}) => TextStyle(
        color: danger ? CmrColors.red : CmrColors.green,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      );
}

// ==================== ДЕКОРАТОРЫ (общие) ====================

class CmrDecor {
  static BoxDecoration panel({double radius = 30}) => BoxDecoration(
        color: CmrColors.panel,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.018),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration softCard({double radius = 22}) => BoxDecoration(
        color: CmrColors.soft,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration greenCard({double radius = 22}) => BoxDecoration(
        color: CmrColors.greenSoft,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: CmrColors.greenBorder),
      );
}

// ==================== API КЛИЕНТ (общий) ====================

class CmrApiClient {
  static const String baseUrl = 'https://sportotekaapp.ru/api';
  
  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> postForm(String endpoint, Map<String, String> body) async {
    final response = await _client
        .post(Uri.parse('$baseUrl/$endpoint'), body: body)
        .timeout(const Duration(seconds: 16));
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> postJson(String endpoint, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/$endpoint'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 16));
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> get(String endpoint, {Map<String, dynamic>? query}) async {
    final uri = Uri.parse('$baseUrl/$endpoint').replace(queryParameters: query?.map((k, v) => MapEntry(k, v.toString())));
    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    return _parseResponse(response);
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    final data = _tryDecode(response.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'success': false, 'message': 'Некорректный ответ сервера'};
  }

  dynamic _tryDecode(String body) {
    try {
      final start = body.indexOf('{');
      final arrayStart = body.indexOf('[');
      final cut = start >= 0 && (arrayStart < 0 || start < arrayStart) 
          ? body.substring(start) 
          : arrayStart >= 0 ? body.substring(arrayStart) : body;
      return jsonDecode(cut);
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}

// ==================== УТИЛИТЫ ДЛЯ ПАРСИНГА (общие) ====================

class CmrDataParser {
  static Map<String, dynamic> asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> asList(dynamic v) {
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  static String string(dynamic v, {String fallback = ''}) {
    final text = (v ?? '').toString().trim();
    return text == 'null' || text.isEmpty ? fallback : text;
  }

  static int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(string(value)) ?? 0;
  }

  static bool boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = string(value).toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  static String firstNotEmpty(List<dynamic> values, {String fallback = ''}) {
    for (final v in values) {
      final text = string(v);
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static String normalizeImage(String raw) {
    final url = raw.trim();
    if (url.isEmpty || url == 'null') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('www.sportotekaapp.ru/')) return 'https://$url';
    if (url.startsWith('/')) return 'https://sportotekaapp.ru$url';
    if (url.startsWith('uploads/')) return 'https://sportotekaapp.ru/$url';
    return 'https://sportotekaapp.ru/uploads/$url';
  }

  static String shortDate(String raw) {
    if (raw.trim().isEmpty) return '';
    final normalized = raw.trim().replaceFirst(' ', 'T');
    final dt = DateTime.tryParse(normalized);
    if (dt == null) return raw.length > 10 ? raw.substring(0, 10) : raw;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final time = dt.hour == 0 && dt.minute == 0 ? '' : ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (day == today) return 'сегодня$time';
    if (day == today.add(const Duration(days: 1))) return 'завтра$time';
    if (day == today.subtract(const Duration(days: 1))) return 'вчера$time';

    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}$time';
  }

  static String attendanceStatus(dynamic raw) {
    switch (string(raw)) {
      case 'present': return 'был';
      case 'absent': return 'нет';
      case 'late': return 'опоздал';
      case 'injured': return 'травма';
      case 'individual': return 'индив.';
      case 'dayoff': return 'отдых';
      default: return string(raw, fallback: 'статус');
    }
  }

  static String eventType(dynamic raw) {
    switch (string(raw)) {
      case 'training': return 'Тренировка';
      case 'league': return 'Официальная игра';
      case 'friendly': return 'Товарищеская игра';
      case 'theory': return 'Теория';
      case 'gym': return 'Зал';
      case 'day_off': return 'Восстановление';
      default: return string(raw, fallback: 'Событие');
    }
  }
}

// ==================== ПЕРЕИСПОЛЬЗУЕМЫЕ ВИДЖЕТЫ ====================

class CmrAvatar extends StatelessWidget {
  final String photo;
  final String name;
  final double size;

  const CmrAvatar({
    super.key,
    required this.photo,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((e) => e.isEmpty ? '' : e[0].toUpperCase()).join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CmrColors.soft,
        borderRadius: BorderRadius.circular(size * .32),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isEmpty
          ? Center(child: Text(initials, style: CmrTextStyle.title(size * .32)))
          : Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: Text(initials, style: CmrTextStyle.title(size * .32))),
            ),
    );
  }
}

class CmrRoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const CmrRoundIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color == CmrColors.green ? CmrColors.greenSoft : CmrColors.soft,
        border: Border.all(color: color == CmrColors.green ? CmrColors.greenBorder : Colors.transparent),
        borderRadius: BorderRadius.circular(size * .34),
      ),
      child: Icon(icon, size: size * .52, color: color),
    );
  }
}

class CmrPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const CmrPill({
    super.key,
    required this.text,
    required this.icon,
    this.color = CmrColors.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: CmrColors.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: CmrTextStyle.pill()),
          ),
        ],
      ),
    );
  }
}

class CmrPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color color;

  const CmrPrimaryButton({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.color = CmrColors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CmrSecondaryButton extends StatelessWidget {
  final IconData? icon;
  final String title;
  final VoidCallback? onTap;

  const CmrSecondaryButton({
    super.key,
    this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: CmrColors.soft,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: CmrColors.text),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CmrTextStyle.tab(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CmrInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const CmrInput({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.suffix,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: CmrTextStyle.title(13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: CmrTextStyle.muted(12.5),
        prefixIcon: Icon(icon, color: CmrColors.muted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: CmrColors.soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
      ),
    );
  }
}

class CmrBottomPanel extends StatelessWidget {
  final Widget child;
  final double maxHeightFactor;

  const CmrBottomPanel({
    super.key,
    required this.child,
    this.maxHeightFactor = .86,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: h * maxHeightFactor),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: CmrDecor.panel(),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class CmrSheetHandle extends StatelessWidget {
  const CmrSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFD0D5DD),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class CmrSheetTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const CmrSheetTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CmrRoundIcon(icon: icon, color: CmrColors.green, size: 50),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CmrTextStyle.title(20)),
              const SizedBox(height: 4),
              Text(subtitle, style: CmrTextStyle.muted(12.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class CmrNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const CmrNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: CmrDecor.softCard(radius: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CmrRoundIcon(icon: icon, color: CmrColors.green, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CmrTextStyle.title(14)),
                const SizedBox(height: 4),
                Text(text, style: CmrTextStyle.muted(13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CmrEmptyState extends StatelessWidget {
  final String title;
  final String text;
  final String buttonText;
  final VoidCallback onTap;

  const CmrEmptyState({
    super.key,
    required this.title,
    required this.text,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: CmrDecor.softCard(radius: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CmrRoundIcon(icon: Icons.info_outline_rounded, color: CmrColors.muted, size: 58),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: CmrTextStyle.title(16)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: CmrTextStyle.muted(12.5)),
            const SizedBox(height: 14),
            SizedBox(width: 190, child: CmrPrimaryButton(icon: Icons.add_rounded, title: buttonText, onTap: onTap)),
          ],
        ),
      ),
    );
  }
}

class CmrErrorState extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const CmrErrorState({
    super.key,
    required this.text,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: CmrDecor.panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: CmrColors.red, size: 42),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: CmrTextStyle.muted(13)),
            const SizedBox(height: 14),
            SizedBox(width: 160, child: CmrPrimaryButton(icon: Icons.refresh_rounded, title: 'Повторить', onTap: onRetry)),
          ],
        ),
      ),
    );
  }
}

class CmrStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const CmrStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: CmrDecor.softCard(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: CmrColors.green, size: 17),
          const SizedBox(height: 6),
          Text(value, style: CmrTextStyle.title(15)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: CmrTextStyle.muted(12, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class CmrInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  const CmrInfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(14),
      decoration: CmrDecor.softCard(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CmrRoundIcon(icon: icon, color: CmrColors.green, size: 32),
          const SizedBox(height: 7),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: CmrTextStyle.muted(12, weight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: CmrTextStyle.value(14),
          ),
        ],
      ),
    );
  }
}

class CmrContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const CmrContactCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CmrDecor.softCard(radius: 24),
      child: Row(
        children: [
          CmrRoundIcon(icon: icon, color: CmrColors.green, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CmrTextStyle.muted(12, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CmrTextStyle.value(15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CmrProfileBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const CmrProfileBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: CmrDecor.softCard(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CmrRoundIcon(icon: icon, color: CmrColors.text, size: 36),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: CmrTextStyle.section())),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: CmrTextStyle.muted(14)),
        ],
      ),
    );
  }
}

class CmrTabButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const CmrTabButton({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? CmrColors.greenSoft : CmrColors.soft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? CmrColors.greenBorder : Colors.transparent),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? CmrColors.green : CmrColors.text),
              const SizedBox(width: 7),
              Text(title, style: CmrTextStyle.tab(selected: selected)),
            ],
          ),
        ),
      ),
    );
  }
}