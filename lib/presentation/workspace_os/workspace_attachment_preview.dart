import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/plans/pdf_preview_screen.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:url_launcher/url_launcher.dart';

String _absoluteUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return 'https://sportotekaapp.ru/${value.replaceFirst(RegExp(r'^/+'), '')}';
}

String _extension(String title, String url) {
  String fromValue(String value) {
    final clean = value.split('?').first.split('#').first.trim();
    final slash = clean.lastIndexOf('/');
    final fileName = slash >= 0 ? clean.substring(slash + 1) : clean;
    final match = RegExp(r'\.([A-Za-z0-9]{2,8})$').firstMatch(fileName);
    return (match?.group(1) ?? '').toLowerCase();
  }

  final fromTitle = fromValue(title);
  if (fromTitle.isNotEmpty) return fromTitle;
  return fromValue(url);
}

Future<String> loadWorkspaceEditableAttachmentBody({
  required String title,
  required String fileUrl,
  String mimeType = '',
}) async {
  final url = _absoluteUrl(fileUrl);
  if (url.isEmpty) throw Exception('У документа нет ссылки');

  final extension = _extension(title, url);
  final mime = mimeType.trim().toLowerCase();
  final isDocx = extension == 'docx' ||
      mime.contains('wordprocessingml.document');
  final isText = (mime.startsWith('text/') && extension != 'rtf') ||
      const <String>{'txt', 'md', 'csv', 'tsv', 'json', 'xml', 'log', 'yaml', 'yml'}
          .contains(extension);

  if (!isText && !isDocx) {
    if (extension == 'pdf' || mime.contains('application/pdf') ||
        const <String>{'doc', 'xls', 'xlsx', 'ppt', 'pptx', 'rtf', 'odt', 'ods', 'odp'}
            .contains(extension)) {
      final endpoint = Uri.parse(
        'https://sportotekaapp.ru/api/workspace/preview_office.php',
      ).replace(queryParameters: <String, String>{'src': url, 'as': 'text'});
      final response = await http
          .get(endpoint, headers: const <String, String>{'Accept': 'text/plain'})
          .timeout(const Duration(minutes: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Не удалось извлечь текст документа (${response.statusCode})');
      }
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (body.trim().isEmpty) {
        throw UnsupportedError('Документ не содержит текстового слоя для редактирования');
      }
      return body;
    }
    throw UnsupportedError('Этот формат нельзя редактировать как текстовый документ');
  }

  final response = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 2));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Не удалось загрузить документ (${response.statusCode})');
  }

  if (isText) {
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }
  if (isDocx) {
    final document = _parseDocx(response.bodyBytes);
    return _docxDocumentToWorkspaceBody(document);
  }

  throw UnsupportedError('Этот формат пока нельзя редактировать как документ Sportoteka OS');
}

String _docxDocumentToWorkspaceBody(_DocxDocument document) {
  final chunks = <String>[];

  String richRun(_DocxTextRun run) {
    var text = run.text.replaceAll('\r', '');
    if (text.isEmpty) return '';
    if (run.bold) text = '**$text**';
    if (run.italic) text = '_${text}_';
    if (run.underline) text = '__${text}__';
    if (run.strike) text = '~~$text~~';
    if (run.fontSize != null) {
      final size = run.fontSize!.round().clamp(8, 48);
      text = '<fs:$size>$text</fs>';
    }
    return text;
  }

  String alignmentPrefix(TextAlign alignment) {
    switch (alignment) {
      case TextAlign.center:
        return '<align:center>';
      case TextAlign.right:
      case TextAlign.end:
        return '<align:right>';
      case TextAlign.justify:
        return '<align:justify>';
      default:
        return '';
    }
  }

  for (final block in document.blocks) {
    if (block is _DocxParagraphBlock) {
      var text = block.runs.map(richRun).join();
      if (block.bullet && text.trim().isNotEmpty) text = '• $text';
      final style = block.styleName.toLowerCase();
      if (style.contains('title') || style.contains('заголовок 1') || style.contains('heading1')) {
        text = '# $text';
      } else if (style.contains('heading2') || style.contains('заголовок 2')) {
        text = '## $text';
      } else if (style.contains('heading3') || style.contains('заголовок 3')) {
        text = '### $text';
      }
      final prefix = alignmentPrefix(block.alignment);
      if (prefix.isNotEmpty && text.isNotEmpty) text = '$prefix$text';
      if (text.trim().isNotEmpty) chunks.add(text);
      if (block.images.isNotEmpty) {
        chunks.add('Изображение сохранено в исходном DOCX. Оригинал доступен в карточке документа выше.');
      }
      continue;
    }

    if (block is _DocxTableBlock && block.rows.isNotEmpty) {
      var columns = 1;
      for (final row in block.rows) {
        if (row.length > columns) columns = row.length;
      }
      final normalized = block.rows.map((row) => List<String>.generate(
        columns,
        (index) => index < row.length
            ? row[index].replaceAll('|', '¦').replaceAll('\n', ' ').trim()
            : '',
      )).toList();
      final out = <String>[];
      out.add('| ${normalized.first.join(' | ')} |');
      out.add('| ${List<String>.filled(columns, '---').join(' | ')} |');
      for (final row in normalized.skip(1)) {
        out.add('| ${row.join(' | ')} |');
      }
      chunks.add(out.join('\n'));
    }
  }

  return chunks.join('\n\n').trim();
}

