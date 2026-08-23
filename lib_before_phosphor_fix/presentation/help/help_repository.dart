import 'package:flutter/material.dart';
import 'help_models.dart';

class HelpRepository {
  static const Color green = Color(0xFF00A750);
  static const Color blue = Color(0xFF1976D2);
  static const Color orange = Color(0xFFF57C00);
  static const Color purple = Color(0xFF7B1FA2);
  static const Color red = Color(0xFFD32F2F);
  static const Color teal = Color(0xFF00796B);

  static List<HelpTipItem> allTips = [
    HelpTipItem(
      id: 'create_team',
      title: 'Как создать команду',
      subtitle: 'Пошаговое создание команды тренером',
      icon: Icons.groups_rounded,
      accent: green,
      sections: [
        HelpTipSection(
          heading: 'Что делает этот раздел',
          bullets: [
            'Команда создаётся тренером и привязывается к его аккаунту.',
            'После создания команды можно добавлять игроков, назначать тренировки и вести состав.',
          ],
        ),
        HelpTipSection(
          heading: 'Как создать',
          bullets: [
            'Откройте раздел команды.',
            'Нажмите кнопку создания команды.',
            'Введите название команды.',
            'Укажите вид спорта.',
            'Сохраните данные.',
          ],
        ),
        HelpTipSection(
          heading: 'Что будет дальше',
          bullets: [
            'Если команда уже есть, вместо кнопки создания откроется экран “Моя команда”.',
            'После создания можно переходить к добавлению игроков и программ.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'add_player',
      title: 'Как добавить игрока',
      subtitle: 'Заполнение карточки спортсмена',
      icon: Icons.person_add_alt_1_rounded,
      accent: blue,
      sections: [
        HelpTipSection(
          heading: 'Где добавлять игрока',
          bullets: [
            'Игрок добавляется из экрана команды.',
            'Тренер может создать игрока и привязать его к своей команде.',
          ],
        ),
        HelpTipSection(
          heading: 'Какие данные заполнить',
          bullets: [
            'Имя и фамилию.',
            'Дату рождения.',
            'Позицию.',
            'Гражданство.',
            'Спортивные данные и дополнительные параметры.',
          ],
        ),
        HelpTipSection(
          heading: 'После сохранения',
          bullets: [
            'Игрок появится в составе команды.',
            'Ему можно будет назначать тренировки и вести профиль.',
            'При необходимости для игрока может быть создан отдельный аккаунт пользователя.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'player_profile',
      title: 'Профиль игрока',
      subtitle: 'Как работает экран игрока',
      icon: Icons.badge_rounded,
      accent: green,
      sections: [
        HelpTipSection(
          heading: 'Что есть в профиле',
          bullets: [
            'Основная информация об игроке.',
            'Метрики и статистика.',
            'Достижения.',
            'Медкарта.',
            'История тренировок.',
            'Фото и видео.',
          ],
        ),
        HelpTipSection(
          heading: 'Что можно делать',
          bullets: [
            'Редактировать данные игрока.',
            'Добавлять достижения.',
            'Просматривать медзаписи.',
            'Открывать тренировочную историю.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'edit_player',
      title: 'Редактирование игрока',
      subtitle: 'Изменение данных спортсмена',
      icon: Icons.edit_rounded,
      accent: orange,
      sections: [
        HelpTipSection(
          heading: 'Когда используется',
          bullets: [
            'Когда нужно обновить профиль игрока.',
            'Когда добавляются новые параметры, фото, достижения или спортивные метрики.',
          ],
        ),
        HelpTipSection(
          heading: 'Что можно изменить',
          bullets: [
            'ФИО.',
            'Дату рождения.',
            'Позицию.',
            'Рост и вес.',
            'Клуб и номер.',
            'Медиа и достижения.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'metrics',
      title: 'Спортивные метрики',
      subtitle: 'Рост, вес, голы и другие показатели',
      icon: Icons.query_stats_rounded,
      accent: teal,
      sections: [
        HelpTipSection(
          heading: 'Для чего нужны метрики',
          bullets: [
            'Метрики помогают отслеживать развитие игрока.',
            'Они могут быть как стандартными, так и произвольными.',
          ],
        ),
        HelpTipSection(
          heading: 'Примеры метрик',
          bullets: [
            'Рост.',
            'Вес.',
            'Голы.',
            'Скорость.',
            'Выносливость.',
            'Индивидуальные параметры тренера.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'medical',
      title: 'Медкарта игрока',
      subtitle: 'Медицинские записи и история',
      icon: Icons.medical_information_rounded,
      accent: red,
      sections: [
        HelpTipSection(
          heading: 'Что хранится в медкарте',
          bullets: [
            'Осмотры.',
            'Травмы.',
            'Вакцинации.',
            'Физическое состояние.',
            'Документы и вложения.',
          ],
        ),
        HelpTipSection(
          heading: 'Что можно делать',
          bullets: [
            'Добавлять запись.',
            'Редактировать запись.',
            'Удалять запись.',
            'Фильтровать по типу и дате.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'personal_training',
      title: 'Личная тренировка',
      subtitle: 'Создание тренировок для себя',
      icon: Icons.fitness_center_rounded,
      accent: green,
      sections: [
        HelpTipSection(
          heading: 'Как работает',
          bullets: [
            'Пользователь может создать тренировку для себя.',
            'Тренировка сохраняется в базе и затем доступна в списке “Мои тренировки”.',
          ],
        ),
        HelpTipSection(
          heading: 'Что можно добавить',
          bullets: [
            'Название.',
            'Тип тренировки.',
            'Описание.',
            'Цели.',
            'Упражнения.',
            'Произвольные поля и параметры.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'training_programs',
      title: 'Тренировочные программы',
      subtitle: 'Программы для игроков и команды',
      icon: Icons.assignment_rounded,
      accent: blue,
      sections: [
        HelpTipSection(
          heading: 'Для чего нужен раздел',
          bullets: [
            'Тренер формирует тренировочные программы для игроков.',
            'Программы можно привязывать к команде и отдельным спортсменам.',
          ],
        ),
        HelpTipSection(
          heading: 'Что можно делать',
          bullets: [
            'Создавать программу.',
            'Назначать игрокам.',
            'Просматривать детали.',
            'Редактировать.',
            'Удалять.',
            'Фильтровать по названию и дате.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'plans',
      title: 'Планы-конспекты',
      subtitle: 'Структурированные планы занятий',
      icon: Icons.description_rounded,
      accent: purple,
      sections: [
        HelpTipSection(
          heading: 'Что такое план-конспект',
          bullets: [
            'Это структурированный план тренировки с целью, упражнениями, инвентарём и блоками занятия.',
            'План можно использовать как рабочий документ тренера.',
          ],
        ),
        HelpTipSection(
          heading: 'Что можно хранить в плане',
          bullets: [
            'Название.',
            'Цель.',
            'Задачи.',
            'Инвентарь.',
            'Упражнения.',
            'Графику и схемы.',
            'Вложения.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'plan_folders',
      title: 'Папки планов',
      subtitle: 'Организация планов по папкам',
      icon: Icons.folder_copy_rounded,
      accent: orange,
      sections: [
        HelpTipSection(
          heading: 'Зачем нужны папки',
          bullets: [
            'Чтобы удобно хранить и группировать планы.',
            'Чтобы разделять планы по темам, возрастам, циклам и командам.',
          ],
        ),
        HelpTipSection(
          heading: 'Рекомендации',
          bullets: [
            'Создавайте отдельные папки под микроциклы.',
            'Разделяйте папки по возрастам или типам тренировок.',
            'Храните шаблонные планы отдельно от рабочих.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'files',
      title: 'Файлы и вложения',
      subtitle: 'Как работать с PDF и ссылками',
      icon: Icons.attach_file_rounded,
      accent: teal,
      sections: [
        HelpTipSection(
          heading: 'Где используются файлы',
          bullets: [
            'В тренировочных программах.',
            'В планах-конспектах.',
            'В медкарте.',
            'В учебных материалах.',
          ],
        ),
        HelpTipSection(
          heading: 'Что можно прикладывать',
          bullets: [
            'PDF-документы.',
            'Ссылки.',
            'Изображения.',
            'Сопроводительные материалы.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'training_graphics',
      title: 'Графический редактор',
      subtitle: 'Training Graphics для тактики',
      icon: Icons.draw_rounded,
      accent: purple,
      sections: [
        HelpTipSection(
          heading: 'Что умеет редактор',
          bullets: [
            'Рисовать линии и траектории.',
            'Расставлять игроков и объекты.',
            'Строить тактические схемы.',
            'Редактировать элементы на поле.',
            'Сохранять графику для тренировок и планов.',
          ],
        ),
        HelpTipSection(
          heading: 'Как начать',
          bullets: [
            'Откройте Training Graphics.',
            'Выберите поле или рабочую сцену.',
            'Добавьте объекты или игроков.',
            'Постройте схему.',
            'Сохраните результат.',
          ],
        ),
        HelpTipSection(
          heading: 'Где используется дальше',
          bullets: [
            'В планах-конспектах.',
            'В обучении игроков.',
            'В тактическом разборе.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'video_analysis',
      title: 'Видеоанализ',
      subtitle: 'Работа с видео и разбором',
      icon: Icons.video_library_rounded,
      accent: red,
      sections: [
        HelpTipSection(
          heading: 'Что даёт видеоанализ',
          bullets: [
            'Разбор игровых моментов.',
            'Визуальное обучение.',
            'Пошаговый анализ действий игроков.',
          ],
        ),
        HelpTipSection(
          heading: 'Типовой сценарий',
          bullets: [
            'Загрузите видео.',
            'Добавьте превью.',
            'Откройте ролик для разбора.',
            'Используйте графику или пояснения для анализа.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'video_lessons',
      title: 'Видеоуроки',
      subtitle: 'Каталог обучающих материалов',
      icon: Icons.ondemand_video_rounded,
      accent: blue,
      sections: [
        HelpTipSection(
          heading: 'Что это за раздел',
          bullets: [
            'Это библиотека обучающих видео и материалов.',
            'Здесь могут быть уроки по упражнениям, технике и методике.',
          ],
        ),
        HelpTipSection(
          heading: 'Как использовать',
          bullets: [
            'Откройте раздел видеоуроков.',
            'Выберите нужную категорию или автора.',
            'Изучайте материал и переходите к деталям.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'exercise_videos',
      title: 'Видео к упражнениям',
      subtitle: 'Обучающие ролики от тренеров',
      icon: Icons.play_lesson_rounded,
      accent: green,
      sections: [
        HelpTipSection(
          heading: 'Как это работает',
          bullets: [
            'Для каждого упражнения можно открыть подробный экран.',
            'Там отображаются видео, описание, таймер и дополнительные материалы.',
          ],
        ),
        HelpTipSection(
          heading: 'Дополнительно',
          bullets: [
            'Тренеры могут загружать свои видео.',
            'Другие пользователи могут смотреть материалы, оставлять комментарии и оценки.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'reels',
      title: 'Reels',
      subtitle: 'Короткие спортивные видео',
      icon: Icons.smart_display_rounded,
      accent: red,
      sections: [
        HelpTipSection(
          heading: 'Что можно делать',
          bullets: [
            'Смотреть короткие ролики.',
            'Лайкать.',
            'Комментировать.',
            'Переходить к автору.',
            'Публиковать собственные reels.',
          ],
        ),
        HelpTipSection(
          heading: 'Для публикации',
          bullets: [
            'Откройте экран загрузки reels.',
            'Выберите видео.',
            'При необходимости обрежьте или подготовьте материал.',
            'Добавьте описание.',
            'Опубликуйте ролик.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'chat',
      title: 'Чаты',
      subtitle: 'Личное и групповое общение',
      icon: Icons.chat_bubble_rounded,
      accent: teal,
      sections: [
        HelpTipSection(
          heading: 'Что доступно',
          bullets: [
            'Личные чаты.',
            'Групповые чаты.',
            'Реакции на сообщения.',
            'Вложения.',
            'Редактирование и удаление сообщений.',
          ],
        ),
        HelpTipSection(
          heading: 'Как пользоваться',
          bullets: [
            'Откройте список чатов.',
            'Выберите существующий диалог или создайте новый.',
            'Для группы укажите название и тип.',
            'Отправляйте сообщения и используйте реакции.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'groups',
      title: 'Групповые чаты',
      subtitle: 'Открытые и закрытые группы',
      icon: Icons.groups_3_rounded,
      accent: purple,
      sections: [
        HelpTipSection(
          heading: 'Возможности',
          bullets: [
            'Создание групповых чатов.',
            'Выбор участников.',
            'Название группы.',
            'Тип чата: открытый или закрытый.',
          ],
        ),
        HelpTipSection(
          heading: 'Когда использовать',
          bullets: [
            'Для общения команды.',
            'Для связи тренеров и родителей.',
            'Для обсуждения программ и событий.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'events',
      title: 'Мероприятия',
      subtitle: 'События и участие',
      icon: Icons.event_rounded,
      accent: orange,
      sections: [
        HelpTipSection(
          heading: 'Что умеет раздел',
          bullets: [
            'Показывать ближайшие спортивные события.',
            'Позволять просматривать детали мероприятия.',
            'Переходить к информации об участниках и активности.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'venues',
      title: 'Площадки',
      subtitle: 'Каталог и бронирование',
      icon: Icons.location_on_rounded,
      accent: green,
      sections: [
        HelpTipSection(
          heading: 'Что есть в разделе',
          bullets: [
            'Список спортивных площадок.',
            'Фото и описание.',
            'Категории по видам спорта.',
            'Бронирование времени.',
          ],
        ),
        HelpTipSection(
          heading: 'Как бронировать',
          bullets: [
            'Откройте площадку.',
            'Выберите свободное время.',
            'Подтвердите бронь.',
            'Занятые интервалы повторно недоступны.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'schools',
      title: 'Школы',
      subtitle: 'Работа со школами и учениками',
      icon: Icons.school_rounded,
      accent: blue,
      sections: [
        HelpTipSection(
          heading: 'Что можно делать',
          bullets: [
            'Просматривать школы.',
            'Открывать подробную информацию.',
            'Добавлять учеников.',
            'Работать с метриками и медкартой учеников.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'news',
      title: 'Новости',
      subtitle: 'Лента, фильтры и категории спорта',
      icon: Icons.newspaper_rounded,
      accent: teal,
      sections: [
        HelpTipSection(
          heading: 'Как устроен раздел',
          bullets: [
            'Новости фильтруются по видам спорта.',
            'На главной отображаются подборки и карточки.',
            'Можно открывать детали новости по нажатию.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'subscription',
      title: 'Подписка PRO',
      subtitle: 'Премиум функции приложения',
      icon: Icons.workspace_premium_rounded,
      accent: orange,
      sections: [
        HelpTipSection(
          heading: 'Что даёт подписка',
          bullets: [
            'Доступ к расширенным спортивным инструментам.',
            'Дополнительные возможности для профессиональной работы.',
            'Премиум-разделы и улучшенные функции.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'ring',
      title: 'Sportoteka Ring',
      subtitle: 'Умное отслеживание активности',
      icon: Icons.ring_volume_rounded,
      accent: green,
      sections: [
        HelpTipSection(
          heading: 'Что это',
          bullets: [
            'Раздел, связанный с умным спортивным трекингом.',
            'Помогает отображать и использовать данные активности.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'roles',
      title: 'Роли в приложении',
      subtitle: 'Тренер, игрок, родитель и другие',
      icon: Icons.admin_panel_settings_rounded,
      accent: purple,
      sections: [
        HelpTipSection(
          heading: 'Основные роли',
          bullets: [
            'Тренер.',
            'Игрок.',
            'Родитель.',
            'Федерация.',
            'Школа и другие роли проекта.',
          ],
        ),
        HelpTipSection(
          heading: 'Почему это важно',
          bullets: [
            'От роли зависит доступный функционал.',
            'У разных ролей свои экраны, действия и разделы.',
          ],
        ),
      ],
    ),
    HelpTipItem(
      id: 'customization',
      title: 'Кастомизация интерфейса',
      subtitle: 'Настройка внешнего вида',
      icon: Icons.tune_rounded,
      accent: blue,
      sections: [
        HelpTipSection(
          heading: 'Что можно настраивать',
          bullets: [
            'Главную страницу.',
            'Цвета.',
            'Блоки и секции.',
            'Вид карточек.',
            'Порядок отображения разделов.',
          ],
        ),
        HelpTipSection(
          heading: 'Совет',
          bullets: [
            'Сначала настройте ключевые разделы: новости, команды, тренировки и помощь.',
          ],
        ),
      ],
    ),
  ];

  static HelpTipItem getById(String id) {
    return allTips.firstWhere(
      (e) => e.id == id,
      orElse: () => allTips.first,
    );
  }
}