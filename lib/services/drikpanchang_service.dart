import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DrikTiming {
  final String name;
  final DateTime start;
  final DateTime end;
  DrikTiming({required this.name, required this.start, required this.end});

  Map<String, dynamic> toMatchMap() => {
        'name': name,
        'start_time': start,
        'end_time': end,
      };
}

class DrikResult {
  final DrikTiming? tithi;
  final DrikTiming? nakshatra;
  DrikResult({this.tithi, this.nakshatra});
}

class DrikPanchangService {
  static const _baseUrl = 'https://www.drikpanchang.com';

  /// Fetches Tithi and Nakshatra begin/end times for a given date and geonameId.
  /// Returns null if anything fails (offline, parsing error, etc.).
  static Future<DrikResult?> fetchTimings(DateTime date, int geonameId) async {
    final dateParam = DateFormat('dd/MM/yyyy').format(date);
    final url = Uri.parse('$_baseUrl/panchang/day-panchang.html').replace(
        queryParameters: {
          'date': dateParam,
          'geoname-id': '$geonameId',
          'time-format': '12hour'
        });
    try {
      final resp = await http.get(url);
      if (resp.statusCode != 200) return null;
      final html = resp.body;

      // Parse JavaScript variables that DrikPanchang injects
      final tithiMatch = RegExp(
              r"drikp_g_tithi_name_='([^']+)'.*?drikp_g_tithi_hhmm_='([^']+)'.*?drikp_g_skipped_tithi_name_='([^']+)'.*?drikp_g_skipped_tithi_hhmm_='([^']+)'")
          .firstMatch(html);
      final nakshatraMatch = RegExp(
              r"drikp_g_nakshatra_name_='([^']+)'.*?drikp_g_nakshatra_hhmm_='([^']+)'.*?drikp_g_skipped_nakshatra_name_='([^']+)'.*?drikp_g_skipped_nakshatra_hhmm_='([^']+)'")
          .firstMatch(html);

      DrikTiming? tithi;
      if (tithiMatch != null) {
        final name = tithiMatch.group(1)!;
        final startHHMM = tithiMatch.group(2)!;
        final nextName = tithiMatch.group(3)!;
        final nextHHMM = tithiMatch.group(4)!;
        tithi = _parseTiming(name, startHHMM, nextName, nextHHMM, date);
      }

      DrikTiming? nakshatra;
      if (nakshatraMatch != null) {
        final name = nakshatraMatch.group(1)!;
        final startHHMM = nakshatraMatch.group(2)!;
        final nextName = nakshatraMatch.group(3)!;
        final nextHHMM = nakshatraMatch.group(4)!;
        nakshatra = _parseTiming(name, startHHMM, nextName, nextHHMM, date);
      }

      if (tithi == null && nakshatra == null) return null;
      return DrikResult(tithi: tithi, nakshatra: nakshatra);
    } catch (e) {
      return null;
    }
  }

  static DrikTiming? _parseTiming(String name, String startHHMM,
      String nextName, String nextHHMM, DateTime date) {
    final start = _parseHHMM(startHHMM, date);
    final end = _parseHHMM(nextHHMM, date);
    if (start == null || end == null) return null;
    return DrikTiming(name: name, start: start, end: end);
  }

  static DateTime? _parseHHMM(String hhmm, DateTime date) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(date.year, date.month, date.day, hour % 24, minute);
  }
}
