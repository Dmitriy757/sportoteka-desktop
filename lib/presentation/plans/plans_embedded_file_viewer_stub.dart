import 'package:flutter/material.dart';

class PlansEmbeddedFileViewer extends StatelessWidget {
  final String url;
  final String sourceUrl;
  final String title;

  const PlansEmbeddedFileViewer({
    super.key,
    required this.url,
    required this.sourceUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7F8),
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.article_rounded, color: Color(0xFF667085), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Встроенный просмотр документа',
                        style: TextStyle(
                          color: Color(0xFF101828),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'На этой платформе документ оставлен внутри окна программы. Для полноценного просмотра DOCX/XLSX/PPTX используется Web-iframe. Ссылку ниже можно скопировать или скачать файл.',
                  style: TextStyle(
                    color: Color(0xFF475467),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: SelectableText(
                    sourceUrl,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
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
