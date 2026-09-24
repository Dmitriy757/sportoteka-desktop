import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class SportotekaAndroidStadiumController {
  MethodChannel? _channel;

  bool get isAttached => _channel != null;

  void _attach(MethodChannel channel) {
    _channel = channel;
  }

  void _detach() {
    _channel = null;
  }

  Future<void> setCamera({
    required double eyeX,
    required double eyeY,
    required double eyeZ,
    required double targetX,
    required double targetY,
    required double targetZ,
    required double verticalFovDegrees,
    required double nearPlane,
    required double farPlane,
  }) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod<void>('setCamera', <String, Object>{
      'eyeX': eyeX,
      'eyeY': eyeY,
      'eyeZ': eyeZ,
      'targetX': targetX,
      'targetY': targetY,
      'targetZ': targetZ,
      'verticalFovDegrees': verticalFovDegrees,
      'nearPlane': nearPlane,
      'farPlane': farPlane,
    });
  }

  Future<void> loadAsset(String assetPath) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod<void>('loadAsset', <String, Object>{
      'assetPath': assetPath,
    });
  }
}

class SportotekaAndroidStadiumView extends StatefulWidget {
  const SportotekaAndroidStadiumView({
    super.key,
    required this.assetPath,
    required this.eyeX,
    required this.eyeY,
    required this.eyeZ,
    required this.targetX,
    required this.targetY,
    required this.targetZ,
    required this.verticalFovDegrees,
    required this.nearPlane,
    required this.farPlane,
    this.useTextureView = true,
    this.backgroundColor = const Color(0xFF26463A),
    this.onCreated,
    this.onReady,
    this.onError,
  });

  final String assetPath;
  final double eyeX;
  final double eyeY;
  final double eyeZ;
  final double targetX;
  final double targetY;
  final double targetZ;
  final double verticalFovDegrees;
  final double nearPlane;
  final double farPlane;
  final bool useTextureView;
  final Color backgroundColor;
  final ValueChanged<SportotekaAndroidStadiumController>? onCreated;
  final VoidCallback? onReady;
  final ValueChanged<String>? onError;

  @override
  State<SportotekaAndroidStadiumView> createState() =>
      _SportotekaAndroidStadiumViewState();
}

class _SportotekaAndroidStadiumViewState
    extends State<SportotekaAndroidStadiumView> {
  final SportotekaAndroidStadiumController _controller =
      SportotekaAndroidStadiumController();
  MethodChannel? _channel;

  Map<String, Object> get _creationParams => <String, Object>{
        'assetPath': widget.assetPath,
        'eyeX': widget.eyeX,
        'eyeY': widget.eyeY,
        'eyeZ': widget.eyeZ,
        'targetX': widget.targetX,
        'targetY': widget.targetY,
        'targetZ': widget.targetZ,
        'verticalFovDegrees': widget.verticalFovDegrees,
        'nearPlane': widget.nearPlane,
        'farPlane': widget.farPlane,
        'useTextureView': widget.useTextureView,
        'backgroundColor': widget.backgroundColor.value,
      };

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('sportoteka/native_stadium/$id');
    _channel = channel;
    _controller._attach(channel);
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'ready':
          widget.onReady?.call();
          break;
        case 'error':
          final message = call.arguments?.toString() ?? 'Unknown Android Filament error';
          widget.onError?.call(message);
          break;
      }
    });
    // Start GLB loading only after Dart has installed the callback channel,
    // otherwise an early native asset error could be lost during view creation.
    unawaited(_controller.loadAsset(widget.assetPath));
    widget.onCreated?.call(_controller);
  }

  @override
  void didUpdateWidget(covariant SportotekaAndroidStadiumView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      unawaited(_controller.loadAsset(widget.assetPath));
    }
    if (oldWidget.eyeX != widget.eyeX ||
        oldWidget.eyeY != widget.eyeY ||
        oldWidget.eyeZ != widget.eyeZ ||
        oldWidget.targetX != widget.targetX ||
        oldWidget.targetY != widget.targetY ||
        oldWidget.targetZ != widget.targetZ ||
        oldWidget.verticalFovDegrees != widget.verticalFovDegrees ||
        oldWidget.nearPlane != widget.nearPlane ||
        oldWidget.farPlane != widget.farPlane) {
      unawaited(_controller.setCamera(
        eyeX: widget.eyeX,
        eyeY: widget.eyeY,
        eyeZ: widget.eyeZ,
        targetX: widget.targetX,
        targetY: widget.targetY,
        targetZ: widget.targetZ,
        verticalFovDegrees: widget.verticalFovDegrees,
        nearPlane: widget.nearPlane,
        farPlane: widget.farPlane,
      ));
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _controller._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    const viewType = 'sportoteka/native_stadium';
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers:
              const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: _creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        controller.addOnPlatformViewCreatedListener((id) {
          params.onPlatformViewCreated(id);
          _onPlatformViewCreated(id);
        });
        controller.create();
        return controller;
      },
    );
  }
}
