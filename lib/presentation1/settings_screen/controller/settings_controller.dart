import 'package:get/get.dart';

/// ✅ Заглушка-контроллер настроек (GetX)
/// Сейчас: хранится только в памяти (после перезапуска сбросится)
/// Позже: подключим сохранение через твой PrefUtils / сервер
class SettingsController extends GetxController {
  // -------------------------
  // УВЕДОМЛЕНИЯ
  // -------------------------
  bool pushEnabled = true;
  bool messageNotifications = true;
  bool trainingReminders = true;

  // -------------------------
  // БЕЗОПАСНОСТЬ
  // -------------------------
  bool faceIdEnabled = false;
  bool autoLockEnabled = true;

  // -------------------------
  // ИНТЕРФЕЙС
  // -------------------------
  bool darkMode = false;
  bool haptics = true;
  bool sounds = true;
  String language = "Русский"; // заглушка

  // -------------------------
  // ВИДЕО / МЕДИА
  // -------------------------
  bool autoplayVideo = true;
  bool preloadImages = true;

  // -------------------------
  // СЕТЬ / КЭШ
  // -------------------------
  bool wifiOnlyUploads = false;

  // ✅ Заглушка: позже сюда подцепим load из PrefUtils/API
  @override
  void onInit() {
    super.onInit();
    update();
  }

  // =========================
  // ✅ TOGGLES (пока просто меняем состояние)
  // =========================
  void togglePush() {
    pushEnabled = !pushEnabled;
    update();
  }

  void toggleMessages() {
    messageNotifications = !messageNotifications;
    update();
  }

  void toggleTrainingReminders() {
    trainingReminders = !trainingReminders;
    update();
  }

  void toggleFaceId() {
    faceIdEnabled = !faceIdEnabled;
    update();
  }

  void toggleAutoLock() {
    autoLockEnabled = !autoLockEnabled;
    update();
  }

  void toggleDarkMode() {
    darkMode = !darkMode;
    update();
  }

  void toggleHaptics() {
    haptics = !haptics;
    update();
  }

  void toggleSounds() {
    sounds = !sounds;
    update();
  }

  void setLanguage(String value) {
    language = value;
    update();
  }

  void toggleAutoplay() {
    autoplayVideo = !autoplayVideo;
    update();
  }

  void togglePreloadImages() {
    preloadImages = !preloadImages;
    update();
  }

  void toggleWifiOnlyUploads() {
    wifiOnlyUploads = !wifiOnlyUploads;
    update();
  }
}