Future<void> openWorkspaceAttachmentPreview(
  BuildContext context, {
  required String title,
  required String fileUrl,
  String mimeType = '',
}) async {
  final url = _absoluteUrl(fileUrl);
  if (url.isEmpty) return;

  final extension = _extension(title, url);
  final mime = mimeType.trim().toLowerCase();
  final isPdf = extension == 'pdf' || mime.contains('application/pdf');

  if (isPdf) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _WorkspacePdfAttachmentPreviewScreen(
          title: title,
          url: url,
        ),
      ),
    );
    return;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => _WorkspaceAttachmentPreviewScreen(
        title: title,
        url: url,
        mimeType: mimeType,
        extension: extension,
      ),
    ),
  );
}


class WorkspaceAttachmentInlinePreview extends StatelessWidget {
  const WorkspaceAttachmentInlinePreview({
    super.key,
    required this.title,
    required this.fileUrl,
    this.mimeType = '',
  });

  final String title;
  final String fileUrl;
  final String mimeType;

  @override
  Widget build(BuildContext context) {
    final url = _absoluteUrl(fileUrl);
    final extension = _extension(title, url);
    final mime = mimeType.trim().toLowerCase();
    final isPdf = extension == 'pdf' || mime.contains('application/pdf');

    if (isPdf) {
      return WorkspacePdfInlinePreview(
        title: title,
        url: url,
      );
    }

    return _WorkspaceAttachmentPreviewScreen(
      title: title,
      url: url,
      mimeType: mimeType,
      extension: extension,
      embedded: true,
    );
  }
}

