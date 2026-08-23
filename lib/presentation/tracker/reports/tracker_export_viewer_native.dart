import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TrackerExportViewer extends StatefulWidget {
  const TrackerExportViewer({super.key, required this.uri});

  final Uri uri;

  @override
  State<TrackerExportViewer> createState() => _TrackerExportViewerState();
}

class _TrackerExportViewerState extends State<TrackerExportViewer> {
  late Future<_TrackerExportPayload> _future;
  WebViewController? _htmlController;
  int _htmlSignature = 0;
  bool _saving = false;

  static const _green = Color(0xFF00A750);
  static const _greenDark = Color(0xFF067A46);
  static const _softGreen = Color(0xFFF3FAF6);
  static const _soft = Color(0xFFF7F8F7);
  static const _line = Color(0xFFE9ECEA);
  static const _text = Color(0xFF0B0F14);
  static const _muted = Color(0xFF5F6670);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant TrackerExportViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _htmlController = null;
      _htmlSignature = 0;
      _future = _load();
    }
  }

  Future<_TrackerExportPayload> _load() async {
    final response = await http
        .get(widget.uri)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Ошибка выгрузки (${response.statusCode})');
    }

    final contentType =
        (response.headers['content-type'] ?? '').toLowerCase();
    final disposition =
        (response.headers['content-disposition'] ?? '').toLowerCase();
    final bytes = response.bodyBytes;
    final lowerUrl = widget.uri.toString().toLowerCase();
    final isCsvRequest = lowerUrl.contains('export_training_report_csv') ||
        lowerUrl.endsWith('.csv') ||
        lowerUrl.contains('format=csv');

    if (contentType.contains('application/pdf') || _looksLikePdf(bytes)) {
      return _TrackerExportPayload.pdf(bytes);
    }

    final text = utf8.decode(bytes, allowMalformed: true);
    if (isCsvRequest ||
        contentType.contains('text/csv') ||
        disposition.contains('.csv')) {
      return _TrackerExportPayload.csv(text);
    }

    // На сервере без Dompdf тот же endpoint возвращает печатный HTML.
    // Раньше он открывался внешней ссылкой. Теперь этот HTML остаётся внутри
    // Sportoteka и показывается во встроенном WebView.
    if (contentType.contains('text/html') ||
        text.trimLeft().startsWith('<!doctype') ||
        text.trimLeft().startsWith('<html')) {
      return _TrackerExportPayload.html(text);
    }

    throw Exception('Сервер вернул неподдерживаемый формат отчёта.');
  }

  bool _looksLikePdf(Uint8List bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  WebViewController _controllerForHtml(String html) {
    final signature = Object.hash(html.length, html.hashCode, widget.uri);
    if (_htmlController != null && _htmlSignature == signature) {
      return _htmlController!;
    }
    _htmlSignature = signature;
    final sourceHost = widget.uri.host.toLowerCase();

    // Не вызываем WebViewController.setBackgroundColor здесь.
    // На macOS webview_flutter_wkwebview реализует этот вызов через
    // WKWebView.setOpaque(false), а NSView-реализация пока бросает
    // UnimplementedError('opaque is not implemented on macOS').
    // Белый фон уже задаётся Flutter-контейнером и самим HTML-отчётом.
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final next = Uri.tryParse(request.url);
            if (next == null) return NavigationDecision.prevent;
            if (next.scheme == 'about' || next.scheme == 'data') {
              return NavigationDecision.navigate;
            }
            if ((next.scheme == 'http' || next.scheme == 'https') &&
                next.host.toLowerCase() == sourceHost) {
              return NavigationDecision.navigate;
            }
            // Документ остаётся внутри программы: переходы на сторонние сайты
            // из печатного шаблона не выпускаем во внешний браузер.
            return NavigationDecision.prevent;
          },
        ),
      );
    final baseUrl = widget.uri.hasAuthority
        ? '${widget.uri.scheme}://${widget.uri.authority}/'
        : null;
    controller.loadHtmlString(html, baseUrl: baseUrl);
    _htmlController = controller;
    return controller;
  }

  String _safeFilePart(String value) {
    final clean = value
        .trim()
        .replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return clean.isEmpty ? 'report' : clean;
  }

  String _defaultPdfFileName() {
    final team = widget.uri.queryParameters['team_id'] ?? '';
    final session = widget.uri.queryParameters['session_id'] ?? '';
    final sessions = widget.uri.queryParameters['session_ids'] ?? '';
    final stamp = DateTime.now();
    final date =
        '${stamp.year.toString().padLeft(4, '0')}-${stamp.month.toString().padLeft(2, '0')}-${stamp.day.toString().padLeft(2, '0')}';
    final suffix = session.isNotEmpty
        ? 'session_${_safeFilePart(session)}'
        : sessions.isNotEmpty
            ? 'sessions_${_safeFilePart(sessions)}'
            : 'team_${_safeFilePart(team)}';
    return 'sportoteka_${suffix}_$date.pdf';
  }

  Uri _forcedPdfUri() {
    final qp = <String, String>{...widget.uri.queryParameters};
    qp['format'] = 'pdf';
    qp['download'] = '1';
    qp['attachment'] = '1';
    qp.remove('html');
    return widget.uri.replace(queryParameters: qp);
  }

  Future<Uint8List?> _loadPdfBytesForSave(_TrackerExportPayload payload) async {
    if (payload.kind == _TrackerExportKind.pdf && payload.bytes != null) {
      return payload.bytes;
    }

    // Если просмотр открыт как HTML (например, сервер не смог отдать PDF с
    // первого запроса), один раз явно просим PDF-ответ. Это не открывает сайт:
    // файл всё равно остаётся внутри приложения и сохраняется через native dialog.
    final response = await http
        .get(_forcedPdfUri())
        .timeout(const Duration(seconds: 60));
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        ((response.headers['content-type'] ?? '')
                .toLowerCase()
                .contains('application/pdf') ||
            _looksLikePdf(response.bodyBytes))) {
      return response.bodyBytes;
    }
    return null;
  }

  Future<void> _savePdf(_TrackerExportPayload payload) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await _loadPdfBytesForSave(payload);
      if (bytes == null || bytes.isEmpty) {
        if (payload.kind == _TrackerExportKind.html && _htmlController != null) {
          // На сервере без Dompdf настоящих PDF-байтов нет. Оставляем пользователя
          // внутри приложения и вызываем системную печать текущего документа:
          // на macOS в диалоге можно выбрать стандартное «Save as PDF».
          try {
            await _htmlController!.runJavaScript('window.print();');
          } catch (_) {}
        }
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'Сервер вернул HTML вместо PDF. Открыта печать — выберите «Сохранить как PDF».',
              ),
            ),
          );
        }
        return;
      }

      final saved = await FilePicker.saveFile(
        dialogTitle: 'Сохранить отчёт Спортотеки',
        fileName: _defaultPdfFileName(),
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
      if (!mounted || saved == null) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('PDF сохранён: $saved')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Не удалось сохранить PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _documentToolbar({
    required _TrackerExportPayload payload,
    required String title,
    String? subtitle,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _softGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: _greenDark, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.custom(
                    size: 11.8,
                    weight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.custom(
                      size: 9.7,
                      weight: FontWeight.w400,
                      color: _muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _saving ? null : () => _savePdf(payload),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              backgroundColor: _green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _softGreen,
              disabledForegroundColor: _greenDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: AppTypography.custom(
                size: 10.5,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: _greenDark,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 16),
            label: Text(_saving ? 'Сохраняю…' : 'Сохранить PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCsv() async {
    final ok = await launchUrl(widget.uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Не удалось выгрузить Excel / CSV.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TrackerExportPayload>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _statePanel(
            icon: Icons.picture_as_pdf_rounded,
            title: 'Формируем документ',
            subtitle: 'PDF загружается во встроенный просмотр Спортотеки.',
            progress: true,
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _statePanel(
            icon: Icons.error_outline_rounded,
            title: 'Не удалось открыть отчёт',
            subtitle: '${snapshot.error ?? 'Неизвестная ошибка'}',
            actionLabel: 'Повторить',
            onAction: () => setState(() => _future = _load()),
          );
        }

        final payload = snapshot.data!;
        switch (payload.kind) {
          case _TrackerExportKind.pdf:
            return ColoredBox(
              color: Colors.white,
              child: Column(
                children: [
                  _documentToolbar(
                    payload: payload,
                    title: 'PDF отчёт готов',
                    subtitle: 'Сохранение идёт напрямую на устройство, без сайта',
                  ),
                  Expanded(
                    child: SfPdfViewer.memory(
                      payload.bytes!,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                      canShowPaginationDialog: false,
                    ),
                  ),
                ],
              ),
            );
          case _TrackerExportKind.html:
            return ColoredBox(
              color: Colors.white,
              child: Column(
                children: [
                  _documentToolbar(
                    payload: payload,
                    title: 'Печатная версия отчёта',
                    subtitle: 'Если сервер отдаст PDF — файл сохранится напрямую',
                  ),
                  Expanded(
                    child: WebViewWidget(
                      controller: _controllerForHtml(payload.text!),
                    ),
                  ),
                ],
              ),
            );
          case _TrackerExportKind.csv:
            return _csvPreview(payload.text!);
        }
      },
    );
  }

  Widget _statePanel({
    required IconData icon,
    required String title,
    required String subtitle,
    bool progress = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _softGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: progress
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            color: _green,
                            strokeWidth: 2.2,
                          ),
                        )
                      : Icon(icon, color: _greenDark, size: 23),
                ),
                const SizedBox(height: 13),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.custom(
                    size: 15,
                    weight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.custom(
                    size: 10.8,
                    weight: FontWeight.w400,
                    color: _muted,
                    height: 1.3,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _csvPreview(String text) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: _soft,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded,
                    color: _greenDark, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Предпросмотр Excel / CSV',
                    style: AppTypography.custom(
                      size: 12,
                      weight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _downloadCsv,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Выгрузить файл'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.topLeft,
                child: SelectableText(
                  text,
                  style: AppTypography.custom(
                    size: 10.2,
                    weight: FontWeight.w400,
                    color: _text,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TrackerExportKind { pdf, html, csv }

class _TrackerExportPayload {
  const _TrackerExportPayload._(this.kind, {this.bytes, this.text});

  factory _TrackerExportPayload.pdf(Uint8List bytes) =>
      _TrackerExportPayload._(_TrackerExportKind.pdf, bytes: bytes);
  factory _TrackerExportPayload.html(String text) =>
      _TrackerExportPayload._(_TrackerExportKind.html, text: text);
  factory _TrackerExportPayload.csv(String text) =>
      _TrackerExportPayload._(_TrackerExportKind.csv, text: text);

  final _TrackerExportKind kind;
  final Uint8List? bytes;
  final String? text;
}
