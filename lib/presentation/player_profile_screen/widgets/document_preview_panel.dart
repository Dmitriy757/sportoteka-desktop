import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'player_profile_ui.dart';

class DocumentPreviewPanel extends StatefulWidget {
  final int playerId;
  final Map<String, dynamic> record;
  final VoidCallback onClose;
  final String? documentTitle;
  final String kindLabel;

  const DocumentPreviewPanel({
    super.key,
    required this.playerId,
    required this.record,
    required this.onClose,
    this.documentTitle,
    this.kindLabel = 'медицинский документ',
  });

  @override
  State<DocumentPreviewPanel> createState() => _DocumentPreviewPanelState();
}

class _DocumentPreviewPanelState extends State<DocumentPreviewPanel> {
  static const String _previewEndpoint =
      'https://sportotekaapp.ru/api/medical/preview_medical_file.php';

  final PdfViewerController _pdfController = PdfViewerController();
  final TransformationController _imageController = TransformationController();

  bool _loading = false;
  String? _error;
  String? _previewUrl;
  int _page = 1;
  int _pageCount = 0;

  String _s(dynamic value) => '${value ?? ''}'.trim();
  int _i(dynamic value) => value is num ? value.toInt() : int.tryParse(_s(value)) ?? 0;

  String get _fileUrl => _absoluteUrl(_s(widget.record['file_url'] ?? widget.record['file_path']));

  String get _fileName {
    final saved = _s(widget.record['file_name']);
    if (saved.isNotEmpty) return saved;
    final uri = Uri.tryParse(_fileUrl);
    return uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'Медицинский документ';
  }

  String get _displayTitle {
    final explicit = _s(widget.documentTitle);
    if (explicit.isNotEmpty) return explicit;
    final stored = _s(widget.record['document_title']);
    return stored.isNotEmpty ? stored : _fileName;
  }

  String get _extension {
    final fromRecord = _s(widget.record['file_ext']).toLowerCase().replaceAll('.', '');
    if (fromRecord.isNotEmpty) return fromRecord;
    final name = _fileName;
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  }

  bool get _isImage => const {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(_extension);
  bool get _isPdf => _extension == 'pdf';
  bool get _isWord => _extension == 'doc' || _extension == 'docx';

  @override
  void initState() {
    super.initState();
    if (_isPdf || _isImage) {
      _previewUrl = _fileUrl;
    } else if (_isWord) {
      _prepareWordPreview();
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  String _absoluteUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    return 'https://sportotekaapp.ru/$clean';
  }

  Future<void> _prepareWordPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(_previewEndpoint),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'record_id': _i(widget.record['id'] ?? widget.record['record_id']),
              'player_id': widget.playerId,
            }),
          )
          .timeout(const Duration(seconds: 45));

      final clean = response.body.substring(response.body.indexOf('{').clamp(0, response.body.length));
      final data = jsonDecode(clean);
      if (response.statusCode != 200 || data is! Map || data['success'] != true) {
        throw Exception(data is Map ? data['message'] ?? 'Не удалось подготовить документ' : 'HTTP ${response.statusCode}');
      }

      if (!mounted) return;
      setState(() => _previewUrl = _absoluteUrl(_s(data['preview_url'])));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(_fileUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть исходный файл')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          _header(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: PpColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PpColors.greenSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_typeIcon(), color: PpColors.greenDark, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PpText.title(14.5),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_fileName} · ${widget.kindLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PpText.body(10.2),
                ),
              ],
            ),
          ),
          if (_isPdf && _pageCount > 0) ...[
            Text('$_page/$_pageCount', style: PpText.body(10.2)),
            const SizedBox(width: 6),
          ],
          _squareAction(Icons.open_in_new_rounded, _openOriginal, 'Открыть отдельно'),
          const SizedBox(width: 6),
          _squareAction(Icons.close_rounded, widget.onClose, 'Закрыть'),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: PpColors.green));
    }
    if (_error != null) return _fallback(error: _error);
    if (_previewUrl == null || _previewUrl!.isEmpty) return _fallback();

    if (_isImage) {
      return Container(
        color: const Color(0xFFF5F6F5),
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            transformationController: _imageController,
            minScale: .7,
            maxScale: 6,
            child: Center(
              child: Image.network(
                _previewUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(color: PpColors.green)),
                errorBuilder: (_, __, ___) => _fallback(error: 'Не удалось загрузить изображение'),
              ),
            ),
          ),
        ),
      );
    }

    if (_isPdf || _isWord) {
      return SfPdfViewer.network(
        _previewUrl!,
        controller: _pdfController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        onDocumentLoaded: (details) {
          if (!mounted) return;
          setState(() => _pageCount = details.document.pages.count);
        },
        onPageChanged: (details) {
          if (!mounted) return;
          setState(() => _page = details.newPageNumber);
        },
        onDocumentLoadFailed: (details) {
          if (!mounted) return;
          setState(() => _error = details.description);
        },
      );
    }

    return _fallback();
  }

  Widget _fallback({String? error}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: PpColors.greenSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(_typeIcon(), color: PpColors.greenDark, size: 29),
            ),
            const SizedBox(height: 14),
            Text(_displayTitle, textAlign: TextAlign.center, style: PpText.title(14)),
            const SizedBox(height: 6),
            Text(
              error ?? 'Для этого формата встроенный просмотр пока недоступен.',
              textAlign: TextAlign.center,
              style: PpText.body(10.8),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _openOriginal,
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('Открыть файл'),
              style: FilledButton.styleFrom(
                backgroundColor: PpColors.greenDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon() {
    if (_isPdf) return Icons.picture_as_pdf_rounded;
    if (_isWord) return Icons.description_rounded;
    if (_isImage) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Widget _squareAction(IconData icon, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: PpColors.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18, color: PpColors.text)),
        ),
      ),
    );
  }
}
