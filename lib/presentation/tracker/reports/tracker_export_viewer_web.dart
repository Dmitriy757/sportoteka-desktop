// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class TrackerExportViewer extends StatefulWidget {
  const TrackerExportViewer({super.key, required this.uri});

  final Uri uri;

  @override
  State<TrackerExportViewer> createState() => _TrackerExportViewerState();
}

class _TrackerExportViewerState extends State<TrackerExportViewer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'sportoteka-export-viewer-${DateTime.now().microsecondsSinceEpoch}-${widget.uri.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = widget.uri.toString()
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#ffffff'
        ..allowFullscreen = true;
      iframe.setAttribute('loading', 'lazy');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
