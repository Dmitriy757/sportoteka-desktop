import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/presentation/club_workspace/widgets/ai_tactical_document_preview.dart';

class PlanTrainingGraphicsSection extends StatefulWidget {
  final int planId;
  final void Function(Map<String, dynamic> payload) onOpenEditor;
  final void Function(String pdfUrl)? onOpenPdf;

  const PlanTrainingGraphicsSection({
    super.key,
    required this.planId,
    required this.onOpenEditor,
    this.onOpenPdf,
  });

  @override
  State<PlanTrainingGraphicsSection> createState() =>
      _PlanTrainingGraphicsSectionState();
}

class _PlanTrainingGraphicsSectionState
    extends State<PlanTrainingGraphicsSection> {
  static const String base = 'https://sportotekaapp.ru/api/ai/v1';

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
        Uri.parse('$base/plans/${widget.planId}/diagrams'),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    if (_error.isNotEmpty) return Text('Не удалось загрузить схемы: $_error');
    if (_items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Тактические схемы',
          style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: AppTypography.screenTitleSize, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        for (final item in _items) ...[
          AiTacticalDocumentPreview(
            title: '${item['title'] ?? 'Тактическая схема'}',
            document: item['doc_json'] is Map
                ? Map<String, dynamic>.from(item['doc_json'] as Map)
                : const {},
            onOpenEditor: () {
              final route = item['route'];
              if (route is Map && route['payload'] is Map) {
                widget.onOpenEditor(
                  Map<String, dynamic>.from(route['payload'] as Map),
                );
              }
            },
            onOpenPdf: '${item['pdf_url'] ?? ''}'.isEmpty ||
                    widget.onOpenPdf == null
                ? null
                : () => widget.onOpenPdf!('${item['pdf_url']}'),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
