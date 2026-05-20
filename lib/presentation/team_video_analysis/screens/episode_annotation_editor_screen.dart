import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/team_video_analysis/models/tactical_annotation_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/painters/tactical_annotation_painter.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/api_constants.dart';

class EpisodeAnnotationEditorScreen extends StatefulWidget {
  final int episodeId;
  final int coachId;
  final String imageUrl;

  const EpisodeAnnotationEditorScreen({
    super.key,
    required this.episodeId,
    required this.coachId,
    required this.imageUrl,
  });

  @override
  State<EpisodeAnnotationEditorScreen> createState() =>
      _EpisodeAnnotationEditorScreenState();
}

class _EpisodeAnnotationEditorScreenState
    extends State<EpisodeAnnotationEditorScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _playerMarkerCtrl = TextEditingController();

  List<TacticalAnnotation> _items = [];
  TacticalAnnotation? _draft;
  String? _selectedId;

  final List<List<TacticalAnnotation>> _undoStack = [];
  final List<List<TacticalAnnotation>> _redoStack = [];

  TacticalToolType _tool = TacticalToolType.freeDraw;
  Color _selectedColor = const Color(0xFFEF4444);
  double _strokeWidth = 4.0;
  double _opacity = 1.0;
  bool _zoneFilled = true;

  bool _loading = true;
  bool _saving = false;
  String? _message;
  bool _messageError = false;

  Size? _imageNaturalSize;
  bool _imageInfoLoading = true;
  bool _imageLoadError = false;

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadAnnotations();
    _loadImageInfo();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _playerMarkerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadImageInfo() async {
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _imageLoadError = true;
        _imageInfoLoading = false;
      });
      return;
    }

    setState(() {
      _imageInfoLoading = true;
      _imageLoadError = false;
    });

    try {
      final imageProvider = NetworkImage(widget.imageUrl);
      final stream = imageProvider.resolve(const ImageConfiguration());

      final listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!mounted) return;
          setState(() {
            _imageNaturalSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
            _imageInfoLoading = false;
            _imageLoadError = false;
          });
        },
        onError: (error, stackTrace) {
          if (!mounted) return;
          setState(() {
            _imageNaturalSize = null;
            _imageInfoLoading = false;
            _imageLoadError = true;
          });
          _showMessage('Ошибка загрузки изображения', isError: true);
        },
      );

      stream.addListener(listener);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _imageInfoLoading = false;
        _imageLoadError = true;
      });
      _showMessage('Ошибка загрузки изображения', isError: true);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    setState(() {
      _message = text;
      _messageError = isError;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_message == text) {
        setState(() => _message = null);
      }
    });
  }

  Map<String, dynamic> _safeDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {
        'success': false,
        'message': 'Некорректный JSON-ответ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Ошибка JSON: $e',
      };
    }
  }

  List<TacticalAnnotation> _cloneItems(List<TacticalAnnotation> source) {
    return source
        .map((e) =>
            TacticalAnnotation.fromJson(Map<String, dynamic>.from(e.toJson())))
        .toList();
  }

  void _pushUndoState() {
    _undoStack.add(_cloneItems(_items));
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_cloneItems(_items));
    setState(() {
      _items = _undoStack.removeLast();
      _selectedId = null;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_cloneItems(_items));
    setState(() {
      _items = _redoStack.removeLast();
      _selectedId = null;
    });
  }

  Future<void> _loadAnnotations() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.apiBase}/get_episode_annotations.php?episode_id=${widget.episodeId}',
      );

      final res = await http.get(uri);
      final body = utf8.decode(res.bodyBytes, allowMalformed: true).trim();
      final data = _safeDecode(body);

      if (data['success'] == true) {
        final annotation = data['annotation'];
        String raw = '';

        if (annotation is Map && annotation['annotations_json'] != null) {
          raw = annotation['annotations_json'].toString();
        } else if (data['annotations_json'] != null) {
          raw = data['annotations_json'].toString();
        }

        setState(() {
          _items = TacticalAnnotation.decodeList(raw);
        });
      } else {
        _showMessage(
          _s(data['message']).isNotEmpty
              ? _s(data['message'])
              : 'Не удалось загрузить разметку',
          isError: true,
        );
      }
    } catch (e) {
      _showMessage('Ошибка загрузки: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveAnnotations() async {
    setState(() => _saving = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.apiBase}/save_episode_annotations.php'),
        body: {
          'episode_id': widget.episodeId.toString(),
          'coach_id': widget.coachId.toString(),
          'image_url': widget.imageUrl,
          'annotations_json': TacticalAnnotation.encodeList(_items),
        },
      );

      final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      final data = _safeDecode(body);

      if (data['success'] == true) {
        _showMessage('Разметка сохранена');
      } else {
        _showMessage(
          _s(data['message']).isNotEmpty
              ? _s(data['message'])
              : 'Ошибка сохранения',
          isError: true,
        );
      }
    } catch (e) {
      _showMessage('Сетевая ошибка: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Offset _normalizeOffset(Offset local, Size size) {
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
  }

  Rect _scaledRectFromAnnotation(TacticalAnnotation item, Size size) {
    if (item.start != null && item.end != null) {
      final a =
          Offset(item.start!.dx * size.width, item.start!.dy * size.height);
      final b = Offset(item.end!.dx * size.width, item.end!.dy * size.height);
      return Rect.fromPoints(a, b);
    }

    if (item.textOffset != null) {
      final p = Offset(
        item.textOffset!.dx * size.width,
        item.textOffset!.dy * size.height,
      );
      return Rect.fromLTWH(p.dx - 8, p.dy - 8, 140, 42);
    }

    if (item.points != null && item.points!.isNotEmpty) {
      final scaled = item.points!
          .map((p) => Offset(p.dx * size.width, p.dy * size.height))
          .toList();

      double minX = scaled.first.dx;
      double maxX = scaled.first.dx;
      double minY = scaled.first.dy;
      double maxY = scaled.first.dy;

      for (final p in scaled) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }

      return Rect.fromLTRB(minX, minY, maxX, maxY);
    }

    return Rect.zero;
  }

  String? _hitTestAnnotation(Offset local, Size size) {
    for (int i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      final rect = _scaledRectFromAnnotation(item, size).inflate(22);
      if (rect.contains(local)) {
        return item.id;
      }
    }
    return null;
  }

  Future<String?> _askTextNote() async {
    _textCtrl.clear();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Текстовая заметка',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: _textCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Например: свободная зона / поздний выход / прессинг',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _textCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askPlayerMarkerText() async {
    _playerMarkerCtrl.clear();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Маркер игрока',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: _playerMarkerCtrl,
          autofocus: true,
          maxLength: 4,
          decoration: InputDecoration(
            hintText: '7 / CF / GK',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, _playerMarkerCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _deleteSelected() {
    if (_selectedId == null) return;
    _pushUndoState();
    setState(() {
      _items.removeWhere((e) => e.id == _selectedId);
      _selectedId = null;
    });
  }

  void _clearAll() {
    if (_items.isEmpty) return;
    _pushUndoState();
    setState(() {
      _items.clear();
      _selectedId = null;
    });
  }

  void _updateSelectedStyle() {
    if (_selectedId == null) return;
    final index = _items.indexWhere((e) => e.id == _selectedId);
    if (index == -1) return;

    setState(() {
      _items[index] = _items[index].copyWith(
        color: _selectedColor,
        strokeWidth: _strokeWidth,
        opacity: _opacity,
        filled: _items[index].type == TacticalToolType.zone
            ? _zoneFilled
            : _items[index].filled,
      );
    });
  }

  void _onPanStart(DragStartDetails details, Size size) async {
    final local = details.localPosition;
    final normalized = _normalizeOffset(local, size);

    if (_tool == TacticalToolType.select) {
      final hit = _hitTestAnnotation(local, size);
      setState(() => _selectedId = hit);
      return;
    }

    if (_tool == TacticalToolType.eraser) {
      final hit = _hitTestAnnotation(local, size);
      if (hit != null) {
        _pushUndoState();
        setState(() {
          _items.removeWhere((e) => e.id == hit);
          if (_selectedId == hit) _selectedId = null;
        });
      }
      return;
    }

    if (_tool == TacticalToolType.text) {
      final text = await _askTextNote();
      if (!mounted || text == null || text.trim().isEmpty) return;

      _pushUndoState();
      setState(() {
        _selectedId = null;
        _items.add(
          TacticalAnnotation(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: TacticalToolType.text,
            color: _selectedColor,
            strokeWidth: _strokeWidth,
            opacity: _opacity,
            text: text.trim(),
            textOffset: normalized,
            fontSize: 18,
          ),
        );
      });
      return;
    }

    if (_tool == TacticalToolType.playerMarker) {
      final text = await _askPlayerMarkerText();
      if (!mounted || text == null || text.trim().isEmpty) return;

      _pushUndoState();
      setState(() {
        _selectedId = null;
        _items.add(
          TacticalAnnotation(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: TacticalToolType.playerMarker,
            color: _selectedColor,
            strokeWidth: _strokeWidth,
            opacity: _opacity,
            start: normalized,
            text: text.trim(),
          ),
        );
      });
      return;
    }

    _pushUndoState();

    setState(() {
      _selectedId = null;
      _draft = TacticalAnnotation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: _tool,
        color: _selectedColor,
        strokeWidth: _strokeWidth,
        opacity: _opacity,
        start: normalized,
        end: normalized,
        points: _tool == TacticalToolType.freeDraw ? [normalized] : null,
        lineStyle: _tool == TacticalToolType.dashedLine
            ? TacticalLineStyle.dashed
            : TacticalLineStyle.solid,
        filled: _tool == TacticalToolType.zone ? _zoneFilled : false,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_draft == null) return;

    final normalized = _normalizeOffset(details.localPosition, size);

    if (_draft!.type == TacticalToolType.freeDraw) {
      final nextPoints = [...?_draft!.points, normalized];
      setState(() {
        _draft = _draft!.copyWith(points: nextPoints);
      });
      return;
    }

    setState(() {
      _draft = _draft!.copyWith(end: normalized);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_draft == null) return;

    setState(() {
      _items.add(_draft!);
      _draft = null;
    });
  }

  String _toolTitle(TacticalToolType tool) {
    switch (tool) {
      case TacticalToolType.select:
        return 'Выбор';
      case TacticalToolType.passArrow:
        return 'Пас';
      case TacticalToolType.runArrow:
        return 'Рывок';
      case TacticalToolType.straightLine:
        return 'Линия';
      case TacticalToolType.dashedLine:
        return 'Пунктир';
      case TacticalToolType.circle:
        return 'Круг';
      case TacticalToolType.rect:
        return 'Рамка';
      case TacticalToolType.zone:
        return 'Зона';
      case TacticalToolType.playerMarker:
        return 'Игрок';
      case TacticalToolType.text:
        return 'Текст';
      case TacticalToolType.freeDraw:
        return 'Перо';
      case TacticalToolType.eraser:
        return 'Ластик';
    }
  }

  IconData _toolIcon(TacticalToolType tool) {
    switch (tool) {
      case TacticalToolType.select:
        return Icons.ads_click_rounded;
      case TacticalToolType.passArrow:
        return Icons.arrow_right_alt_rounded;
      case TacticalToolType.runArrow:
        return Icons.trending_up_rounded;
      case TacticalToolType.straightLine:
        return Icons.show_chart_rounded;
      case TacticalToolType.dashedLine:
        return Icons.more_horiz_rounded;
      case TacticalToolType.circle:
        return Icons.circle_outlined;
      case TacticalToolType.rect:
        return Icons.crop_square_rounded;
      case TacticalToolType.zone:
        return Icons.space_dashboard_outlined;
      case TacticalToolType.playerMarker:
        return Icons.person_pin_circle_outlined;
      case TacticalToolType.text:
        return Icons.text_fields_rounded;
      case TacticalToolType.freeDraw:
        return Icons.gesture_rounded;
      case TacticalToolType.eraser:
        return Icons.auto_fix_off_rounded;
    }
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(12),
    double radius = 22,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _topHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _roundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
            iconColor: const Color(0xFF111827),
            bgColor: const Color(0xFFF3F4F6),
            borderColor: const Color(0xFFE5E7EB),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Тактический разбор эпизода',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Скрин в центре · панели поверх кадра',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _roundIconButton(
            icon: Icons.undo_rounded,
            onTap: _undoStack.isEmpty ? null : _undo,
            iconColor: const Color(0xFF111827),
            bgColor: const Color(0xFFF3F4F6),
            borderColor: const Color(0xFFE5E7EB),
          ),
          const SizedBox(width: 8),
          _roundIconButton(
            icon: Icons.redo_rounded,
            onTap: _redoStack.isEmpty ? null : _redo,
            iconColor: const Color(0xFF111827),
            bgColor: const Color(0xFFF3F4F6),
            borderColor: const Color(0xFFE5E7EB),
          ),
          const SizedBox(width: 8),
          _roundIconButton(
            icon: Icons.delete_sweep_rounded,
            onTap: _items.isEmpty ? null : _clearAll,
            iconColor: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFECACA),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _saving ? null : _saveAnnotations,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1D4ED8),
                    Color(0xFF2563EB),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.20),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Сохранить',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    Color iconColor = Colors.white,
    Color bgColor = Colors.white,
    Color borderColor = const Color(0xFFE5E7EB),
  }) {
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.38,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  Widget _toolButton(TacticalToolType tool) {
    final selected = _tool == tool;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tool = tool;
          _selectedId = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 78,
        height: 58,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF2563EB)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _toolIcon(tool),
                color: selected ? Colors.white : const Color(0xFF111827),
                size: 17,
              ),
              const SizedBox(height: 3),
              Flexible(
                child: Text(
                  _toolTitle(tool),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                    fontSize: 9.5,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leftToolsPanel() {
    return _glassPanel(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: 96,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _toolButton(TacticalToolType.select),
              const SizedBox(height: 8),
              _toolButton(TacticalToolType.passArrow),
              const SizedBox(height: 8),
              _toolButton(TacticalToolType.runArrow),
              const SizedBox(height: 8),
              _toolButton(TacticalToolType.straightLine),
              const SizedBox(height: 8),
              _toolButton(TacticalToolType.dashedLine),
              const SizedBox(height: 8),
              _toolButton(TacticalToolType.circle),
              const SizedBox(height: 8),
              _toolButton(TacticalToolType.rect),
              const SizedBox(height: 8),
              _toolButton(TacticalToolType.zone),
              const SizedBox(height: 8),
              _toolButton(TacticalToolType.playerMarker),
              const SizedBox(height: 8),
              _toolButton(TacticalToolType.text),
              const SizedBox(height: 8),
              _toolButton(TacticalToolType.freeDraw),
              const SizedBox(height: 8),
              _toolButton(TacticalToolType.eraser),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorDot(Color color) {
    final selected = _selectedColor.value == color.value;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedColor = color);
        _updateSelectedStyle();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: selected ? 34 : 28,
        height: selected ? 34 : 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? const Color(0xFF111827) : const Color(0xFFD1D5DB),
            width: selected ? 3 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.20),
              blurRadius: selected ? 10 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rightPropertiesPanel() {
    final hasSelected = _selectedId != null;

    return _glassPanel(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Свойства',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasSelected
                    ? 'Выбран объект для редактирования'
                    : 'Активный инструмент: ${_toolTitle(_tool)}',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Цвет',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _colorDot(const Color(0xFFEF4444)),
                  _colorDot(const Color(0xFF2563EB)),
                  _colorDot(const Color(0xFF16A34A)),
                  _colorDot(const Color(0xFFF59E0B)),
                  _colorDot(Colors.white),
                  _colorDot(Colors.black),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Толщина',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF2563EB),
                  inactiveTrackColor: const Color(0xFFE5E7EB),
                  thumbColor: const Color(0xFF2563EB),
                  overlayColor: const Color(0xFF2563EB).withOpacity(0.15),
                ),
                child: Slider(
                  value: _strokeWidth,
                  min: 2,
                  max: 10,
                  divisions: 8,
                  label: _strokeWidth.toStringAsFixed(0),
                  onChanged: (v) {
                    setState(() => _strokeWidth = v);
                    _updateSelectedStyle();
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _strokeWidth.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Прозрачность',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF2563EB),
                  inactiveTrackColor: const Color(0xFFE5E7EB),
                  thumbColor: const Color(0xFF2563EB),
                  overlayColor: const Color(0xFF2563EB).withOpacity(0.15),
                ),
                child: Slider(
                  value: _opacity,
                  min: 0.2,
                  max: 1.0,
                  divisions: 8,
                  label: _opacity.toStringAsFixed(1),
                  onChanged: (v) {
                    setState(() => _opacity = v);
                    _updateSelectedStyle();
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _opacity.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Заливка зоны',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Switch(
                    value: _zoneFilled,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (v) {
                      setState(() => _zoneFilled = v);
                      _updateSelectedStyle();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (hasSelected)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Удалить объект'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageOverlay() {
    if (_message == null) return const SizedBox.shrink();

    return Positioned(
      top: 84,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _messageError
                ? const Color(0xFFFEF2F2)
                : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _messageError
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFBBF7D0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _messageError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                color: _messageError
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF166534),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _messageError
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF166534),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _canvasCenter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight <= 0) {
          return Container(
            color: Colors.white,
            child: const Center(
              child: Text(
                'Waiting for layout...',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          );
        }

        if (_imageInfoLoading) {
          return Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_imageLoadError || _imageNaturalSize == null) {
          return Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Error loading image',
                    style: TextStyle(color: Colors.black, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SelectableText(
                      widget.imageUrl,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadImageInfo,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final imageAspect = _imageNaturalSize!.width / _imageNaturalSize!.height;
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        final double effectiveHeight = maxHeight > 0 ? maxHeight : 400.0;
        final double effectiveWidth = maxWidth > 0 ? maxWidth : 400.0;

        double drawWidth = effectiveWidth;
        double drawHeight = drawWidth / imageAspect;

        if (drawHeight > effectiveHeight) {
          drawHeight = effectiveHeight;
          drawWidth = drawHeight * imageAspect;
        }

        final drawSize = Size(drawWidth, drawHeight);

        return Container(
          color: Colors.white,
          alignment: Alignment.center,
          child: SizedBox(
            width: drawWidth,
            height: drawHeight,
            child: GestureDetector(
              onPanStart: (d) => _onPanStart(d, drawSize),
              onPanUpdate: (d) => _onPanUpdate(d, drawSize),
              onPanEnd: _onPanEnd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.imageUrl,
                    fit: BoxFit.fill,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Center(
                          child: Text(
                            'Image load error',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: TacticalAnnotationPainter(
                        items: [..._items, if (_draft != null) _draft!],
                        selectedId: _selectedId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _desktopCanvasLayout() {
    return SafeArea(
      child: Column(
        children: [
          _topHeader(),
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 12),
                _leftToolsPanel(),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _canvasCenter(),
                  ),
                ),
                const SizedBox(width: 12),
                _rightPropertiesPanel(),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileBottomToolbar() {
    final tools = [
      TacticalToolType.select,
      TacticalToolType.passArrow,
      TacticalToolType.runArrow,
      TacticalToolType.circle,
      TacticalToolType.zone,
      TacticalToolType.text,
      TacticalToolType.freeDraw,
      TacticalToolType.eraser,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tools.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) => _toolButton(tools[index]),
        ),
      ),
    );
  }

  Widget _mobilePropertiesCard() {
    final hasSelected = _selectedId != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasSelected ? 'Свойства объекта' : 'Свойства инструмента',
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _colorDot(const Color(0xFFEF4444)),
              _colorDot(const Color(0xFF2563EB)),
              _colorDot(const Color(0xFF16A34A)),
              _colorDot(const Color(0xFFF59E0B)),
              _colorDot(Colors.white),
              _colorDot(Colors.black),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Толщина',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2563EB),
              inactiveTrackColor: const Color(0xFFE5E7EB),
              thumbColor: const Color(0xFF2563EB),
            ),
            child: Slider(
              value: _strokeWidth,
              min: 2,
              max: 10,
              divisions: 8,
              onChanged: (v) {
                setState(() => _strokeWidth = v);
                _updateSelectedStyle();
              },
            ),
          ),
          const Text(
            'Прозрачность',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2563EB),
              inactiveTrackColor: const Color(0xFFE5E7EB),
              thumbColor: const Color(0xFF2563EB),
            ),
            child: Slider(
              value: _opacity,
              min: 0.2,
              max: 1.0,
              divisions: 8,
              onChanged: (v) {
                setState(() => _opacity = v);
                _updateSelectedStyle();
              },
            ),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Заливка зоны',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch(
                value: _zoneFilled,
                activeColor: const Color(0xFF2563EB),
                onChanged: (v) {
                  setState(() => _zoneFilled = v);
                  _updateSelectedStyle();
                },
              ),
            ],
          ),
          if (hasSelected) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _deleteSelected,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Удалить объект'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mobileCanvasLayout() {
    return SafeArea(
      child: Column(
        children: [
          _topHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _canvasCenter(),
            ),
          ),
          _mobilePropertiesCard(),
          _mobileBottomToolbar(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return isWide
                    ? _desktopCanvasLayout()
                    : _mobileCanvasLayout();
              },
            ),
    );
  }
}