import 'dart:convert';
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
    final clean = value.split('?').first.split('#').first;
    final slash = clean.lastIndexOf('/');
    final dot = clean.lastIndexOf('.');
    if (dot <= slash || dot < 0 || dot == clean.length - 1) return '';
    return clean.substring(dot + 1).toLowerCase();
  }

  final fromTitle = fromValue(title);
  if (fromTitle.isNotEmpty) return fromTitle;
  return fromValue(url);
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
            child: ColoredBox(
              color: _viewerBackground,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // PdfPreviewScreen contains an old green toolbar at the
                  // bottom. We keep its PDF renderer, but render that widget
                  // slightly taller and clip the legacy toolbar outside the
                  // visible area. The document itself remains fully visible.
                  const legacyToolbarHeight = 44.0;
                  final previewHeight =
                      constraints.maxHeight + legacyToolbarHeight;

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
  });

  final String title;
  final String url;
  final String mimeType;
  final String extension;

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
  String? _textBody;
  String? _error;

  bool get _isImage {
    final mime = widget.mimeType.toLowerCase();
    return mime.startsWith('image/') ||
        const <String>{'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}
            .contains(widget.extension);
  }

  bool get _isText {
    final mime = widget.mimeType.toLowerCase();
    return mime.startsWith('text/') ||
        const <String>{'txt', 'md', 'csv', 'json', 'xml', 'log', 'yaml', 'yml'}
            .contains(widget.extension);
  }

  @override
  void initState() {
    super.initState();
    if (_isText) _loadText();
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

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.trim().isEmpty ? 'Документ' : widget.title.trim();
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

    return _message(
      'Документ остаётся внутри SPORTOTEKA. Для этого формата доступен переход к оригиналу.',
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
