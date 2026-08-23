import 'package:flutter/material.dart';

import '../export/player_card_preview.dart';
import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

class PlayerCardSection extends StatelessWidget {
  final PlayerProfileSnapshot data;
  final PlayerProfileSession? session;
  final VoidCallback? onEditSchoolProfile;

  const PlayerCardSection({
    super.key,
    required this.data,
    this.session,
    this.onEditSchoolProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(
            children: [
              const PpDot.green(size: 7),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Карточка игрока', style: PpText.title(18)),
                    const SizedBox(height: 3),
                    Text(
                      'Паспорт школы · форма · посещаемость · трекер',
                      style: PpText.body(10.2),
                    ),
                  ],
                ),
              ),
              const PpDotCluster(),
            ],
          ),
          const PpThinDivider(
            margin: EdgeInsets.only(top: 12, bottom: 12),
          ),
          PlayerCardPreview(data: data, session: session),
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          _SchoolPassport(data: data, onEdit: onEditSchoolProfile),
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          _PlayerMediaFeed(data: data),
        ],
      ),
    );
  }
}

class _SchoolPassport extends StatelessWidget {
  final PlayerProfileSnapshot data;
  final VoidCallback? onEdit;

  const _SchoolPassport({required this.data, this.onEdit});

  String _s(dynamic value) => '${value ?? ''}'.trim();

