import '../models/birth_details.dart';
import '../services/panchang_engine.dart';

class PanchangTimingService {
  static DateTime _toUtcFromLocal(DateTime localTime, double tzOffsetHours) {
    final offsetMinutes = (tzOffsetHours * 60).round();
    return localTime.subtract(Duration(minutes: offsetMinutes));
  }

  static int _tithiAtLocal(BirthDetails birthDetails, DateTime localTime) {
    final utc = _toUtcFromLocal(localTime, birthDetails.timezone);
    final p = PanchangEngine.panchangAtUTC(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      0,
    );
    return p['tithi_number'] as int;
  }

  static int _nakshatraAtLocal(BirthDetails birthDetails, DateTime localTime) {
    final utc = _toUtcFromLocal(localTime, birthDetails.timezone);
    final p = PanchangEngine.panchangAtUTC(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      0,
    );
    return p['nakshatra'] as int;
  }

  static DateTime _findTransitionMinute({
    required DateTime fromLocal,
    required DateTime toLocal,
    required bool Function(DateTime t) isNewValueAt,
  }) {
    var lo = fromLocal;
    var hi = toLocal;
    while (hi.difference(lo).inMinutes > 1) {
      final mid =
          lo.add(Duration(minutes: (hi.difference(lo).inMinutes / 2).floor()));
      if (isNewValueAt(mid)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return isNewValueAt(lo) ? lo : hi;
  }

  // Get detailed timing for Tithi and Nakshatra on a specific date
  static Map<String, dynamic> getTithiNakshatraTiming(
    BirthDetails birthDetails,
    DateTime targetDate,
  ) {
    final List<Map<String, dynamic>> tithiTimings = [];
    final List<Map<String, dynamic>> nakshatraTimings = [];

    final dayStartLocal =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    final windowStartLocal = dayStartLocal.subtract(const Duration(days: 1));
    final windowEndLocal = dayStartLocal.add(const Duration(days: 2));

    DateTime? prevTimeLocal;
    int? prevTithi;
    int? prevNakshatra;

    for (DateTime currentTimeLocal = windowStartLocal;
        currentTimeLocal.isBefore(windowEndLocal);
        currentTimeLocal = currentTimeLocal.add(const Duration(minutes: 15))) {
      final currentTithi = _tithiAtLocal(birthDetails, currentTimeLocal);
      final currentNakshatra =
          _nakshatraAtLocal(birthDetails, currentTimeLocal);

      if (prevTimeLocal == null) {
        tithiTimings.add({
          'tithi': currentTithi,
          'tithi_name': _getTithiName(currentTithi),
          'start_time': currentTimeLocal,
          'end_time': null,
        });
        nakshatraTimings.add({
          'nakshatra': currentNakshatra,
          'nakshatra_name': _getNakshatraName(currentNakshatra),
          'start_time': currentTimeLocal,
          'end_time': null,
        });
        prevTimeLocal = currentTimeLocal;
        prevTithi = currentTithi;
        prevNakshatra = currentNakshatra;
        continue;
      }

      if (prevTithi != currentTithi) {
        final transition = _findTransitionMinute(
          fromLocal: prevTimeLocal,
          toLocal: currentTimeLocal,
          isNewValueAt: (t) => _tithiAtLocal(birthDetails, t) == currentTithi,
        );
        tithiTimings.last['end_time'] = transition;
        tithiTimings.add({
          'tithi': currentTithi,
          'tithi_name': _getTithiName(currentTithi),
          'start_time': transition,
          'end_time': null,
        });
      }

      if (prevNakshatra != currentNakshatra) {
        final transition = _findTransitionMinute(
          fromLocal: prevTimeLocal,
          toLocal: currentTimeLocal,
          isNewValueAt: (t) =>
              _nakshatraAtLocal(birthDetails, t) == currentNakshatra,
        );
        nakshatraTimings.last['end_time'] = transition;
        nakshatraTimings.add({
          'nakshatra': currentNakshatra,
          'nakshatra_name': _getNakshatraName(currentNakshatra),
          'start_time': transition,
          'end_time': null,
        });
      }

      prevTimeLocal = currentTimeLocal;
      prevTithi = currentTithi;
      prevNakshatra = currentNakshatra;
    }

    // Last Tithi ends at window end
    if (tithiTimings.isNotEmpty) {
      tithiTimings.last['end_time'] = windowEndLocal;
    }

    // Last Nakshatra ends at window end
    if (nakshatraTimings.isNotEmpty) {
      nakshatraTimings.last['end_time'] = windowEndLocal;
    }

    return {
      'date': targetDate,
      'tithi_timings': tithiTimings,
      'nakshatra_timings': nakshatraTimings,
    };
  }

  // Get timing for multiple days (useful for checking March 25-26, 2001)
  static List<Map<String, dynamic>> getMultiDayTiming(
    BirthDetails birthDetails,
    DateTime startDate,
    int numberOfDays,
  ) {
    final List<Map<String, dynamic>> results = [];

    for (int i = 0; i < numberOfDays; i++) {
      final currentDate =
          DateTime(startDate.year, startDate.month, startDate.day + i);
      final timing = getTithiNakshatraTiming(birthDetails, currentDate);
      results.add(timing);
    }

    return results;
  }

  static String _getTithiName(int tithiNumber) {
    final tithiNames = [
      'Shukla Prathama',
      'Shukla Dwitiya',
      'Shukla Tritiya',
      'Shukla Chaturthi',
      'Shukla Panchami',
      'Shukla Shashthi',
      'Shukla Saptami',
      'Shukla Ashtami',
      'Shukla Navami',
      'Shukla Dashami',
      'Shukla Ekadashi',
      'Shukla Dwadashi',
      'Shukla Trayodashi',
      'Shukla Chaturdashi',
      'Purnima',
      'Krishna Prathama',
      'Krishna Dwitiya',
      'Krishna Tritiya',
      'Krishna Chaturthi',
      'Krishna Panchami',
      'Krishna Shashthi',
      'Krishna Saptami',
      'Krishna Ashtami',
      'Krishna Navami',
      'Krishna Dashami',
      'Krishna Ekadashi',
      'Krishna Dwadashi',
      'Krishna Trayodashi',
      'Krishna Chaturdashi',
      'Amavasya'
    ];
    return tithiNames[(tithiNumber - 1) % 30];
  }

  static String _getNakshatraName(int nakshatraNumber) {
    final nakshatraNames = [
      'Ashwini',
      'Bharani',
      'Krittika',
      'Rohini',
      'Mrigashirsha',
      'Ardra',
      'Punarvasu',
      'Pushya',
      'Ashlesha',
      'Magha',
      'Purva Phalguni',
      'Uttara Phalguni',
      'Hasta',
      'Chitra',
      'Swati',
      'Vishakha',
      'Anuradha',
      'Jyeshtha',
      'Mula',
      'Purva Ashadha',
      'Uttara Ashadha',
      'Shravana',
      'Dhanishta',
      'Shatabhisha',
      'Purva Bhadrapada',
      'Uttara Bhadrapada',
      'Revati'
    ];
    return nakshatraNames[(nakshatraNumber - 1) % 27];
  }
}
