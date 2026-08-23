// ignore_for_file: deprecated_member_use

import '../../core/expantiontile/src/types/expansion_tile_border_item.dart';
import 'controller/help_controller.dart';
import 'package:flutter/material.dart';
import 'package:sportoteka/core/app_export.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  HelpController helpController = Get.put(HelpController());
  @override
  Widget build(BuildContext context) {
    mediaQueryData = MediaQuery.of(context);

    return WillPopScope(
      onWillPop: () async {
        Get.back();
        return true;
      },
      child: Scaffold(
        backgroundColor: appTheme.bgColor,
        body: SafeArea(
          child: Column(
            children: [
              getCommonAppBar("Помощь"),
              SizedBox(height: 0.v),
              Expanded(
                child: ListView(
                  children: [
                    _buildFrame(
                      title: "Регистрация и вход",
                      content: "Для начала работы зарегистрируйтесь, выбрав роль: Тренер, Федерация, Родитель или Игрок. Укажите имя, фамилию, email и пароль. После регистрации вы можете войти в систему и начать использовать функциональность, доступную вашей роли.",
                    ),
                    _buildFrame(
                      title: "Создание команды (для тренеров)",
                      content: "После входа тренер может создать команду, указав название. Команда будет закреплена за ним. В разделе 'Моя команда' можно добавлять и редактировать игроков.",
                    ),
                    _buildFrame(
                      title: "Добавление игроков",
                      content: "Нажмите 'Добавить игрока' в разделе 'Моя команда'. Заполните имя, фамилию, дату рождения, гражданство, позицию, номер, рост и вес. Игроку будет автоматически создан аккаунт.",
                    ),
                    _buildFrame(
                      title: "Публикации и новости",
                      content: "На главной странице отображаются последние новости. Вы можете публиковать новости с текстом, фото и видео. Новости можно фильтровать по видам спорта и командам.",
                    ),
                    _buildFrame(
                      title: "Тренировочные программы",
                      content: "Тренер может создавать тренировочные программы и назначать их своим игрокам. Каждая программа включает описание, вложения, сроки и задачи. Программы отображаются в разделе 'Мои программы'.",
                    ),
                    _buildFrame(
                      title: "Медкарта игрока",
                      content: "В профиле игрока отображается медицинская карта: осмотры, вакцинации, травмы, состояние и документы. Эти записи добавляются тренером или врачом.",
                    ),
                    _buildFrame(
                      title: "Чат и общение",
                      content: "Вы можете создавать групповые или приватные чаты. Общение доступно между пользователями, входящими в одну команду или федерацию.",
                    ),
                    _buildFrame(
                      title: "Профиль пользователя",
                      content: "В разделе 'Профиль' отображается ваша роль, имя, email, команды и опубликованные материалы. Доступна настройка аккаунта и выход из системы.",
                    ),
                    _buildFrame(
                      title: "Расписание и бронирование",
                      content: "Пользователи могут просматривать расписание тренировок и мероприятий. В разделе 'Бронь' доступно бронирование спортивных площадок и услуг.",
                    ),
                    _buildFrame(
                      title: "Статистика и метрики игроков",
                      content: "В профиле каждого игрока отображаются ключевые спортивные показатели: матчи, голы, передачи, рост, вес и другие. Эти данные добавляет тренер при создании или редактировании игрока.",
                    ),
                    _buildFrame(
                      title: "Видео и медиа",
                      content: "В разделах новостей и профиля можно загружать видео и фото. Раздел 'Видео' открывает галерею с Reels/короткими клипами, загруженными игроками и тренерами.",
                    ),
                    _buildFrame(
                      title: "Спортпит и инвентарь",
                      content: "Разделы 'Спортпит' и 'Инвентарь' содержат рекомендации по питанию, спортивным добавкам и доступному инвентарю, который может быть закреплён за игроками.",
                    ),
                    _buildFrame(
                      title: "Пресс-центр и трансферы",
                      content: "Новости от клубов, объявления о трансферах, официальные сообщения и статьи — всё это доступно в пресс-центре. Клубы могут публиковать запросы на трансфер игроков.",
                    ),
                    _buildFrame(
                      title: "Навигация по видам спорта",
                      content: "Категории спорта (футбол, баскетбол, волейбол и т.д.) позволяют фильтровать контент, команды и игроков. После выбора отображаются релевантные клубы, турниры и материалы.",
                    ),
                    _buildFrame(
                      title: "История травм и восстановлений",
                      content: "В медкарте можно вести историю травм, назначений врача и этапов восстановления, чтобы тренер и родитель могли отслеживать здоровье игрока.",
                    ),
                    _buildFrame(
                      title: "Документы и файлы",
                      content: "Загружайте важные файлы: медсправки, допуски, контракты. Эти документы доступны в профиле игрока и защищены.",
                    ),
                    _buildFrame(
                      title: "Админ-панель и роли",
                      content: "В системе есть админ-панель (если включена), через которую администраторы управляют пользователями, модерируют публикации и следят за безопасностью платформы.",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrame({required String title, required String content}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.h, vertical: 8.v),
      child: ExpansionTileBorderItem(
        iconColor: appTheme.black900,
        childrenPadding:
            EdgeInsets.only(left: 20.h, right: 20.h, top: 0, bottom: 16.v),
        borderRadius: BorderRadius.circular(16.h),
        decoration: AppDecoration.fillGray.copyWith(
          color: appTheme.textfieldFillColor,
          borderRadius: BorderRadiusStyle.roundedBorder16,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium!.copyWith(
            color: appTheme.black900,
          ),
        ),
        expendedBorderColor: Colors.blue,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              content,
              textAlign: TextAlign.left,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: appTheme.black900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}