  String _value(List<String> keys) {
    for (final key in keys) {
      final value = _s(data.player[key] ?? data.schoolProfile[key]);
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '—';
  }

  int get _completion {
    const keys = <String>[
      'birth_date',
      'citizenship',
      'city',
      'position',
      'dominant_foot',
      'jersey_number',
      'enrollment_date',
      'player_status',
      'school_name',
      'school_class',
      'parent_name',
      'parent_phone',
      'parent_email',
      'contract_number',
      'medical_clearance_until',
      'equipment_size',
    ];
    final filled = keys.where((key) {
      final value = _s(data.player[key] ?? data.schoolProfile[key]);
      return value.isNotEmpty && value != 'null';
    }).length;
    return (filled / keys.length * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final sections = <_PassportGroup>[
      _PassportGroup(
        'Футбольная школа',
        PpColors.greenDark,
        <_PassportRow>[
          _PassportRow('Дата зачисления', _value(const ['enrollment_date'])),
          _PassportRow('Статус', _value(const ['player_status'])),
          _PassportRow('Основное амплуа', _value(const ['position', 'amplua'])),
          _PassportRow('Доп. амплуа', _value(const ['secondary_position'])),
          _PassportRow('Ведущая нога', _value(const ['dominant_foot'])),
          _PassportRow('ID федерации', _value(const ['federation_id'])),
        ],
      ),
      _PassportGroup(
        'Обучение',
        PpColors.amber,
        <_PassportRow>[
          _PassportRow('Школа', _value(const ['school_name'])),
          _PassportRow('Класс', _value(const ['school_class'])),
          _PassportRow('Смена', _value(const ['school_shift'])),
          _PassportRow('Расписание', _value(const ['education_note'])),
        ],
      ),
      _PassportGroup(
        'Родитель и связь',
        PpColors.green,
        <_PassportRow>[
          _PassportRow('Представитель', _value(const ['parent_name'])),
          _PassportRow('Кем приходится', _value(const ['parent_relation'])),
          _PassportRow('Телефон', _value(const ['parent_phone'])),
          _PassportRow('Email', _value(const ['parent_email'])),
          _PassportRow('Экстренный контакт', _value(const ['emergency_contact'])),
        ],
      ),
      _PassportGroup(
        'Учёт и экипировка',
        PpColors.amber,
        <_PassportRow>[
          _PassportRow('Договор', _value(const ['contract_number'])),
          _PassportRow('Приказ', _value(const ['admission_order'])),
          _PassportRow('Мед. допуск до', _value(const ['medical_clearance_until'])),
          _PassportRow('Размер формы', _value(const ['equipment_size'])),
          _PassportRow('Размер обуви', _value(const ['shoe_size'])),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PpSectionTitle(
          title: 'Паспорт футбольной школы',
          subtitle: 'Анкета заполнена на $_completion%',
          dotColor: PpColors.greenDark,
          trailing: onEdit == null
              ? null
              : PpTextAction(
                  label: 'Заполнить / изменить',
                  onTap: onEdit,
                  dotColor: PpColors.greenDark,
                  emphasized: true,
                ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 820;
            final width = twoColumns
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: sections
                  .map(
                    (section) => SizedBox(
                      width: width,
                      child: _PassportCard(group: section),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _PassportCard extends StatelessWidget {
  final _PassportGroup group;

  const _PassportCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return PpSurface(
      color: PpColors.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PpSectionTitle(title: group.title, dotColor: group.color),
          const SizedBox(height: 7),
          ...group.rows.asMap().entries.map((entry) {
            final row = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      PpDot(color: group.color, size: 5),
                      const SizedBox(width: 8),
                      Expanded(child: Text(row.label, style: PpText.body(10.4))),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          row.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: PpText.body(
                            10.4,
                            color: PpColors.text,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.key != group.rows.length - 1)
                  const PpThinDivider(margin: EdgeInsets.zero),
              ],
            );
          }),
        ],
      ),
    );
  }
}


class _PlayerMediaFeed extends StatefulWidget {
  final PlayerProfileSnapshot data;

  const _PlayerMediaFeed({required this.data});

  @override
  State<_PlayerMediaFeed> createState() => _PlayerMediaFeedState();
}

class _PlayerMediaFeedState extends State<_PlayerMediaFeed> {
  int _selected = 0;

  String _s(dynamic value) => '${value ?? ''}'.trim();

  String _title(Map<String, dynamic> post) {
    final value = _s(post['title']);
    if (value.isNotEmpty) return value;
    final body = _body(post);
    if (body.isNotEmpty) {
      return body.length > 54 ? '${body.substring(0, 54)}…' : body;
    }
    return 'Публикация игрока';
  }

  String _body(Map<String, dynamic> post) =>
      _s(post['body'] ?? post['description'] ?? post['text'] ?? post['caption']);

  String _date(Map<String, dynamic> post) =>
      _s(post['created_at'] ?? post['published_at'] ?? post['date']);

  String _url(dynamic raw) {
    final value = _s(raw);
    if (value.isEmpty || value == 'null') return '';
    if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('data:image/')) {
      return value;
    }
    return 'https://sportotekaapp.ru${value.startsWith('/') ? value : '/$value'}';
  }

  String _image(Map<String, dynamic> post) {
    for (final key in const [
      'image', 'image_url', 'photo', 'photo_url', 'media_url', 'thumbnail',
      'thumbnail_url', 'preview', 'preview_url', 'cover', 'cover_url',
    ]) {
      final value = _url(post[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _video(Map<String, dynamic> post) {
    for (final key in const ['video', 'video_url', 'media_video', 'file_url']) {
      final value = _url(post[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final posts = widget.data.mediaFeed;
    if (_selected >= posts.length) _selected = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const PpDotCluster(color: PpColors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Лента игрока', style: PpText.title(16)),
                  const SizedBox(height: 3),
                  Text(
                    'Публикации, фото и медиа, которые игрок добавляет в свой профиль',
                    style: PpText.body(10.2),
                  ),
                ],
              ),
            ),
            if (posts.isNotEmpty)
              Text('${posts.length}', style: PpText.value(14)),
          ],
        ),
        const SizedBox(height: 10),
        if (posts.isEmpty)
          PpSurface(
            color: PpColors.soft,
            child: Row(
              children: [
                const PpDot(color: PpColors.muted2, size: 6, glow: false),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Игрок пока ничего не публиковал в своём профиле.',
                    style: PpText.body(10.6),
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 780;
              if (!desktop) {
                return Column(
                  children: posts.take(12).map((post) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _mediaListTile(
                        post,
                        selected: false,
                        onTap: () => _showInlinePost(context, post),
                      ),
                    );
                  }).toList(),
                );
              }

              final selectedPost = posts[_selected];
              return SizedBox(
                height: 430,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 300,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: posts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, index) => _mediaListTile(
                          posts[index],
                          selected: index == _selected,
                          onTap: () => setState(() => _selected = index),
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
    );
  }

  Widget _mediaListTile(
    Map<String, dynamic> post, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final image = _image(post);
    final hasVideo = _video(post).isNotEmpty;
    return Material(
      color: selected ? PpColors.greenSoft : PpColors.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
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
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _mediaPlaceholder(hasVideo),
                  ),
                )
              else
                _mediaPlaceholder(hasVideo),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PpDot(
                          color: selected ? PpColors.green : PpColors.muted2,
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
                      Text(_date(post), style: PpText.caption()),
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

  Widget _mediaPlaceholder(bool video) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: PpColors.greenSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        video ? Icons.play_circle_outline_rounded : Icons.notes_rounded,
        size: 20,
        color: PpColors.greenDark,
      ),
    );
  }

  Widget _mediaDetail(Map<String, dynamic> post) {
    final image = _image(post);
    final video = _video(post);
    final body = _body(post);
    return PpSurface(
      color: PpColors.soft,
      padding: const EdgeInsets.all(12),
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
                  style: PpText.title(15),
                ),
              ),
            ],
          ),
          if (_date(post).isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(_date(post), style: PpText.caption()),
          ],
          if (image.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                image,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (video.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: PpColors.greenSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded, size: 18, color: PpColors.greenDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('В публикации есть видео', style: PpText.body(10.4, color: PpColors.greenDark, weight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(body, style: PpText.body(11, color: PpColors.text)),
          ],
        ],
      ),
    );
  }

  void _showInlinePost(BuildContext context, Map<String, dynamic> post) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .74,
        minChildSize: .45,
        maxChildSize: .92,
        expand: false,
        builder: (_, controller) => Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _mediaDetail(post),
        ),
      ),
    );
  }
}

class _PassportGroup {
  final String title;
  final Color color;
  final List<_PassportRow> rows;

  const _PassportGroup(this.title, this.color, this.rows);
}

class _PassportRow {
  final String label;
  final String value;

  const _PassportRow(this.label, this.value);
}
