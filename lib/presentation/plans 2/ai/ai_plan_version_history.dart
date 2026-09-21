import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:http/http.dart' as http;

class AiPlanVersionHistory extends StatefulWidget {
  final int templateId;
  final int userId;
  final void Function(Map<String, dynamic> draftPayload) onRestore;

  const AiPlanVersionHistory({
    super.key,
    required this.templateId,
    required this.userId,
    required this.onRestore,
  });

  @override
  State<AiPlanVersionHistory> createState() =>
      _AiPlanVersionHistoryState();
}

class _AiPlanVersionHistoryState extends State<AiPlanVersionHistory> {
  static const base =
      'https://sportotekaapp.ru/api/ai/v1/plans/ai';

  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse(
          '$base/templates/${widget.templateId}/versions',
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final raw = data is Map && data['items'] is List
          ? data['items'] as List
          : const [];

      if (!mounted) return;
      setState(() {
        _items = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _restore(int versionNo) async {
    final response = await http.post(
      Uri.parse(
        '$base/templates/${widget.templateId}/versions/'
        '$versionNo/restore?user_id=${widget.userId}',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = Map<String, dynamic>.from(
      jsonDecode(response.body) as Map,
    );

    if (data['draft_payload'] is Map) {
      widget.onRestore(
        Map<String, dynamic>.from(
          data['draft_payload'] as Map,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Text(_error, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: Colors.red));
    }

    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        final changes = item['change_summary'] is List
            ? (item['change_summary'] as List)
                .map((e) => '$e')
                .toList()
            : const <String>[];

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3FBF7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'v${item['version_no']}',
                  style: const TextStyle(fontFamily: AppTypography.fontFamily, 
                    color: Color(0xFF067A46),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['command_text'] ?? 'Изменение плана'}',
                      style: const TextStyle(fontFamily: AppTypography.fontFamily, 
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (changes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        changes.first,
                        style: const TextStyle(fontFamily: AppTypography.fontFamily, 
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _restore(
                  int.tryParse('${item['version_no']}') ?? 0,
                ),
                child: const Text('Вернуть'),
              ),
            ],
          ),
        );
      },
    );
  }
}
