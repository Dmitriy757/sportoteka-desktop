import 'package:shared_preferences/shared_preferences.dart';

class PrefUtils {
  static SharedPreferences? _prefs;

  /// ВАЖНО: ключи должны совпадать со старыми
  static String prefName = "com.flutterplaygroundbookingapp.app.";
  static String isIntro = "${prefName}isIntro";
  static String signIn = "${prefName}signIn";

  static String userRole = "${prefName}userRole";
  static String userFirstName = "${prefName}userFirstName";
  static String userLastName = "${prefName}userLastName";
  static String userEmail = "${prefName}userEmail";

  static String teamIdKey = "${prefName}teamId";
  static String userIdKey = "${prefName}userId";

  static String agreedEulaKey = "${prefName}agreedEula";

  /// служебный ключ фото
  static const String _userPhotoKey = "user_photo";

  // ---------------------------
  // INTERNAL
  // ---------------------------
  static Future<SharedPreferences> _instance() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ---------------------------
  // Intro / SignIn
  // ---------------------------
  static Future<void> setIsIntro(bool value) async {
    final p = await _instance();
    await p.setBool(isIntro, value);
  }

  static Future<bool> getIsIntro() async {
    final p = await _instance();
    return p.getBool(isIntro) ?? true;
  }

  /// signIn = true -> вошёл, false -> не вошёл
  static Future<void> setIsSignIn(bool value) async {
    final p = await _instance();
    await p.setBool(signIn, value);
  }

  static Future<bool> getIsSignIn() async {
    final p = await _instance();
    return p.getBool(signIn) ?? false;
  }

  // ---------------------------
  // UserId / TeamId
  // ---------------------------
  static Future<void> setUserId(int value) async {
    final p = await _instance();
    await p.setInt(userIdKey, value);
  }

  static Future<int?> getUserId() async {
    final p = await _instance();
    return p.getInt(userIdKey);
  }

  static Future<void> setTeamId(int value) async {
    final p = await _instance();
    await p.setInt(teamIdKey, value);
  }

  static Future<int?> getTeamId() async {
    final p = await _instance();
    return p.getInt(teamIdKey);
  }

  // ---------------------------
  // ROLE / USER DATA (STATIC)
  // ---------------------------
  static Future<void> setRole(String role) async {
    final p = await _instance();
    await p.setString(userRole, role);
  }

  static Future<String> getRole() async {
    final p = await _instance();
    return p.getString(userRole) ?? '';
  }

  static Future<void> setUserFirstName(String firstName) async {
    final p = await _instance();
    await p.setString(userFirstName, firstName);
  }

  static Future<String> getUserFirstName() async {
    final p = await _instance();
    return p.getString(userFirstName) ?? '';
  }

  static Future<void> setUserLastName(String lastName) async {
    final p = await _instance();
    await p.setString(userLastName, lastName);
  }

  static Future<String> getUserLastName() async {
    final p = await _instance();
    return p.getString(userLastName) ?? '';
  }

  static Future<void> setUserEmail(String email) async {
    final p = await _instance();
    await p.setString(userEmail, email);
  }

  static Future<String> getUserEmail() async {
    final p = await _instance();
    return p.getString(userEmail) ?? '';
  }

  // ---------------------------
  // Theme
  // ---------------------------
  static Future<void> setThemeData(String value) async {
    final p = await _instance();
    await p.setString('themeData', value);
  }

  static Future<String> getThemeData() async {
    final p = await _instance();
    return p.getString('themeData') ?? 'primary';
  }

  // ---------------------------
  // Photo
  // ---------------------------
  static Future<void> setUserPhoto(String fileName) async {
    final p = await _instance();
    await p.setString(_userPhotoKey, fileName);
  }

  static Future<String?> getUserPhoto() async {
    final p = await _instance();
    final fileName = p.getString(_userPhotoKey);
    if (fileName != null && fileName.isNotEmpty) {
      return 'https://sportotekaapp.ru/uploads/$fileName';
    }
    return null;
  }

  // ---------------------------
  // EULA
  // ---------------------------
  static Future<void> setAgreedEula(bool value) async {
    final p = await _instance();
    await p.setBool(agreedEulaKey, value);
  }

  static Future<bool> getAgreedEula() async {
    final p = await _instance();
    return p.getBool(agreedEulaKey) ?? false;
  }

  // ---------------------------
  // CLEAR (очень важно)
  // ---------------------------
  static Future<void> clearAll() async {
    final p = await _instance();

    await p.remove(userIdKey);
    await p.remove(teamIdKey);
    await p.remove(userRole);
    await p.remove(userFirstName);
    await p.remove(userLastName);
    await p.remove(userEmail);
    await p.remove(_userPhotoKey);

    await p.setBool(signIn, false);
  }
}

/// ✅ EXTENSION: чтобы старые вызовы PrefUtils().xxx тоже работали
extension PrefUtilsInstanceCompat on PrefUtils {
  Future<void> init() async {
    // просто гарантируем инициализацию prefs
    await PrefUtils.getIsSignIn();
  }

  // instance-style setters/getters (пробрасываем на static)
  Future<void> setUserRole(String role) => PrefUtils.setRole(role);
  Future<void> setUserFirstName(String v) => PrefUtils.setUserFirstName(v);
  Future<void> setUserLastName(String v) => PrefUtils.setUserLastName(v);
  Future<void> setUserEmail(String v) => PrefUtils.setUserEmail(v);

  // instance getters (синхронные раньше у тебя были — сделаем безопасно через cached prefs)
  // Если где-то нужны СИНХРОННЫЕ — лучше перевести на async,
  // но чтобы не ломать, дадим sync через _prefs (если еще не готово, будет '').
  String getUserRole() => PrefUtils._prefs?.getString(PrefUtils.userRole) ?? '';
  String getUserFirstName() => PrefUtils._prefs?.getString(PrefUtils.userFirstName) ?? '';
  String getUserLastName() => PrefUtils._prefs?.getString(PrefUtils.userLastName) ?? '';
  String getUserEmail() => PrefUtils._prefs?.getString(PrefUtils.userEmail) ?? '';

  // theme_helper у тебя вызывает PrefUtils().getThemeData() синхронно —
  // дадим sync чтение из кэша, чтобы компилилось.
  String getThemeData() => PrefUtils._prefs?.getString('themeData') ?? 'primary';

  Future<void> setThemeData(String v) => PrefUtils.setThemeData(v);

  Future<void> clearPreferencesData() async {
    await PrefUtils.clearAll();
  }
}
