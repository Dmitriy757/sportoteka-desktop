class MediaUtils {
  MediaUtils._();

  static const String _domain = "https://sportotekaapp.ru";

  /// Нормализует путь/URL из БД к абсолютному URL.
  /// Поддержка кейсов:
  /// - null / "" / "null"
  /// - "https://..."
  /// - "/uploads/..."
  /// - "uploads/..."
  /// - "api/uploads/..."
  /// - "/api/uploads/..."
  static String? normalizeUrl(String? raw) {
    if (raw == null) return null;

    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.toLowerCase() == "null") return null;

    // Уже абсолютная ссылка
    if (s.startsWith("http://") || s.startsWith("https://")) return s;

    // Убираем ведущий слэш, чтобы удобно склеивать
    if (s.startsWith("/")) s = s.substring(1);

    // В БД бывает "api/uploads/..."
    if (s.startsWith("api/")) {
      return "$_domain/$s";
    }

    // В БД бывает "uploads/..."
    if (s.startsWith("uploads/")) {
      return "$_domain/$s";
    }

    // fallback: считаем относительным от домена
    return "$_domain/$s";
  }
}