class WorkspacePdfInlinePreview extends StatelessWidget {
  const WorkspacePdfInlinePreview({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  static const _viewerBackground = Color(0xFFF4F6F5);

  Future<Uint8List> _loadPdf() async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(minutes: 2));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Не удалось загрузить PDF (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    final fileTitle = title.trim().isEmpty ? 'Документ.pdf' : title.trim();
    return ColoredBox(
      color: _viewerBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // PdfPreviewScreen already renders the complete PDF. Its legacy
          // bottom toolbar is clipped so the preview fits SPORTOTEKA OS.
          const legacyToolbarHeight = 44.0;
          final previewHeight = constraints.maxHeight + legacyToolbarHeight;

          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: constraints.maxWidth,
              maxWidth: constraints.maxWidth,
              minHeight: previewHeight,
              maxHeight: previewHeight,
              child: SizedBox(
                width: constraints.maxWidth,
                height: previewHeight,
                child: PdfPreviewScreen(
                  fileName: fileTitle,
                  buildPdf: (_) => _loadPdf(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class WorkspacePdfBytesInlinePreview extends StatelessWidget {
  const WorkspacePdfBytesInlinePreview({
    super.key,
    required this.title,
    required this.bytes,
  });

  final String title;
  final Uint8List bytes;

  static const _viewerBackground = Color(0xFFF4F6F5);

  @override
  Widget build(BuildContext context) {
    final sourceTitle = title.trim().isEmpty ? 'Документ' : title.trim();
    return ColoredBox(
      color: _viewerBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const legacyToolbarHeight = 44.0;
          final previewHeight = constraints.maxHeight + legacyToolbarHeight;
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: constraints.maxWidth,
              maxWidth: constraints.maxWidth,
              minHeight: previewHeight,
              maxHeight: previewHeight,
              child: SizedBox(
                width: constraints.maxWidth,
                height: previewHeight,
                child: PdfPreviewScreen(
                  fileName: sourceTitle,
                  buildPdf: (_) async => bytes,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WorkspacePdfAttachmentPreviewScreen extends StatelessWidget {
  const _WorkspacePdfAttachmentPreviewScreen({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);

  @override
  Widget build(BuildContext context) {
    final fileTitle = title.trim().isEmpty ? 'Документ.pdf' : title.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                _PreviewHeaderButton(
                  tooltip: 'Назад',
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 8),
                const SportotekaWorkspaceIcon(
                  kind: SportotekaWorkspaceIconKind.document,
                  size: 20,
                  color: _green,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    fileTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.itemTitle(color: _text),
                  ),
                ),
                const SizedBox(width: 8),
                _PreviewHeaderButton(
                  tooltip: 'Закрыть документ',
                  icon: Icons.close_rounded,
                  iconColor: _muted,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: WorkspacePdfInlinePreview(
              title: fileTitle,
              url: url,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHeaderButton extends StatelessWidget {
  const _PreviewHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.iconColor = const Color(0xFF34413A),
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 20,
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          child: SizedBox.square(
            dimension: 36,
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceAttachmentPreviewScreen extends StatefulWidget {
  const _WorkspaceAttachmentPreviewScreen({
    required this.title,
    required this.url,
    required this.mimeType,
    required this.extension,
    this.embedded = false,
  });

  final String title;
  final String url;
  final String mimeType;
  final String extension;
  final bool embedded;

  @override
  State<_WorkspaceAttachmentPreviewScreen> createState() =>
      _WorkspaceAttachmentPreviewScreenState();
}

class _WorkspaceAttachmentPreviewScreenState
    extends State<_WorkspaceAttachmentPreviewScreen> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);

  bool _loadingText = false;
  bool _loadingOffice = false;
  String? _textBody;
  _DocxDocument? _docxDocument;
  Uint8List? _officePdfBytes;
  String? _error;

  bool get _isImage {
    final mime = widget.mimeType.toLowerCase();
    return mime.startsWith('image/') ||
        const <String>{'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}
            .contains(widget.extension);
  }

  bool get _isDocx {
    final mime = widget.mimeType.toLowerCase();
    return widget.extension == 'docx' ||
        mime.contains('wordprocessingml.document');
  }

  bool get _isOffice => _isDocx ||
      const <String>{'doc', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp', 'rtf'}
          .contains(widget.extension);

  bool get _isText {
    final mime = widget.mimeType.toLowerCase();
    return !_isOffice && (mime.startsWith('text/') ||
        const <String>{'txt', 'md', 'csv', 'tsv', 'json', 'xml', 'log', 'yaml', 'yml'}
            .contains(widget.extension));
  }

  @override
  void initState() {
    super.initState();
    if (_isText) {
      _loadText();
    } else if (_isOffice) {
      _loadOffice();
    }
  }

  Future<void> _loadText() async {
    setState(() {
      _loadingText = true;
      _error = null;
    });
    try {
      final response = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(minutes: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      if (!mounted) return;
      setState(() {
        _textBody = utf8.decode(response.bodyBytes, allowMalformed: true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить документ: $e');
    } finally {
      if (mounted) setState(() => _loadingText = false);
    }
  }

  Future<void> _loadOffice() async {
    setState(() {
      _loadingOffice = true;
      _officePdfBytes = null;
      _docxDocument = null;
      _error = null;
    });

    Object? conversionError;
    try {
      // DOCX is a page-layout format. Reconstructing it with Flutter widgets
      // changes cell widths, floating drawings, SmartArt, anchors and page
      // geometry. For a faithful preview SPORTOTEKA asks its own server to
      // render the original Office document to PDF, then shows that PDF inside
      // the app. This keeps schemes/images and the original page layout.
      final previewUri = Uri.parse(
        'https://sportotekaapp.ru/api/workspace/preview_office.php',
      ).replace(queryParameters: <String, String>{'src': widget.url});
      final previewResponse = await http
          .get(previewUri, headers: const <String, String>{'Accept': 'application/pdf'})
          .timeout(const Duration(seconds: 90));
      final body = previewResponse.bodyBytes;
      final isPdf = body.length >= 5 &&
          body[0] == 0x25 &&
          body[1] == 0x50 &&
          body[2] == 0x44 &&
          body[3] == 0x46 &&
          body[4] == 0x2D;
      if (previewResponse.statusCode >= 200 &&
          previewResponse.statusCode < 300 &&
          isPdf) {
        if (!mounted) return;
        setState(() {
          _officePdfBytes = Uint8List.fromList(body);
          _loadingOffice = false;
        });
        return;
      }
      conversionError = Exception(
        'preview_office HTTP ${previewResponse.statusCode}',
      );
    } catch (e) {
      conversionError = e;
    }

    if (!_isDocx) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось подготовить просмотр внутри приложения. '
            'Проверьте серверный конвертер документов: $conversionError';
        _loadingOffice = false;
      });
      return;
    }

    // Safe fallback for the period before preview_office.php is installed on
    // the server. It can show text/basic tables, but it is intentionally only
    // a fallback because it cannot reproduce Word layout pixel-for-pixel.
    try {
      final response = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(minutes: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      await Future<void>.delayed(Duration.zero);
      final document = _parseDocx(response.bodyBytes);
      if (!mounted) return;
      setState(() => _docxDocument = document);
    } catch (fallbackError) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось подготовить точный просмотр DOCX. '
            'Конвертация: ${conversionError ?? 'недоступна'}. '
            'Резервный просмотр: $fallbackError';
      });
    } finally {
      if (mounted) setState(() => _loadingOffice = false);
    }
  }

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.trim().isEmpty ? 'Документ' : widget.title.trim();
    if (widget.embedded) {
      return ColoredBox(
        color: Colors.white,
        child: _buildBody(),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.only(left: 14, right: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                _PreviewHeaderButton(
                  tooltip: 'Назад',
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 5),
                const SportotekaWorkspaceIcon(
                  kind: SportotekaWorkspaceIconKind.document,
                  size: 21,
                  color: _green,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.itemTitle(color: _text),
                  ),
                ),
                _PreviewHeaderButton(
                  tooltip: 'Закрыть документ',
                  icon: Icons.close_rounded,
                  iconColor: _muted,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isImage) {
      return Container(
        color: const Color(0xFFF7F8F7),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(18),
        child: InteractiveViewer(
          minScale: .5,
          maxScale: 5,
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _message(
              'Не удалось показать изображение.',
              showOriginal: true,
            ),
          ),
        ),
      );
    }

    if (_isText) {
      if (_loadingText) {
        return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: _green),
        );
      }
      if (_error != null) return _message(_error!, showOriginal: true);
      return SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              _textBody ?? '',
              style: AppTypography.secondary(color: _text).copyWith(height: 1.45),
            ),
          ),
        ),
      );
    }

    if (_isOffice) {
      if (_loadingOffice) {
        return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: _green),
        );
      }
      if (_error != null) return _message(_error!, showOriginal: true);
      final pdfBytes = _officePdfBytes;
      if (pdfBytes != null && pdfBytes.isNotEmpty) {
        return WorkspacePdfBytesInlinePreview(
          title: widget.title,
          bytes: pdfBytes,
        );
      }
      final document = _docxDocument;
      if (document == null) {
        return _message('Нет данных для просмотра документа.', showOriginal: true);
      }
      return _DocxPreview(document: document);
    }

    return _message(
      'Для этого формата пока доступна карточка файла внутри SPORTOTEKA.',
      showOriginal: true,
    );
  }

  Widget _message(String message, {required bool showOriginal}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SportotekaWorkspaceIcon(
              kind: SportotekaWorkspaceIconKind.document,
              size: 52,
              color: Color(0xFF66736B),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.secondary(color: _muted),
            ),
            if (showOriginal) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _openOriginal,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: Text(
                  'Открыть оригинал',
                  style: AppTypography.action(),
                ),
                style: TextButton.styleFrom(foregroundColor: _green),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

abstract class _DocxBlock {
  const _DocxBlock();
}

class _DocxDocument {
  const _DocxDocument(this.blocks);

  final List<_DocxBlock> blocks;
}

class _DocxTextRun {
  const _DocxTextRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSize,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final double? fontSize;
}

class _DocxParagraphBlock extends _DocxBlock {
  const _DocxParagraphBlock({
    required this.runs,
    required this.alignment,
    required this.styleName,
    this.images = const <Uint8List>[],
    this.bullet = false,
  });

  final List<_DocxTextRun> runs;
  final TextAlign alignment;
  final String styleName;
  final List<Uint8List> images;
  final bool bullet;
}

class _DocxTableBlock extends _DocxBlock {
  const _DocxTableBlock(this.rows);

  final List<List<String>> rows;
}

class _DocxPreview extends StatelessWidget {
  const _DocxPreview({required this.document});

  final _DocxDocument document;

  static const _page = Color(0xFFFFFFFF);
  static const _surface = Color(0xFFF1F3F2);
  static const _text = Color(0xFF172019);
  static const _line = Color(0xFFD8DEDA);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _surface,
      child: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 860),
              padding: const EdgeInsets.fromLTRB(52, 46, 52, 62),
              decoration: BoxDecoration(
                color: _page,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE3E7E4), width: .8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: document.blocks.isEmpty
                  ? Text(
                      'Документ пуст.',
                      style: AppTypography.secondary(color: const Color(0xFF758079)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final block in document.blocks) _buildBlock(block),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlock(_DocxBlock block) {
    if (block is _DocxTableBlock) return _buildTable(block);
    if (block is _DocxParagraphBlock) return _buildParagraph(block);
    return const SizedBox.shrink();
  }

  Widget _buildParagraph(_DocxParagraphBlock block) {
    final styleName = block.styleName.toLowerCase();
    final isTitle = styleName.contains('title') || styleName.contains('заголовок');
    final headingMatch = RegExp(r'heading\s*([1-6])').firstMatch(styleName);
    final headingLevel = headingMatch == null
        ? (styleName.contains('heading') ? 2 : 0)
        : int.tryParse(headingMatch.group(1) ?? '') ?? 0;

    double baseSize = 15;
    FontWeight baseWeight = FontWeight.w400;
    double top = 2;
    double bottom = 8;
    if (isTitle) {
      baseSize = 24;
      baseWeight = FontWeight.w700;
      top = 4;
      bottom = 18;
    } else if (headingLevel > 0) {
      baseSize = headingLevel == 1
          ? 21
          : headingLevel == 2
              ? 19
              : 17;
      baseWeight = FontWeight.w700;
      top = 12;
      bottom = 8;
    }

    final spans = <InlineSpan>[];
    if (block.bullet) {
      spans.add(TextSpan(
        text: '• ',
        style: TextStyle(
          color: _text,
          fontSize: baseSize,
          height: 1.42,
          fontWeight: baseWeight,
        ),
      ));
    }
    for (final run in block.runs) {
      spans.add(TextSpan(
        text: run.text,
        style: TextStyle(
          color: _text,
          fontSize: run.fontSize ?? baseSize,
          height: 1.42,
          fontWeight: run.bold ? FontWeight.w700 : baseWeight,
          fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
          decoration: run.underline && run.strike
              ? TextDecoration.combine(const <TextDecoration>[
                  TextDecoration.underline,
                  TextDecoration.lineThrough,
                ])
              : run.underline
                  ? TextDecoration.underline
                  : run.strike
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
        ),
      ));
    }

    final hasText = block.runs.any((run) => run.text.trim().isNotEmpty);
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasText || block.bullet)
            RichText(
              textAlign: block.alignment,
              text: TextSpan(children: spans),
            )
          else if (block.images.isEmpty)
            const SizedBox(height: 8),
          for (final image in block.images)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 520),
                  child: Image.memory(
                    image,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTable(_DocxTableBlock table) {
    final maxColumns = table.rows.fold<int>(
      0,
      (value, row) => row.length > value ? row.length : value,
    );
    if (maxColumns == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < maxColumns; column++)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              right: column == maxColumns - 1
                                  ? BorderSide.none
                                  : const BorderSide(color: _line),
                              bottom: rowIndex == table.rows.length - 1
                                  ? BorderSide.none
                                  : const BorderSide(color: _line),
                            ),
                          ),
                          child: Text(
                            column < table.rows[rowIndex].length
                                ? table.rows[rowIndex][column]
                                : '',
                            style: const TextStyle(
                              color: _text,
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

_DocxDocument _parseDocx(Uint8List bytes) {
  final archive = _OpenXmlArchive(bytes);
  final documentXmlBytes = archive.read('word/document.xml');
  if (documentXmlBytes == null || documentXmlBytes.isEmpty) {
    throw FormatException('В файле не найден word/document.xml');
  }

  final documentXml = utf8.decode(documentXmlBytes, allowMalformed: true);
  final relationshipMap = <String, String>{};
  final relBytes = archive.read('word/_rels/document.xml.rels');
  if (relBytes != null && relBytes.isNotEmpty) {
    final relXml = utf8.decode(relBytes, allowMalformed: true);
    for (final match in RegExp(r'<Relationship\b[^>]*/?>').allMatches(relXml)) {
      final tag = match.group(0) ?? '';
      final id = _xmlAttribute(tag, 'Id');
      final target = _xmlAttribute(tag, 'Target');
      if (id.isNotEmpty && target.isNotEmpty && !target.contains('://')) {
        relationshipMap[id] = target;
      }
    }
  }

  final bodyMatch = RegExp(r'<w:body\b[^>]*>([\s\S]*?)</w:body>').firstMatch(documentXml);
  final body = bodyMatch?.group(1) ?? documentXml;
  final blockPattern = RegExp(
    r'<w:p\b[\s\S]*?</w:p>|<w:tbl\b[\s\S]*?</w:tbl>',
    multiLine: true,
  );

  final blocks = <_DocxBlock>[];
  for (final match in blockPattern.allMatches(body)) {
    final xml = match.group(0) ?? '';
    if (xml.startsWith('<w:tbl')) {
      final table = _parseDocxTable(xml);
      if (table.rows.isNotEmpty) blocks.add(table);
    } else {
      blocks.add(_parseDocxParagraph(xml, archive, relationshipMap));
    }
  }

  if (blocks.isEmpty) {
    final fallback = _docxPlainText(body);
    if (fallback.trim().isNotEmpty) {
      blocks.add(_DocxParagraphBlock(
        runs: <_DocxTextRun>[_DocxTextRun(text: fallback)],
        alignment: TextAlign.left,
        styleName: '',
      ));
    }
  }

  return _DocxDocument(blocks);
}

_DocxParagraphBlock _parseDocxParagraph(
  String xml,
  _OpenXmlArchive archive,
  Map<String, String> relationships,
) {
  final styleMatch = RegExp(r'''<w:pStyle\b[^>]*w:val=["']([^"']+)["']''').firstMatch(xml);
  final styleName = styleMatch?.group(1) ?? '';
  final alignMatch = RegExp(r'''<w:jc\b[^>]*w:val=["']([^"']+)["']''').firstMatch(xml);
  final alignValue = (alignMatch?.group(1) ?? '').toLowerCase();
  final TextAlign alignment;
  if (alignValue == 'center') {
    alignment = TextAlign.center;
  } else if (alignValue == 'right' || alignValue == 'end') {
    alignment = TextAlign.right;
  } else if (alignValue == 'both' || alignValue == 'distribute') {
    alignment = TextAlign.justify;
  } else {
    alignment = TextAlign.left;
  }

  final runs = <_DocxTextRun>[];
  for (final runMatch in RegExp(r'<w:r\b[\s\S]*?</w:r>').allMatches(xml)) {
    final runXml = runMatch.group(0) ?? '';
    final content = StringBuffer();
    final tokenPattern = RegExp(
      r'<w:t\b[^>]*>[\s\S]*?</w:t>|<w:tab\b[^>]*/>|<w:br\b[^>]*/>|<w:cr\b[^>]*/>',
      multiLine: true,
    );
    for (final token in tokenPattern.allMatches(runXml)) {
      final raw = token.group(0) ?? '';
      if (raw.startsWith('<w:t')) {
        final start = raw.indexOf('>');
        final end = raw.lastIndexOf('</w:t>');
        if (start >= 0 && end > start) {
          content.write(_decodeXml(raw.substring(start + 1, end)));
        }
      } else if (raw.startsWith('<w:tab')) {
        content.write('\t');
      } else {
        content.write('\n');
      }
    }

    if (content.length == 0) continue;
    final sizeMatch = RegExp(r'''<w:sz\b[^>]*w:val=["']([0-9.]+)["']''').firstMatch(runXml);
    final halfPoints = double.tryParse(sizeMatch?.group(1) ?? '');
    runs.add(_DocxTextRun(
      text: content.toString(),
      bold: RegExp(r'<w:b(?:\s|/|>)').hasMatch(runXml) &&
          !RegExp(r'''<w:b\b[^>]*w:val=["'](?:0|false|off)["']''').hasMatch(runXml),
      italic: RegExp(r'<w:i(?:\s|/|>)').hasMatch(runXml) &&
          !RegExp(r'''<w:i\b[^>]*w:val=["'](?:0|false|off)["']''').hasMatch(runXml),
      underline: RegExp(r'<w:u\b[^>]*>').hasMatch(runXml) &&
          !RegExp(r'''<w:u\b[^>]*w:val=["'](?:none|0|false|off)["']''').hasMatch(runXml),
      strike: RegExp(r'<w:strike(?:\s|/|>)').hasMatch(runXml),
      fontSize: halfPoints == null ? null : (halfPoints / 2).clamp(8, 40).toDouble(),
    ));
  }

  if (runs.isEmpty) {
    final plain = _docxPlainText(xml);
    if (plain.isNotEmpty) runs.add(_DocxTextRun(text: plain));
  }

  final images = <Uint8List>[];
  for (final imageMatch in RegExp(r'''<a:blip\b[^>]*r:embed=["']([^"']+)["']''').allMatches(xml)) {
    final relationshipId = imageMatch.group(1) ?? '';
    final target = relationships[relationshipId];
    if (target == null || target.isEmpty) continue;
    final path = _resolveWordTarget(target);
    final image = archive.read(path);
    if (image != null && image.isNotEmpty) images.add(image);
  }

  return _DocxParagraphBlock(
    runs: runs,
    alignment: alignment,
    styleName: styleName,
    images: images,
    bullet: xml.contains('<w:numPr>') || xml.contains('<w:numPr '),
  );
}

_DocxTableBlock _parseDocxTable(String xml) {
  final rows = <List<String>>[];
  for (final rowMatch in RegExp(r'<w:tr\b[\s\S]*?</w:tr>').allMatches(xml)) {
    final rowXml = rowMatch.group(0) ?? '';
    final cells = <String>[];
    for (final cellMatch in RegExp(r'<w:tc\b[\s\S]*?</w:tc>').allMatches(rowXml)) {
      final cellXml = cellMatch.group(0) ?? '';
      final paragraphTexts = <String>[];
      for (final pMatch in RegExp(r'<w:p\b[\s\S]*?</w:p>').allMatches(cellXml)) {
        final text = _docxPlainText(pMatch.group(0) ?? '').trim();
        if (text.isNotEmpty) paragraphTexts.add(text);
      }
      cells.add(paragraphTexts.join('\n'));
    }
    if (cells.isNotEmpty) rows.add(cells);
  }
  return _DocxTableBlock(rows);
}

String _docxPlainText(String xml) {
  final out = StringBuffer();
  final tokens = RegExp(
    r'<w:t\b[^>]*>[\s\S]*?</w:t>|<w:tab\b[^>]*/>|<w:br\b[^>]*/>|<w:cr\b[^>]*/>|</w:p>',
    multiLine: true,
  );
  for (final match in tokens.allMatches(xml)) {
    final raw = match.group(0) ?? '';
    if (raw.startsWith('<w:t')) {
      final start = raw.indexOf('>');
      final end = raw.lastIndexOf('</w:t>');
      if (start >= 0 && end > start) {
        out.write(_decodeXml(raw.substring(start + 1, end)));
      }
    } else if (raw.startsWith('<w:tab')) {
      out.write('\t');
    } else {
      out.write('\n');
    }
  }
  return out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

String _resolveWordTarget(String target) {
  var normalized = target.replaceAll('\\', '/');
  while (normalized.startsWith('../')) {
    normalized = normalized.substring(3);
  }
  while (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.startsWith('word/')) return normalized;
  return 'word/$normalized';
}

String _xmlAttribute(String tag, String name) {
  final match = RegExp('''$name=["']([^"']*)["']''').firstMatch(tag);
  return match == null ? '' : _decodeXml(match.group(1) ?? '');
}

String _decodeXml(String value) {
  var result = value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  result = result.replaceAllMapped(RegExp(r'&#x([0-9A-Fa-f]+);'), (match) {
    final code = int.tryParse(match.group(1) ?? '', radix: 16);
    return code == null ? match.group(0)! : String.fromCharCode(code);
  });
  result = result.replaceAllMapped(RegExp(r'&#([0-9]+);'), (match) {
    final code = int.tryParse(match.group(1) ?? '');
    return code == null ? match.group(0)! : String.fromCharCode(code);
  });
  return result;
}

class _OpenXmlArchive {
  _OpenXmlArchive(this.bytes) {
    _index();
  }

  final Uint8List bytes;
  final Map<String, _ZipEntry> _entries = <String, _ZipEntry>{};

  int _u16(int offset) {
    if (offset < 0 || offset + 1 >= bytes.length) {
      throw FormatException('Повреждён ZIP: выход за границы');
    }
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  int _u32(int offset) {
    if (offset < 0 || offset + 3 >= bytes.length) {
      throw FormatException('Повреждён ZIP: выход за границы');
    }
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  void _index() {
    if (bytes.length < 22) {
      throw FormatException('DOCX слишком короткий');
    }

    final minOffset = bytes.length > 65557 ? bytes.length - 65557 : 0;
    var eocd = -1;
    for (var i = bytes.length - 22; i >= minOffset; i--) {
      if (_u32(i) == 0x06054B50) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) {
      throw FormatException('Не найден каталог DOCX');
    }

    final totalEntries = _u16(eocd + 10);
    final centralOffset = _u32(eocd + 16);
    var cursor = centralOffset;
    for (var index = 0; index < totalEntries; index++) {
      if (cursor + 46 > bytes.length || _u32(cursor) != 0x02014B50) {
        throw FormatException('Повреждён центральный каталог DOCX');
      }
      final method = _u16(cursor + 10);
      final compressedSize = _u32(cursor + 20);
      final uncompressedSize = _u32(cursor + 24);
      final nameLength = _u16(cursor + 28);
      final extraLength = _u16(cursor + 30);
      final commentLength = _u16(cursor + 32);
      final localOffset = _u32(cursor + 42);
      final nameStart = cursor + 46;
      final nameEnd = nameStart + nameLength;
      if (nameEnd > bytes.length) {
        throw FormatException('Повреждено имя файла в DOCX');
      }
      final name = utf8.decode(bytes.sublist(nameStart, nameEnd), allowMalformed: true);
      _entries[name] = _ZipEntry(
        method: method,
        compressedSize: compressedSize,
        uncompressedSize: uncompressedSize,
        localOffset: localOffset,
      );
      cursor = nameEnd + extraLength + commentLength;
    }
  }

  Uint8List? read(String name) {
    final entry = _entries[name];
    if (entry == null) return null;
    final offset = entry.localOffset;
    if (offset + 30 > bytes.length || _u32(offset) != 0x04034B50) {
      throw FormatException('Повреждена запись DOCX');
    }
    final nameLength = _u16(offset + 26);
    final extraLength = _u16(offset + 28);
    final dataStart = offset + 30 + nameLength + extraLength;
    final dataEnd = dataStart + entry.compressedSize;
    if (dataStart < 0 || dataEnd > bytes.length || dataEnd < dataStart) {
      throw FormatException('Повреждены данные внутри DOCX');
    }
    final compressed = bytes.sublist(dataStart, dataEnd);
    if (entry.method == 0) return Uint8List.fromList(compressed);
    if (entry.method == 8) {
      final decoded = ZLibDecoder(raw: true).convert(compressed);
      if (entry.uncompressedSize > 0 && decoded.length != entry.uncompressedSize) {
        // Some generators write an approximate size. The decoded payload is
        // still valid, so do not reject it solely because of that metadata.
      }
      return Uint8List.fromList(decoded);
    }
    throw FormatException('Неизвестный метод сжатия DOCX: ${entry.method}');
  }
}

class _ZipEntry {
  const _ZipEntry({
    required this.method,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localOffset,
  });

  final int method;
  final int compressedSize;
  final int uncompressedSize;
  final int localOffset;
}
