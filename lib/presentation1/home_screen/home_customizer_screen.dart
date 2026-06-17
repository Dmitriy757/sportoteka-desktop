import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/home_screen/home_screen_design.dart';

class HomeCustomizerScreen extends StatefulWidget {
  final HomeScreenDesign initialDesign;
  final ValueChanged<HomeScreenDesign> onSave;

  const HomeCustomizerScreen({
    super.key,
    required this.initialDesign,
    required this.onSave,
  });

  @override
  State<HomeCustomizerScreen> createState() => _HomeCustomizerScreenState();
}

class _HomeCustomizerScreenState extends State<HomeCustomizerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late HomeScreenDesign _design;

  late TextEditingController _headerTitleController;
  late TextEditingController _headerSubtitleController;
  late TextEditingController _greetingController;
  late TextEditingController _statusController;
  late TextEditingController _headerImageController;

  @override
  void initState() {
    super.initState();
    _design = _normalizeCustomizerDesign(widget.initialDesign);
    _tabController = TabController(length: 6, vsync: this);

    _headerTitleController =
        TextEditingController(text: _design.customHeaderTitle);
    _headerSubtitleController =
        TextEditingController(text: _design.customHeaderSubtitle);
    _greetingController =
        TextEditingController(text: _design.greetingText ?? '');
    _statusController = TextEditingController(text: _design.statusText ?? '');
    _headerImageController =
        TextEditingController(text: _design.headerImageUrl ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerTitleController.dispose();
    _headerSubtitleController.dispose();
    _greetingController.dispose();
    _statusController.dispose();
    _headerImageController.dispose();
    super.dispose();
  }

  HomeScreenDesign _normalizeCustomizerDesign(HomeScreenDesign design) {
    HomeSectionConfig normalizeSection(HomeSectionConfig config) {
      double minHeight;
      double minWidth;

      switch (config.type) {
        case HomeSectionType.ringBanner:
          minHeight = 180;
          minWidth = 300;
          break;
        case HomeSectionType.reels:
          minHeight = 320;
          minWidth = 210;
          break;
        case HomeSectionType.promo:
          minHeight = 170;
          minWidth = 300;
          break;
        case HomeSectionType.innovations:
          minHeight = 180;
          minWidth = 220;
          break;
        case HomeSectionType.tips:
          minHeight = 190;
          minWidth = 220;
          break;
        case HomeSectionType.events:
          minHeight = 240;
          minWidth = 230;
          break;
        case HomeSectionType.venues:
          minHeight = 230;
          minWidth = 230;
          break;
        case HomeSectionType.clubs:
          minHeight = 230;
          minWidth = 230;
          break;
        case HomeSectionType.tickets:
          minHeight = 220;
          minWidth = 230;
          break;
        case HomeSectionType.posts:
          minHeight = 250;
          minWidth = 240;
          break;
      }

      return config.copyWith(
        cardHeight: config.cardHeight < minHeight ? minHeight : config.cardHeight,
        cardWidth: config.cardWidth < minWidth ? minWidth : config.cardWidth,
        itemLimit: config.itemLimit < 1 ? 1 : config.itemLimit,
        gridColumns: config.gridColumns < 1 ? 1 : config.gridColumns,
        aspectRatio: config.aspectRatio <= 0 ? 1.0 : config.aspectRatio,
        topSpacing: config.topSpacing < 0 ? 0 : config.topSpacing,
        bottomSpacing: config.bottomSpacing < 0 ? 0 : config.bottomSpacing,
      );
    }

    return design.copyWith(
      sections: design.sections.map(normalizeSection).toList(),
    );
  }

  void _update(HomeScreenDesign design) {
    setState(() {
      _design = _normalizeCustomizerDesign(design);
    });
  }

  void _applyPreset(HomeScreenDesign preset) {
    final safePreset = _normalizeCustomizerDesign(preset);
    _update(safePreset);
    _headerTitleController.text = safePreset.customHeaderTitle;
    _headerSubtitleController.text = safePreset.customHeaderSubtitle;
    _greetingController.text = safePreset.greetingText ?? '';
    _statusController.text = safePreset.statusText ?? '';
    _headerImageController.text = safePreset.headerImageUrl ?? '';
  }

  String _sectionLabel(HomeSectionType type) {
    switch (type) {
      case HomeSectionType.ringBanner:
        return 'Sportoteka Ring';
      case HomeSectionType.reels:
        return 'Видео';
      case HomeSectionType.promo:
        return 'Sportoteka PRO';
      case HomeSectionType.innovations:
        return 'AR функции';
      case HomeSectionType.tips:
        return 'Советы';
      case HomeSectionType.events:
        return 'Мероприятия';
      case HomeSectionType.venues:
        return 'Площадки';
      case HomeSectionType.clubs:
        return 'Клубы';
      case HomeSectionType.tickets:
        return 'Билеты';
      case HomeSectionType.posts:
        return 'Новости';
    }
  }

  IconData _sectionIcon(HomeSectionType type) {
    switch (type) {
      case HomeSectionType.ringBanner:
        return Icons.ring_volume_rounded;
      case HomeSectionType.reels:
        return Icons.play_circle_fill_rounded;
      case HomeSectionType.promo:
        return Icons.workspace_premium_rounded;
      case HomeSectionType.innovations:
        return Icons.auto_awesome_rounded;
      case HomeSectionType.tips:
        return Icons.lightbulb_rounded;
      case HomeSectionType.events:
        return Icons.event_rounded;
      case HomeSectionType.venues:
        return Icons.location_on_rounded;
      case HomeSectionType.clubs:
        return Icons.groups_rounded;
      case HomeSectionType.tickets:
        return Icons.confirmation_number_rounded;
      case HomeSectionType.posts:
        return Icons.forum_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _design.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _design.primaryColor,
        foregroundColor: Colors.white,
        title: const Text(
          'Редактор главной',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSave(_normalizeCustomizerDesign(_design));
              Navigator.pop(context);
            },
            child: const Text(
              'Сохранить',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: const [
            Tab(text: 'Превью'),
            Tab(text: 'Тема'),
            Tab(text: 'Хедер'),
            Tab(text: 'Блоки'),
            Tab(text: 'Карточки'),
            Tab(text: 'Поведение'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPreviewTab(),
          _buildThemeTab(),
          _buildHeaderTab(),
          _buildSectionsTab(),
          _buildCardsTab(),
          _buildBehaviorTab(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: _design.surfaceColor,
            border: Border(top: BorderSide(color: _design.borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _applyPreset(HomeScreenDesign.defaults());
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Сбросить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onSave(_normalizeCustomizerDesign(_design));
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _design.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Применить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Живой предпросмотр',
          icon: Icons.visibility_rounded,
          child: _buildPhonePreview(),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Пресеты',
          icon: Icons.auto_fix_high_rounded,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _presetChip('Sportoteka Classic', () {
                _applyPreset(HomeScreenDesign.defaults());
              }),
              _presetChip('Glass Mint', () {
                _applyPreset(HomeScreenDesign.glassMint());
              }),
              _presetChip('Dark Arena', () {
                _applyPreset(HomeScreenDesign.darkArena());
              }),
              _presetChip('White Premium', () {
                _applyPreset(HomeScreenDesign.whitePremium());
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Основные цвета',
          icon: Icons.palette_rounded,
          child: Column(
            children: [
              _colorPickerRow(
                label: 'Фон страницы',
                value: _design.backgroundColor,
                options: _softBackgrounds,
                onChanged: (c) => _update(_design.copyWith(backgroundColor: c)),
              ),
              _colorPickerRow(
                label: 'Поверхность',
                value: _design.surfaceColor,
                options: _surfaceColors,
                onChanged: (c) => _update(_design.copyWith(surfaceColor: c)),
              ),
              _colorPickerRow(
                label: 'Карточки',
                value: _design.cardColor,
                options: _surfaceColors,
                onChanged: (c) => _update(_design.copyWith(cardColor: c)),
              ),
              _colorPickerRow(
                label: 'Основной акцент',
                value: _design.primaryColor,
                options: _accentColors,
                onChanged: (c) => _update(_design.copyWith(primaryColor: c)),
              ),
              _colorPickerRow(
                label: 'Вторичный акцент',
                value: _design.secondaryColor,
                options: _accentColors,
                onChanged: (c) => _update(_design.copyWith(secondaryColor: c)),
              ),
              _colorPickerRow(
                label: 'Текст',
                value: _design.textColor,
                options: _textColors,
                onChanged: (c) => _update(_design.copyWith(textColor: c)),
              ),
              _colorPickerRow(
                label: 'Приглушённый текст',
                value: _design.mutedTextColor,
                options: _textColors,
                onChanged: (c) => _update(_design.copyWith(mutedTextColor: c)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Типографика',
          icon: Icons.text_fields_rounded,
          child: Column(
            children: [
              _slider(
                label: 'Размер заголовка хедера',
                value: _design.headerTitleSize,
                min: 18,
                max: 40,
                onChanged: (v) => _update(_design.copyWith(headerTitleSize: v)),
              ),
              _slider(
                label: 'Размер подзаголовка хедера',
                value: _design.headerSubtitleSize,
                min: 10,
                max: 24,
                onChanged: (v) =>
                    _update(_design.copyWith(headerSubtitleSize: v)),
              ),
              _slider(
                label: 'Размер заголовков секций',
                value: _design.sectionTitleSize,
                min: 12,
                max: 28,
                onChanged: (v) =>
                    _update(_design.copyWith(sectionTitleSize: v)),
              ),
              _slider(
                label: 'Размер подзаголовков секций',
                value: _design.sectionSubtitleSize,
                min: 10,
                max: 20,
                onChanged: (v) =>
                    _update(_design.copyWith(sectionSubtitleSize: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Шрифты',
          icon: Icons.format_size_rounded,
          child: Column(
            children: [
              _slider(
                label: 'Общий размер текста',
                value: _design.textScale,
                min: 0.8,
                max: 1.6,
                onChanged: (v) => _update(_design.copyWith(textScale: v)),
              ),
              _slider(
                label: 'Размер заголовков карточек',
                value: _design.cardTitleSize,
                min: 12,
                max: 24,
                onChanged: (v) => _update(_design.copyWith(cardTitleSize: v)),
              ),
              _slider(
                label: 'Размер основного текста',
                value: _design.bodyTextSize,
                min: 11,
                max: 20,
                onChanged: (v) => _update(_design.copyWith(bodyTextSize: v)),
              ),
              _slider(
                label: 'Размер мелкого текста',
                value: _design.smallTextSize,
                min: 9,
                max: 16,
                onChanged: (v) => _update(_design.copyWith(smallTextSize: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Пресеты интерфейса',
          icon: Icons.style_rounded,
          child: Column(
            children: [
              _enumSelector<HomeHeaderStyle>(
                title: 'Стиль хедера',
                current: _design.headerStyle,
                values: HomeHeaderStyle.values,
                labelBuilder: (v) {
                  switch (v) {
                    case HomeHeaderStyle.gradient:
                      return 'Градиент';
                    case HomeHeaderStyle.glass:
                      return 'Стекло';
                    case HomeHeaderStyle.solid:
                      return 'Сплошной';
                    case HomeHeaderStyle.premium:
                      return 'Премиум';
                  }
                },
                onChanged: (v) => _update(_design.copyWith(headerStyle: v)),
              ),
              const SizedBox(height: 12),
              _enumSelector<HomeCardStyle>(
                title: 'Стиль карточек',
                current: _design.cardStyle,
                values: HomeCardStyle.values,
                labelBuilder: (v) {
                  switch (v) {
                    case HomeCardStyle.soft:
                      return 'Мягкий';
                    case HomeCardStyle.glass:
                      return 'Стекло';
                    case HomeCardStyle.outlined:
                      return 'Контурный';
                    case HomeCardStyle.elevated:
                      return 'Объёмный';
                  }
                },
                onChanged: (v) => _update(_design.copyWith(cardStyle: v)),
              ),
              const SizedBox(height: 12),
              _enumSelector<HomeAnimationPreset>(
                title: 'Анимация',
                current: _design.animationPreset,
                values: HomeAnimationPreset.values,
                labelBuilder: (v) {
                  switch (v) {
                    case HomeAnimationPreset.none:
                      return 'Без анимации';
                    case HomeAnimationPreset.soft:
                      return 'Плавная';
                    case HomeAnimationPreset.dynamic:
                      return 'Динамичная';
                    case HomeAnimationPreset.premium:
                      return 'Премиум';
                  }
                },
                onChanged: (v) =>
                    _update(_design.copyWith(animationPreset: v)),
              ),
              const SizedBox(height: 12),
              _enumSelector<HomeModePreset>(
                title: 'Режим',
                current: _design.modePreset,
                values: HomeModePreset.values,
                labelBuilder: (v) {
                  switch (v) {
                    case HomeModePreset.athlete:
                      return 'Спортсмен';
                    case HomeModePreset.coach:
                      return 'Тренер';
                    case HomeModePreset.parent:
                      return 'Родитель';
                    case HomeModePreset.club:
                      return 'Клуб';
                    case HomeModePreset.media:
                      return 'Медиа';
                    case HomeModePreset.custom:
                      return 'Свой';
                  }
                },
                onChanged: (v) => _update(_design.copyWith(modePreset: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Тексты хедера',
          icon: Icons.title_rounded,
          child: Column(
            children: [
              TextField(
                controller: _headerTitleController,
                decoration: const InputDecoration(
                  labelText: 'Заголовок',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    _update(_design.copyWith(customHeaderTitle: v)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _headerSubtitleController,
                decoration: const InputDecoration(
                  labelText: 'Подзаголовок',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    _update(_design.copyWith(customHeaderSubtitle: v)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _greetingController,
                decoration: const InputDecoration(
                  labelText: 'Текст приветствия',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _update(_design.copyWith(
                  greetingText: v.trim().isEmpty ? null : v,
                )),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _statusController,
                decoration: const InputDecoration(
                  labelText: 'Текст статуса',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _update(_design.copyWith(
                  statusText: v.trim().isEmpty ? null : v,
                )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Структура хедера',
          icon: Icons.dashboard_customize_rounded,
          child: Column(
            children: [
              SwitchListTile(
                value: _design.showHeaderSubtitle,
                onChanged: (v) =>
                    _update(_design.copyWith(showHeaderSubtitle: v)),
                title: const Text('Показывать подзаголовок'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.showSearchInHeader,
                onChanged: (v) =>
                    _update(_design.copyWith(showSearchInHeader: v)),
                title: const Text('Показывать поиск в хедере'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.showHeaderQuickActions,
                onChanged: (v) =>
                    _update(_design.copyWith(showHeaderQuickActions: v)),
                title: const Text('Показывать быстрые действия'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.showQuickActionsLabels,
                onChanged: (v) =>
                    _update(_design.copyWith(showQuickActionsLabels: v)),
                title: const Text('Подписи быстрых действий'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.showHeaderGreeting,
                onChanged: (v) =>
                    _update(_design.copyWith(showHeaderGreeting: v)),
                title: const Text('Показывать приветствие'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.showHeaderAvatar,
                onChanged: (v) =>
                    _update(_design.copyWith(showHeaderAvatar: v)),
                title: const Text('Показывать аватар'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.centerHeaderContent,
                onChanged: (v) =>
                    _update(_design.copyWith(centerHeaderContent: v)),
                title: const Text('Центрировать контент'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.showHeaderBottomFade,
                onChanged: (v) =>
                    _update(_design.copyWith(showHeaderBottomFade: v)),
                title: const Text('Показывать нижнее затемнение'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Фон хедера',
          icon: Icons.image_rounded,
          child: Column(
            children: [
              SwitchListTile(
                value: _design.useHeaderImage,
                onChanged: (v) =>
                    _update(_design.copyWith(useHeaderImage: v)),
                title: const Text('Использовать изображение'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _headerImageController,
                decoration: const InputDecoration(
                  labelText: 'Ссылка на изображение хедера',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _update(_design.copyWith(
                  headerImageUrl: v.trim().isEmpty ? null : v,
                )),
              ),
              const SizedBox(height: 12),
              _slider(
                label: 'Прозрачность картинки',
                value: _design.headerImageOpacity,
                min: 0,
                max: 1,
                onChanged: (v) =>
                    _update(_design.copyWith(headerImageOpacity: v)),
              ),
              _slider(
                label: 'Прозрачность затемнения',
                value: _design.headerOverlayOpacity,
                min: 0,
                max: 1,
                onChanged: (v) =>
                    _update(_design.copyWith(headerOverlayOpacity: v)),
              ),
              _colorPickerRow(
                label: 'Начальный цвет хедера',
                value: _design.headerStartColor,
                options: _accentColors,
                onChanged: (c) =>
                    _update(_design.copyWith(headerStartColor: c)),
              ),
              _colorPickerRow(
                label: 'Средний цвет хедера',
                value: _design.headerMidColor,
                options: _accentColors,
                onChanged: (c) =>
                    _update(_design.copyWith(headerMidColor: c)),
              ),
              _colorPickerRow(
                label: 'Конечный цвет хедера',
                value: _design.headerEndColor,
                options: _accentColors,
                onChanged: (c) =>
                    _update(_design.copyWith(headerEndColor: c)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Быстрые действия',
          icon: Icons.bolt_rounded,
          child: Column(
            children: [
              _enumSelector<HomeQuickActionShape>(
                title: 'Форма кнопок',
                current: _design.quickActionShape,
                values: HomeQuickActionShape.values,
                labelBuilder: (v) {
                  switch (v) {
                    case HomeQuickActionShape.circle:
                      return 'Круг';
                    case HomeQuickActionShape.roundedSquare:
                      return 'Скруглённый квадрат';
                    case HomeQuickActionShape.softSquare:
                      return 'Мягкий квадрат';
                    case HomeQuickActionShape.pill:
                      return 'Капсула';
                  }
                },
                onChanged: (v) =>
                    _update(_design.copyWith(quickActionShape: v)),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _design.quickActionUseGradient,
                onChanged: (v) =>
                    _update(_design.copyWith(quickActionUseGradient: v)),
                title: const Text('Градиент у быстрых действий'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.quickActionOutlined,
                onChanged: (v) =>
                    _update(_design.copyWith(quickActionOutlined: v)),
                title: const Text('Контурный стиль'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              _slider(
                label: 'Размер кнопки',
                value: _design.quickActionBubbleSize,
                min: 44,
                max: 82,
                onChanged: (v) =>
                    _update(_design.copyWith(quickActionBubbleSize: v)),
              ),
              _slider(
                label: 'Размер иконки',
                value: _design.quickActionIconSize,
                min: 18,
                max: 36,
                onChanged: (v) =>
                    _update(_design.copyWith(quickActionIconSize: v)),
              ),
              _slider(
                label: 'Радиус контейнера',
                value: _design.quickActionsCornerRadius,
                min: 10,
                max: 36,
                onChanged: (v) =>
                    _update(_design.copyWith(quickActionsCornerRadius: v)),
              ),
              _slider(
                label: 'Толщина рамки',
                value: _design.quickActionBorderWidth,
                min: 0,
                max: 4,
                onChanged: (v) =>
                    _update(_design.copyWith(quickActionBorderWidth: v)),
              ),
              _colorPickerRow(
                label: 'Фон быстрых действий',
                value: _design.quickActionBackgroundColor,
                options: _accentColors,
                onChanged: (c) => _update(
                  _design.copyWith(quickActionBackgroundColor: c),
                ),
              ),
              _colorPickerRow(
                label: 'Цвет иконок',
                value: _design.quickActionIconColor,
                options: _accentColors,
                onChanged: (c) =>
                    _update(_design.copyWith(quickActionIconColor: c)),
              ),
              _colorPickerRow(
                label: 'Внутренний цвет',
                value: _design.quickActionInnerColor,
                options: const [
                  Colors.white,
                  Colors.black,
                  Color(0xFFF3F4F6),
                  Color(0xFFECFDF5),
                ],
                onChanged: (c) =>
                    _update(_design.copyWith(quickActionInnerColor: c)),
              ),
            ],
          ),
        ),
      ],
    );
  }

 Widget _buildSectionsTab() {
  final sections = [..._design.sections];

  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _sectionCard(
        title: 'Порядок блоков',
        icon: Icons.reorder_rounded,
        child: ReorderableListView.builder(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sections.length,
          onReorder: (oldIndex, newIndex) {
            final list = [...sections];
            if (newIndex > oldIndex) newIndex -= 1;
            final item = list.removeAt(oldIndex);
            list.insert(newIndex, item);
            _update(_design.copyWith(sections: list));
          },
          itemBuilder: (context, index) {
            final item = sections[index];

            return Container(
              key: ValueKey('${item.type.name}_$index'),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _design.surfaceColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _design.borderColor),
              ),
              child: ExpansionTile(
                maintainState: true,
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Icon(
                  _sectionIcon(item.type),
                  color: _design.primaryColor,
                ),
                title: Text(
                  item.customTitle?.trim().isNotEmpty == true
                      ? item.customTitle!
                      : _sectionLabel(item.type),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  item.visible ? 'Видимый блок' : 'Скрытый блок',
                ),
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle_rounded),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  SwitchListTile(
                    value: item.visible,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(visible: v);
                      _update(_design.copyWith(sections: list));
                    },
                    title: const Text('Показывать блок'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: item.pinned,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(pinned: v);
                      _update(_design.copyWith(sections: list));
                    },
                    title: const Text('Закрепить'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: item.showSubtitle,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(showSubtitle: v);
                      _update(_design.copyWith(sections: list));
                    },
                    title: const Text('Показывать подзаголовок'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: item.showIcon,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(showIcon: v);
                      _update(_design.copyWith(sections: list));
                    },
                    title: const Text('Показывать иконку'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: item.showSeeAll,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(showSeeAll: v);
                      _update(_design.copyWith(sections: list));
                    },
                    title: const Text('Показывать кнопку "Все"'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: item.allowCollapse,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(allowCollapse: v);
                      _update(_design.copyWith(sections: list));
                    },
                    title: const Text('Разрешить сворачивание'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: item.initiallyCollapsed,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] =
                          list[index].copyWith(initiallyCollapsed: v);
                      _update(_design.copyWith(sections: list));
                    },
                    title: const Text('Изначально свернуть'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: item.highlightAsNew,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(highlightAsNew: v);
                      _update(_design.copyWith(sections: list));
                    },
                    title: const Text('Подсветить как новое'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: item.showBadge,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(showBadge: v);
                      _update(_design.copyWith(sections: list));
                    },
                    title: const Text('Показывать бейдж'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: item.customTitle ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Свой заголовок',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(
                        customTitle: v.trim().isEmpty ? null : v,
                        clearCustomTitle: v.trim().isEmpty,
                      );
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: item.customSubtitle ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Свой подзаголовок',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(
                        customSubtitle: v.trim().isEmpty ? null : v,
                        clearCustomSubtitle: v.trim().isEmpty,
                      );
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: item.badgeText ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Текст бейджа',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(
                        badgeText: v.trim().isEmpty ? null : v,
                        clearBadgeText: v.trim().isEmpty,
                      );
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                  const SizedBox(height: 12),
                  _enumSelector<HomeSectionLayout>(
                    title: 'Тип расположения',
                    current: item.layout,
                    values: HomeSectionLayout.values,
                    labelBuilder: (v) {
                      switch (v) {
                        case HomeSectionLayout.horizontal:
                          return 'Горизонтально';
                        case HomeSectionLayout.grid:
                          return 'Сетка';
                        case HomeSectionLayout.compactList:
                          return 'Компактно';
                        case HomeSectionLayout.hero:
                          return 'Главный баннер';
                      }
                    },
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(layout: v);
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                  _slider(
                    label: 'Лимит элементов',
                    value: item.itemLimit.toDouble(),
                    min: 2,
                    max: 12,
                    divisions: 10,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(
                        itemLimit: v.round(),
                      );
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                  _slider(
                    label: 'Ширина карточки',
                    value: item.cardWidth.clamp(200.0, 380.0),
                    min: 200,
                    max: 380,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(cardWidth: v);
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                  _slider(
                    label: 'Высота карточки',
                    value: item.cardHeight.clamp(180.0, 420.0),
                    min: 180,
                    max: 420,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(cardHeight: v);
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                  _slider(
                    label: 'Колонки сетки',
                    value: item.gridColumns.toDouble().clamp(1.0, 4.0),
                    min: 1,
                    max: 4,
                    divisions: 3,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(
                        gridColumns: v.round(),
                      );
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                  _slider(
                    label: 'Соотношение сторон',
                    value: item.aspectRatio.clamp(0.7, 2.2),
                    min: 0.7,
                    max: 2.2,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(aspectRatio: v);
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                  _slider(
                    label: 'Верхний отступ секции',
                    value: item.topSpacing.clamp(0.0, 40.0),
                    min: 0,
                    max: 40,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(topSpacing: v);
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                  _slider(
                    label: 'Нижний отступ секции',
                    value: item.bottomSpacing.clamp(0.0, 40.0),
                    min: 0,
                    max: 40,
                    onChanged: (v) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(bottomSpacing: v);
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                  _colorPickerRow(
                    label: 'Акцент секции',
                    value: item.accentOverride ?? _design.primaryColor,
                    options: _accentColors,
                    onChanged: (c) {
                      final list = [...sections];
                      list[index] = list[index].copyWith(
                        accentOverride: c,
                      );
                      _update(_design.copyWith(sections: list));
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      _sectionCard(
        title: 'Общие настройки блоков',
        icon: Icons.widgets_rounded,
        child: Column(
          children: [
            SwitchListTile(
              value: _design.showPromoBanner,
              onChanged: (v) =>
                  _update(_design.copyWith(showPromoBanner: v)),
              title: const Text('Показывать PRO баннер'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _design.showSectionIcons,
              onChanged: (v) =>
                  _update(_design.copyWith(showSectionIcons: v)),
              title: const Text('Показывать иконки секций'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _design.showSectionBackgrounds,
              onChanged: (v) =>
                  _update(_design.copyWith(showSectionBackgrounds: v)),
              title: const Text('Фон у заголовков секций'),
              contentPadding: EdgeInsets.zero,
            ),
            _slider(
              label: 'Отступ между секциями',
              value: _design.sectionGap,
              min: 8,
              max: 40,
              onChanged: (v) => _update(_design.copyWith(sectionGap: v)),
            ),
            _slider(
              label: 'Боковые поля страницы',
              value: _design.pageHorizontalPadding,
              min: 8,
              max: 32,
              onChanged: (v) =>
                  _update(_design.copyWith(pageHorizontalPadding: v)),
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildCardsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Геометрия карточек',
          icon: Icons.crop_rounded,
          child: Column(
            children: [
              _slider(
                label: 'Радиус карточек',
                value: _design.cardRadius,
                min: 8,
                max: 40,
                onChanged: (v) => _update(_design.copyWith(cardRadius: v)),
              ),
              _slider(
                label: 'Радиус баннеров',
                value: _design.bannerRadius,
                min: 8,
                max: 40,
                onChanged: (v) => _update(_design.copyWith(bannerRadius: v)),
              ),
              _slider(
                label: 'Толщина рамки',
                value: _design.borderWidth,
                min: 0,
                max: 3,
                onChanged: (v) => _update(_design.copyWith(borderWidth: v)),
              ),
              _slider(
                label: 'Внутренний отступ',
                value: _design.cardContentPadding,
                min: 8,
                max: 28,
                onChanged: (v) =>
                    _update(_design.copyWith(cardContentPadding: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Тени и стиль',
          icon: Icons.layers_rounded,
          child: Column(
            children: [
              _slider(
                label: 'Прозрачность тени',
                value: _design.shadowOpacity,
                min: 0,
                max: 0.30,
                onChanged: (v) => _update(_design.copyWith(shadowOpacity: v)),
              ),
              _slider(
                label: 'Размытие тени',
                value: _design.shadowBlur,
                min: 0,
                max: 40,
                onChanged: (v) => _update(_design.copyWith(shadowBlur: v)),
              ),
              _slider(
                label: 'Прозрачность фона карточки',
                value: _design.cardBackgroundOpacity,
                min: 0.2,
                max: 1,
                onChanged: (v) =>
                    _update(_design.copyWith(cardBackgroundOpacity: v)),
              ),
              _slider(
                label: 'Прозрачность рамки',
                value: _design.cardBorderOpacity,
                min: 0,
                max: 1,
                onChanged: (v) =>
                    _update(_design.copyWith(cardBorderOpacity: v)),
              ),
              SwitchListTile(
                value: _design.useRoundedBanners,
                onChanged: (v) =>
                    _update(_design.copyWith(useRoundedBanners: v)),
                title: const Text('Сильно скруглённые баннеры'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.useFloatingCards,
                onChanged: (v) =>
                    _update(_design.copyWith(useFloatingCards: v)),
                title: const Text('Плавающие карточки'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.useGradientCards,
                onChanged: (v) =>
                    _update(_design.copyWith(useGradientCards: v)),
                title: const Text('Градиент внутри карточек'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.cardUseGradientBorder,
                onChanged: (v) =>
                    _update(_design.copyWith(cardUseGradientBorder: v)),
                title: const Text('Градиентная рамка'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.cardShowTopAccentLine,
                onChanged: (v) =>
                    _update(_design.copyWith(cardShowTopAccentLine: v)),
                title: const Text('Верхняя акцентная линия'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBehaviorTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Поведение',
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              SwitchListTile(
                value: _design.enableAnimatedSectionEntrance,
                onChanged: (v) => _update(
                  _design.copyWith(enableAnimatedSectionEntrance: v),
                ),
                title: const Text('Анимация появления секций'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.enableParallaxHeader,
                onChanged: (v) =>
                    _update(_design.copyWith(enableParallaxHeader: v)),
                title: const Text('Параллакс хедера'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.enablePullToRefresh,
                onChanged: (v) =>
                    _update(_design.copyWith(enablePullToRefresh: v)),
                title: const Text('Обновление свайпом вниз'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.showScrollToTopButton,
                onChanged: (v) =>
                    _update(_design.copyWith(showScrollToTopButton: v)),
                title: const Text('Кнопка прокрутки наверх'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.rememberCollapsedSections,
                onChanged: (v) =>
                    _update(_design.copyWith(rememberCollapsedSections: v)),
                title: const Text('Запоминать свёрнутые секции'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.autoHidePromoAfterClose,
                onChanged: (v) =>
                    _update(_design.copyWith(autoHidePromoAfterClose: v)),
                title: const Text('Автоскрытие промо-баннера'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.enableHapticFeedback,
                onChanged: (v) =>
                    _update(_design.copyWith(enableHapticFeedback: v)),
                title: const Text('Тактильная отдача'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.reduceMotion,
                onChanged: (v) => _update(_design.copyWith(reduceMotion: v)),
                title: const Text('Уменьшить анимации'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.compactMode,
                onChanged: (v) => _update(_design.copyWith(compactMode: v)),
                title: const Text('Компактный режим'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _design.denseMode,
                onChanged: (v) => _update(_design.copyWith(denseMode: v)),
                title: const Text('Плотный режим'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhonePreview() {
    final radius = BorderRadius.circular(_design.bannerRadius);

    return Container(
      height: 620,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(36),
      ),
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: _design.backgroundColor,
          child: Column(
            children: [
              Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _design.headerStartColor,
                      _design.headerMidColor,
                      _design.headerEndColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    if (_design.useHeaderImage &&
                        (_design.headerImageUrl?.isNotEmpty ?? false))
                      Positioned.fill(
                        child: Opacity(
                          opacity: _design.headerImageOpacity,
                          child: Container(
                            color: Colors.white.withOpacity(0.08),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_rounded,
                              size: 80,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: _design.centerHeaderContent
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            _design.customHeaderTitle,
                            textAlign: _design.centerHeaderContent
                                ? TextAlign.center
                                : TextAlign.left,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _design.headerTitleSize.clamp(18, 34),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (_design.showHeaderSubtitle) ...[
                            const SizedBox(height: 6),
                            Text(
                              _design.customHeaderSubtitle,
                              textAlign: _design.centerHeaderContent
                                  ? TextAlign.center
                                  : TextAlign.left,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize:
                                    _design.headerSubtitleSize.clamp(10, 18),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (_design.showHeaderGreeting &&
                              (_design.greetingText?.isNotEmpty ?? false)) ...[
                            const SizedBox(height: 8),
                            Text(
                              _design.greetingText!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (_design.showHeaderQuickActions)
                            Expanded(
                              child: _previewGlassPanel(
                                radius: _design.quickActionsCornerRadius,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Быстрые действия',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: List.generate(4, (index) {
                                        return Column(
                                          children: [
                                            Container(
                                              width: _design.quickActionBubbleSize
                                                  .clamp(40, 66),
                                              height: _design
                                                  .quickActionBubbleSize
                                                  .clamp(40, 66),
                                              decoration: BoxDecoration(
                                                shape: _design.quickActionShape ==
                                                        HomeQuickActionShape.circle
                                                    ? BoxShape.circle
                                                    : BoxShape.rectangle,
                                                borderRadius:
                                                    _quickActionPreviewRadius(),
                                                color: _design
                                                    .quickActionBackgroundColor,
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: (_design
                                                              .quickActionBubbleSize -
                                                          10)
                                                      .clamp(28, 60),
                                                  height: (_design
                                                              .quickActionBubbleSize -
                                                          10)
                                                      .clamp(28, 60),
                                                  decoration: BoxDecoration(
                                                    color: _design
                                                        .quickActionInnerColor,
                                                    shape: _design.quickActionShape ==
                                                            HomeQuickActionShape
                                                                .circle
                                                        ? BoxShape.circle
                                                        : BoxShape.rectangle,
                                                    borderRadius:
                                                        _quickActionPreviewRadius(
                                                      inner: true,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    [
                                                      Icons.ondemand_video_rounded,
                                                      Icons.event_available_rounded,
                                                      Icons.calendar_today_rounded,
                                                      Icons.play_circle_fill_rounded,
                                                    ][index],
                                                    color:
                                                        _design.quickActionIconColor,
                                                    size: _design
                                                        .quickActionIconSize,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_design.showQuickActionsLabels)
                                              const SizedBox(height: 8),
                                            if (_design.showQuickActionsLabels)
                                              const Text(
                                                'Действие',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    _design.pageHorizontalPadding.clamp(8, 28),
                    14,
                    _design.pageHorizontalPadding.clamp(8, 28),
                    16,
                  ),
                  children: [
                    _previewBanner(radius),
                    SizedBox(height: _design.sectionGap.clamp(8, 36)),
                    ..._design.sections
                        .where((e) => e.visible)
                        .take(4)
                        .map((e) => Padding(
                              padding: EdgeInsets.only(
                                bottom: _design.sectionGap.clamp(8, 36),
                              ),
                              child: _previewSection(e),
                            )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BorderRadius? _quickActionPreviewRadius({bool inner = false}) {
    switch (_design.quickActionShape) {
      case HomeQuickActionShape.circle:
        return null;
      case HomeQuickActionShape.roundedSquare:
        return BorderRadius.circular(inner ? 18 : 20);
      case HomeQuickActionShape.softSquare:
        return BorderRadius.circular(inner ? 20 : 24);
      case HomeQuickActionShape.pill:
        return BorderRadius.circular(999);
    }
  }

  Widget _previewBanner(BorderRadius radius) {
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _design.primaryColor,
              _design.secondaryColor,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const Positioned(
              left: 16,
              top: 18,
              child: Text(
                'Баннер Sportoteka',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewSection(HomeSectionConfig section) {
    final title = section.customTitle?.trim().isNotEmpty == true
        ? section.customTitle!
        : _sectionLabel(section.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_design.showSectionIcons && section.showIcon)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _effectiveSectionAccent(section).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _sectionIcon(section.type),
                  size: 18,
                  color: _effectiveSectionAccent(section),
                ),
              ),
            if (_design.showSectionIcons && section.showIcon)
              const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: _design.sectionTitleSize.clamp(14, 24),
                  fontWeight: FontWeight.w800,
                  color: _design.textColor,
                ),
              ),
            ),
            if (section.showBadge && (section.badgeText?.isNotEmpty ?? false))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (section.badgeColor ?? _design.primaryColor)
                      .withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  section.badgeText!,
                  style: TextStyle(
                    color: section.badgeColor ?? _design.primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        if (section.showSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            section.customSubtitle?.trim().isNotEmpty == true
                ? section.customSubtitle!
                : 'Предпросмотр блока',
            style: TextStyle(
              fontSize: _design.sectionSubtitleSize.clamp(10, 16),
              color: _design.mutedTextColor,
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: (section.cardHeight * 0.58).clamp(120.0, 220.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, i) => Container(
              width: section.layout == HomeSectionLayout.hero
                  ? section.cardWidth.clamp(220.0, 320.0)
                  : section.cardWidth.clamp(160.0, 280.0),
              decoration: _previewCardDecoration(section),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_design.cardShowTopAccentLine)
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _effectiveSectionAccent(section),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  if (_design.cardShowTopAccentLine)
                    const SizedBox(height: 8),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color:
                          _effectiveSectionAccent(section).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 10,
                    width: 90,
                    decoration: BoxDecoration(
                      color: _design.textColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    width: 120,
                    decoration: BoxDecoration(
                      color: _design.textColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: 3,
          ),
        ),
      ],
    );
  }
  

 BoxDecoration _previewCardDecoration(HomeSectionConfig section) {
  final borderColor =
      _design.borderColor.withOpacity(_design.cardBorderOpacity);

  switch (_design.cardStyle) {
    case HomeCardStyle.glass:
      return BoxDecoration(
        color: _design.cardColor.withOpacity(
          0.65 * _design.cardBackgroundOpacity,
        ),
        borderRadius: BorderRadius.circular(_design.cardRadius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_design.shadowOpacity),
            blurRadius: _design.shadowBlur,
            offset: const Offset(0, 8),
          ),
        ],
      );

    case HomeCardStyle.outlined:
      return BoxDecoration(
        color: _design.cardColor.withOpacity(_design.cardBackgroundOpacity),
        borderRadius: BorderRadius.circular(_design.cardRadius),
        border: Border.all(
          color: _effectiveSectionAccent(section),
          width: 1.2,
        ),
      );

    case HomeCardStyle.elevated:
      return BoxDecoration(
        gradient: _design.useGradientCards
            ? LinearGradient(
                colors: [
                  _design.cardColor,
                  _effectiveSectionAccent(section).withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: _design.useGradientCards
            ? null
            : _design.cardColor.withOpacity(_design.cardBackgroundOpacity),
        borderRadius: BorderRadius.circular(_design.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              (_design.shadowOpacity + 0.04).clamp(0, 0.35),
            ),
            blurRadius: (_design.shadowBlur + 8).clamp(0, 40),
            offset: const Offset(0, 12),
          ),
        ],
      );

    case HomeCardStyle.soft:
      return BoxDecoration(
        color: _design.cardColor.withOpacity(_design.cardBackgroundOpacity),
        borderRadius: BorderRadius.circular(_design.cardRadius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_design.shadowOpacity),
            blurRadius: _design.shadowBlur,
            offset: const Offset(0, 8),
          ),
        ],
      );
  }

  return BoxDecoration(
    color: _design.cardColor,
    borderRadius: BorderRadius.circular(_design.cardRadius),
  );
}

  Color _effectiveSectionAccent(HomeSectionConfig section) {
    return section.accentOverride ?? _design.primaryColor;
  }

  Widget _previewGlassPanel({
    required Widget child,
    required double radius,
  }) {
    if (!_design.glassEnabled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(0.24)),
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _design.blurSigma,
          sigmaY: _design.blurSigma,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_design.glassOpacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
            boxShadow: [
              if (_design.premiumGlow)
                BoxShadow(
                  color: _design.primaryColor.withOpacity(0.22),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _design.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _design.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _design.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _design.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _design.textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: _design.primaryColor.withOpacity(0.10),
      labelStyle: TextStyle(
        color: _design.primaryColor,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: _design.primaryColor.withOpacity(0.15)),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _design.textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value.toStringAsFixed(value >= 10 ? 0 : 2),
              style: TextStyle(
                color: _design.mutedTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: _design.primaryColor,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _enumSelector<T>({
    required String title,
    required T current,
    required List<T> values,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _design.textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) {
            final selected = value == current;
            return ChoiceChip(
              selected: selected,
              label: Text(labelBuilder(value)),
              onSelected: (_) => onChanged(value),
              selectedColor: _design.primaryColor.withOpacity(0.18),
              backgroundColor: _design.surfaceColor,
              labelStyle: TextStyle(
                color: selected ? _design.primaryColor : _design.textColor,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: selected ? _design.primaryColor : _design.borderColor,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _colorPickerRow({
    required String label,
    required Color value,
    required List<Color> options,
    required ValueChanged<Color> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _design.textColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((c) {
              final selected = c.value == value.value;

              return GestureDetector(
                onTap: () => onChanged(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 34 : 30,
                  height: selected ? 34 : 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? _design.textColor : Colors.white,
                      width: selected ? 2.4 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

const List<Color> _accentColors = [
  Color(0xFF00A750),
  Color(0xFF00C060),
  Color(0xFF10B981),
  Color(0xFF7ED321),
  Color(0xFF0091EA),
  Color(0xFF3B82F6),
  Color(0xFF7C3AED),
  Color(0xFFE4002B),
  Color(0xFFF59E0B),
  Color(0xFF111827),
];

const List<Color> _softBackgrounds = [
  Color(0xFFEFF8F1),
  Color(0xFFF4FFFA),
  Color(0xFFF9FAFB),
  Color(0xFFF7F9FC),
  Color(0xFFFFFBF4),
  Color(0xFFF6F3FF),
  Color(0xFF0F1512),
];

const List<Color> _surfaceColors = [
  Colors.white,
  Color(0xFFF8FBF9),
  Color(0xFFF6F8FA),
  Color(0xFF17221C),
  Color(0xFF141D18),
];

const List<Color> _textColors = [
  Color(0xFF18201B),
  Color(0xFF111827),
  Color(0xFF334155),
  Colors.white,
];