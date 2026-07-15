// ignore_for_file: avoid_web_libraries_in_flutter, undefined_prefixed_name
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
  late final String _viewType;
  late final html.IFrameElement _iframe;
  bool _usingGoogle = false;
  bool _loading = true;

  String get _officeUrl =>
      'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(widget.sourceUrl)}';

  String get _googleUrl =>
      'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.sourceUrl)}';

  @override
  void initState() {
    super.initState();
    _viewType = 'plans-file-viewer-${DateTime.now().microsecondsSinceEpoch}';

    _iframe = html.IFrameElement()
      ..src = widget.url.isEmpty ? _officeUrl : widget.url
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#ffffff'
      ..allowFullscreen = true
      ..setAttribute('allow', 'fullscreen')
      ..setAttribute('referrerpolicy', 'no-referrer-when-downgrade');

    _iframe.onLoad.listen((_) {
      if (mounted) setState(() => _loading = false);
    });

    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );
  }

  void _switchViewer() {
    setState(() {
      _usingGoogle = !_usingGoogle;
      _loading = true;
    });
    _iframe.src = _usingGoogle ? _googleUrl : _officeUrl;
  }

  void _reload() {
    setState(() => _loading = true);
    _iframe.src = _iframe.src;
  }

  void _openOriginal() {
    html.window.open(widget.sourceUrl, '_blank');
  }

  @override
  Widget build(BuildContext context) {
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
                    style: const TextStyle(
                      color: Color(0xFF101828),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _WebTool(
                  icon: Icons.swap_horiz_rounded,
                  tooltip: 'Сменить просмотрщик',
                  onTap: _switchViewer,
                ),
                const SizedBox(width: 6),
                _WebTool(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Повторить',
                  onTap: _reload,
                ),
                const SizedBox(width: 6),
                _WebTool(
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
                Positioned.fill(child: HtmlElementView(viewType: _viewType)),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebTool extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _WebTool({
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
