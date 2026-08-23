import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PlansEmbeddedFileViewer extends StatefulWidget {
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
  State<PlansEmbeddedFileViewer> createState() =>
      _PlansEmbeddedFileViewerState();
}

class _PlansEmbeddedFileViewerState extends State<PlansEmbeddedFileViewer> {
  WebViewController? _controller;
  bool _loading = true;
  bool _usingGoogle = false;
  String? _error;

  bool get _supportsEmbeddedWebView {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  String get _officeUrl =>
      'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(widget.sourceUrl)}';

  String get _googleUrl =>
      'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.sourceUrl)}';

  @override
  void initState() {
    super.initState();
    if (_supportsEmbeddedWebView) {
      _createController();
    } else {
      _loading = false;
      _error = 'Встроенный просмотр недоступен на этой платформе.';
    }
  }

  void _createController() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() {
              _loading = false;
              _error = error.description;
            });
          },
          onHttpError: (error) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error =
                  'Просмотрщик вернул HTTP ${error.response?.statusCode ?? ''}';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url.isEmpty ? _officeUrl : widget.url));

    _controller = controller;
  }

  Future<void> _switchViewer() async {
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      _usingGoogle = !_usingGoogle;
      _loading = true;
      _error = null;
    });

    await controller.loadRequest(
      Uri.parse(_usingGoogle ? _googleUrl : _officeUrl),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _controller?.reload();
  }

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(widget.sourceUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsEmbeddedWebView || _controller == null) {
      return _Fallback(
        title: widget.title,
        sourceUrl: widget.sourceUrl,
        error: _error,
        onOpen: _openOriginal,
      );
    }

    return ColoredBox(
      color: const Color(0xFFF7F8FA),
      child: Column(
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _usingGoogle
                        ? 'Google Docs Viewer'
                        : 'Microsoft Office Viewer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF101828),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _ToolButton(
                  icon: Icons.swap_horiz_rounded,
                  tooltip: 'Сменить просмотрщик',
                  onTap: _switchViewer,
                ),
                const SizedBox(width: 6),
                _ToolButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Повторить',
                  onTap: _reload,
                ),
                const SizedBox(width: 6),
                _ToolButton(
                  icon: Icons.open_in_new_rounded,
                  tooltip: 'Открыть оригинал',
                  onTap: _openOriginal,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: WebViewWidget(controller: _controller!),
                ),
                if (_loading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0xCCFFFFFF),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF00A750),
                        ),
                      ),
                    ),
                  ),
                if (_error != null && !_loading)
                  Positioned.fill(
                    child: _ErrorPanel(
                      error: _error!,
                      onRetry: _reload,
                      onSwitch: _switchViewer,
                      onOpen: _openOriginal,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF667085)),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onSwitch;
  final VoidCallback onOpen;

  const _ErrorPanel({
    required this.error,
    required this.onRetry,
    required this.onSwitch,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F8FA),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.article_outlined,
                  size: 38,
                  color: Color(0xFF667085),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Документ пока не открылся',
                  style: TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Повторить'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onSwitch,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                      label: const Text('Другой просмотрщик'),
                    ),
                    ElevatedButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: const Text('Открыть файл'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String title;
  final String sourceUrl;
  final String? error;
  final VoidCallback onOpen;

  const _Fallback({
    required this.title,
    required this.sourceUrl,
    required this.error,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F8FA),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.article_rounded,
                  size: 38, color: Color(0xFF667085)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('Открыть документ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
