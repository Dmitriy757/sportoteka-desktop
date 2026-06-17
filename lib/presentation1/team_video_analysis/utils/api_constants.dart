class ApiConstants {
  static const String phpBaseUrl = "https://sportotekaapp.ru/api";
  static const String aiBaseUrl = "https://sportotekaapp.ru/ai";

  // backward compatibility
  static const String apiBase = phpBaseUrl;

  static const String getPlayersUrl = "$phpBaseUrl/get_players_by_team.php";
  static const String addEventUrl = "$phpBaseUrl/add_video_event.php";
  static const String getEventsUrl = "$phpBaseUrl/get_video_events_by_match.php";
  static const String deleteEventUrl = "$phpBaseUrl/delete_video_event.php";
  static const String getMatchTtdReportUrl = "$phpBaseUrl/get_match_ttd_report.php";
  static const String updateEventUrl = "$phpBaseUrl/update_video_event.php";
  static const String getPlayerTtdEventsUrl = "$phpBaseUrl/get_player_ttd_events.php";
}