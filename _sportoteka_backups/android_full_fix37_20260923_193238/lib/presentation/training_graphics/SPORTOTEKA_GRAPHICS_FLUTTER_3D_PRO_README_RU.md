# Sportoteka Training Graphics — Flutter 3D Pro

Версия модуля после ревизии `training_graphics(3).zip`.

## Что изменено

- Добавлен **Sportoteka Flutter 3D Pro** (`flutter_3d_pro_screen.dart`). Unity, WebView, `three_dart` и отдельный 3D runtime не требуются.
- 3D Pro открывает **тот же `TgState`**, что и основной редактор: изменения схемы сразу видны в 3D и не требуют конвертации.
- В 3D отображаются игроки/мяч/конусы/манекены/ворота, текст, линии, polyline, curve, wavy, spring, spiral, zigzag, прямоугольники, круги и произвольные зоны.
- Камера 3D: orbit, elevation, zoom, reset; переключатели маршрутов, подписей и зон.
- Старые `field_3d` и `unity` экраны оставлены как совместимые точки входа, но теперь тоже используют Flutter 3D Pro и больше не импортируют Unity/three_dart.
- Исправлен режим **Объект / Точки**: обычный клик по кривой/волне/зигзагу/спирали только выбирает объект. Редактирование точек включается явно.
- Переработана анимация: визуально перемещается **сам привязанный `TgStamp`**, а не его дубликат поверх сцены.
- Обычная тактическая линия больше не запускает анимацию автоматически. Маршрутом считается только явно привязанный к шагу и объекту элемент.
- В маршрутах анимации поддержаны Line, Polyline, Curve, Wavy, Spring, Spiral и Zigzag.
- Добавлен PDF A4 landscape без новой PDF-зависимости (`tg_pdf_export.dart`).
- PNG/PDF/JSON используют системное **«Сохранить как…»** через `FilePicker.saveFile`; сохранение во временную папку остаётся fallback.
- Добавлен личный режим редактора без клуба/команды и экран проверки доступа к модулю.
- Удалён дублирующий код корневого `tg_right_panel.dart`: файл теперь compatibility-export на актуальный `widgets/tg_right_panel.dart`.

## Личный профиль / отдельная подписка

Минимальный вызов:

```dart
TrainingGraphicsScreen(
  personalMode: true,
  userId: currentUserId, // обязателен в personalMode
  userDisplayName: currentUserName,
  moduleAccessGranted: hasGraphicEditorSubscription,
  onManageSubscription: openSubscriptions,
)
```

В личном режиме `userId` обязателен: это не позволяет смешать документы двух аккаунтов на одном устройстве.

### Облачный Personal Workspace

Редактор имеет три необязательных host-callback. Если они не переданы, используется локальный профильный cache (`PrefUtils`). Если переданы — UI работает с серверным аккаунтом и одновременно сохраняет локальный cache для offline fallback.

```dart
TrainingGraphicsScreen(
  personalMode: true,
  userId: currentUserId,
  userDisplayName: currentUserName,
  moduleAccessGranted: hasGraphicEditorSubscription,
  onManageSubscription: openSubscriptions,

  personalLibraryLoader: (userId) async {
    // GET/POST вашего API -> List<Map<String,dynamic>>
    return loadPersonalGraphics(userId);
  },
  personalGraphicSaver: (userId, document) async {
    // API может вернуть как минимум {'id': serverId}
    return savePersonalGraphic(userId, document);
  },
  personalGraphicDeleter: (userId, graphicId) async {
    await deletePersonalGraphic(userId, graphicId);
  },
)
```

Рекомендуемый серверный owner-контракт уже формируется редактором:

```json
{
  "owner_type": "user",
  "owner_user_id": 250,
  "club_id": 0,
  "team_id": 0,
  "doc_json": {}
}
```

Клубный режим остаётся прежним и продолжает использовать `TrainingGraphicsApi` / Workspace команды.

## Entitlement подписки

Сам редактор не содержит оплату и не привязан к конкретному App Store/Google Play/веб-биллингу. Хост передаёт факт доступа:

```dart
moduleAccessGranted: entitlement.graphicEditorPro
```

Если `false`, редактор показывает спокойный экран «Графический редактор — модуль не подключён» и вызывает `onManageSubscription` по кнопке.

Это позволяет использовать один и тот же модуль с App Store subscriptions, Google Play, Stripe/веб-подпиской или клубной лицензией.

## Важно при интеграции

1. В personalMode всегда передавать реальный `userId` текущего аккаунта.
2. Для синхронизации Mac/iPad/iPhone/Android подключить три personal callbacks к серверному API.
3. Клубный CMR намеренно не вызывается из personalMode. План остаётся личным; публикация в CMR делается из Workspace команды.
4. Для Flutter 3D Pro не нужны Unity, `flutter_embed_unity`, `three_dart` и `three_dart_jsm` именно этому модулю. Если они больше нигде в приложении не используются, зависимости можно удалить из `pubspec.yaml` основного проекта.
5. В текущем окружении архива нет полного Flutter-проекта/pubspec и Flutter SDK, поэтому выполнены статическая проверка структуры/скобок/связей кода, но не `flutter analyze` всей Sportoteka.
