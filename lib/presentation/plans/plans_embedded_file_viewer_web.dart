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
  State<PlansEmbeddedFileViewer> createState() => _PlansEmbeddedFileViewerState();
}

class _PlansEmbeddedFileViewerState extends State<PlansEmbeddedFileViewer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'plans-file-viewer-${DateTime.now().microsecondsSinceEpoch}';
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = widget.url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7F8),
      child: Stack(
        children: [
          Positioned.fill(child: HtmlElementView(viewType: _viewType)),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.82),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w700,
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
