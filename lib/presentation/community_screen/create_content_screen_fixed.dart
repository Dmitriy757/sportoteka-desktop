import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/community_screen/create_post_editor_screen.dart';
import 'package:sportoteka/presentation/reels_screen/upload_reel_screen.dart';

enum CreateContentType { post, reel }

class CreateContentScreen extends StatefulWidget {
  final CreateContentType initialType;
  final String sportName;
  final String visibility;
  final String authorLabel;
  final int teamId;
  final int clubId;
  final String teamName;
  final bool pressMode;
  final bool embedded;
  final VoidCallback? onClose;
  final Future<void> Function()? onPostSaved;
  final Future<void> Function()? onReelSaved;

  const CreateContentScreen({
    super.key,
    this.initialType = CreateContentType.post,
    this.sportName = 'Футбол',
    this.visibility = 'feed',
    this.authorLabel = '',
    this.teamId = 0,
    this.clubId = 0,
    this.teamName = '',
    this.pressMode = false,
    this.embedded = false,
    this.onClose,
    this.onPostSaved,
    this.onReelSaved,
  });

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  late CreateContentType _type;
  final PostComposerController _postController = PostComposerController();
  final ReelComposerController _reelController = ReelComposerController();
  bool _finishing = false;

  bool get _saving => _type == CreateContentType.post
      ? _postController.saving
      : _reelController.saving;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _postController.addListener(_controllerChanged);
    _reelController.addListener(_controllerChanged);
  }

  @override
  void dispose() {
    _postController.removeListener(_controllerChanged);
    _reelController.removeListener(_controllerChanged);
    _postController.dispose();
    _reelController.dispose();
    super.dispose();
  }

  void _controllerChanged() {
    if (mounted) setState(() {});
  }

  TextStyle _text(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = const Color(0xFF111827),
  }) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: 1.15,
      letterSpacing: 0,
    );
  }

  void _close() {
    if (_saving || _finishing) return;
    if (widget.embedded) {
      widget.onClose?.call();
      return;
    }
    Navigator.of(context).pop<CreateContentType>();
  }

  Future<void> _submit() async {
    if (_saving || _finishing) return;
    if (_type == CreateContentType.post) {
      await _postController.submit();
    } else {
      await _reelController.submit();
    }
  }

  Future<void> _handleSaved(CreateContentType type) async {
    if (_finishing) return;
    _finishing = true;

    if (type == CreateContentType.post) {
      await widget.onPostSaved?.call();
    } else {
      await widget.onReelSaved?.call();
    }

    // Даем внутреннему редактору завершить finally (progress/saving)
    // до закрытия общего composer.
    await Future<void>.delayed(Duration.zero);

    if (!mounted) return;

    if (widget.embedded) {
      widget.onClose?.call();
    } else {
      Navigator.of(context).pop<CreateContentType>(type);
    }
  }

  void _selectType(CreateContentType type) {
    if (_saving || _finishing || type == _type) return;
    setState(() => _type = type);
  }

  Widget _brandDots() {
    const values = <(double, double)>[
      (3.5, .34),
      (4.5, .48),
      (5.5, .68),
      (6.5, 1),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < values.length; i++) ...[
          Container(
            width: values[i].$1,
            height: values[i].$1,
            decoration: BoxDecoration(
              color: const Color(0xFF00A750).withOpacity(values[i].$2),
              shape: BoxShape.circle,
            ),
          ),
          if (i != values.length - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }

  Widget _header() {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Назад',
              onPressed: _saving ? null : _close,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                widget.embedded
                    ? Icons.close_rounded
                    : Icons.arrow_back_ios_new_rounded,
                size: widget.embedded ? 19 : 18,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 1),
            _brandDots(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Создать',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(14.6, weight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: _saving ? null : _submit,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00A750),
                disabledForegroundColor: const Color(0xFFB8C1BC),
                padding: const EdgeInsets.symmetric(horizontal: 9),
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00A750),
                      ),
                    )
                  : Text(
                      'Поделиться',
                      style: _text(
                        10.5,
                        weight: FontWeight.w700,
                        color: const Color(0xFF00A750),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeSwitcher() {
    Widget item(CreateContentType type, String label) {
      final selected = _type == type;
      return Expanded(
        child: InkWell(
          onTap: _saving ? null : () => _selectType(type),
          child: SizedBox(
            height: 43,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  label,
                  style: _text(
                    11.2,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? const Color(0xFF111827)
                        : const Color(0xFF98A2B3),
                  ),
                ),
                if (selected)
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A750),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEF1EF), width: .7),
        ),
      ),
      child: Row(
        children: [
          item(CreateContentType.post, 'Публикация'),
          item(CreateContentType.reel, 'Reels'),
        ],
      ),
    );
  }

  Widget _composerBody() {
    return IndexedStack(
      index: _type == CreateContentType.post ? 0 : 1,
      children: [
        CreatePostEditorScreen(
          sportName: widget.sportName,
          visibility: widget.visibility,
          authorLabel: widget.authorLabel,
          teamId: widget.teamId,
          clubId: widget.clubId,
          teamName: widget.teamName,
          pressMode: widget.pressMode,
          embedded: true,
          hideChrome: true,
          composerController: _postController,
          forceSimpleComposer: true,
          onSaved: () {
            unawaited(_handleSaved(CreateContentType.post));
          },
        ),
        UploadReelScreen(
          embedded: true,
          hideChrome: true,
          composerController: _reelController,
          active: _type == CreateContentType.reel,
          onUploadComplete: () {
            unawaited(_handleSaved(CreateContentType.reel));
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final body = Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(
          fontFamily: AppTypography.fontFamily,
          bodyColor: const Color(0xFF111827),
          displayColor: const Color(0xFF111827),
        ),
      ),
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            _header(),
            _typeSwitcher(),
            Expanded(child: _composerBody()),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return SafeArea(top: false, bottom: false, child: body);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: body),
    );
  }
}
