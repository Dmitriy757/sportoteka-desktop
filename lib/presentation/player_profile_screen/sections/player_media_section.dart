import 'package:flutter/material.dart';

import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

class PlayerMediaSection extends StatefulWidget {
  final PlayerProfileSnapshot data;

  const PlayerMediaSection({
    super.key,
    required this.data,
  });

  @override
  State<PlayerMediaSection> createState() => _PlayerMediaSectionState();
}

class _PlayerMediaSectionState extends State<PlayerMediaSection> {
  int _selected = 0;

  String _s(dynamic value) => '${value ?? ''}'.trim();

  String _title(Map<String, dynamic> post) {
    final title = _s(post['title']);
    if (title.isNotEmpty) return title;
    final body = _body(post);
    if (body.isNotEmpty) {
      return body.length > 64 ? '${body.substring(0, 64)}…' : body;
    }
    return 'Публикация игрока';
  }

  String _body(Map<String, dynamic> post) =>
      _s(post['body'] ??
          post['description'] ??
          post['text'] ??
          post['caption']);

  String _date(Map<String, dynamic> post) =>
      _s(post['created_at'] ??
          post['published_at'] ??
          post['date']);

  String _author(Map<String, dynamic> post) =>
      _s(post['author'] ??
          post['author_name'] ??
          post['player_name'] ??
          post['user_name']);

  String _url(dynamic raw) {
    final value = _s(raw);
    if (value.isEmpty || value == 'null') return '';
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:image/')) {
      return value;
    }
    return 'https://sportotekaapp.ru${value.startsWith('/') ? value : '/$value'}';
  }

  String _image(Map<String, dynamic> post) {
    for (final key in const [
      'image',
      'image_url',
      'photo',
      'photo_url',
      'media_url',
      'thumbnail',
      'thumbnail_url',
      'preview',
      'preview_url',
      'cover',
      'cover_url',
    ]) {
      final value = _url(post[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _video(Map<String, dynamic> post) {
    for (final key in const [
      'video',
      'video_url',
      'media_video',
      'file_url',
    ]) {
      final value = _url(post[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final posts = widget.data.mediaFeed;
    if (_selected >= posts.length) _selected = 0;

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(
            children: [
              const PpDotCluster(color: PpColors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Медиа игрока', style: PpText.title(18)),
                    const SizedBox(height: 3),
                    Text(
                      'Публикации, фото, видео и заметки, которые игрок добавляет в свой профиль',
                      style: PpText.body(10.2),
                    ),
                  ],
                ),
              ),
              if (posts.isNotEmpty)
                PpSurface(
                  color: PpColors.greenSoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    '${posts.length}',
                    style: PpText.body(
                      10.4,
                      color: PpColors.greenDark,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          if (posts.isEmpty)
            PpSurface(
              color: PpColors.soft,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 18,
              ),
              child: Row(
                children: [
                  const PpDot(
                    color: PpColors.muted2,
                    size: 6,
                    glow: false,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Игрок пока ничего не публиковал в своём профиле.',
                      style: PpText.body(10.8),
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final selectedPost = posts[_selected];

                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 270,
                        child: ListView.separated(
                          itemCount: posts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (_, index) => _mediaTile(
                            posts[index],
                            selected: index == _selected,
                            onTap: () =>
                                setState(() => _selected = index),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _mediaDetail(selectedPost),
                    ],
                  );
                }

                return SizedBox(
                  height: 520,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 310,
                        child: ListView.separated(
                          itemCount: posts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (_, index) => _mediaTile(
                            posts[index],
                            selected: index == _selected,
                            onTap: () =>
                                setState(() => _selected = index),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _mediaDetail(selectedPost)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _mediaTile(
    Map<String, dynamic> post, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final image = _image(post);
    final hasVideo = _video(post).isNotEmpty;

    return Material(
      color: selected ? PpColors.greenSoft : PpColors.soft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    image,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _placeholder(hasVideo),
                  ),
                )
              else
                _placeholder(hasVideo),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PpDot(
                          color: selected
                              ? PpColors.green
                              : PpColors.muted2,
                          size: selected ? 6 : 4.5,
                          glow: selected,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _title(post),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PpText.body(
                              10.6,
                              color: PpColors.text,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_date(post).isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        _date(post),
                        style: PpText.caption(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(bool video) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: PpColors.greenSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        video
            ? Icons.play_circle_outline_rounded
            : Icons.photo_library_outlined,
        size: 21,
        color: PpColors.greenDark,
      ),
    );
  }

  Widget _mediaDetail(Map<String, dynamic> post) {
    final image = _image(post);
    final video = _video(post);
    final body = _body(post);
    final author = _author(post);

    return PpSurface(
      color: PpColors.soft,
      padding: const EdgeInsets.all(13),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              const PpDotCluster(color: PpColors.greenDark),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _title(post),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PpText.title(16),
                ),
              ),
            ],
          ),
          if (author.isNotEmpty || _date(post).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (author.isNotEmpty) author,
                if (_date(post).isNotEmpty) _date(post),
              ].join(' · '),
              style: PpText.caption(),
            ),
          ],
          if (image.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                image,
                width: double.infinity,
                height: 260,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const SizedBox.shrink(),
              ),
            ),
          ],
          if (video.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: PpColors.greenSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    size: 18,
                    color: PpColors.greenDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'В публикации есть видео',
                      style: PpText.body(
                        10.4,
                        color: PpColors.greenDark,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              body,
              style: PpText.body(
                11,
                color: PpColors.text,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
