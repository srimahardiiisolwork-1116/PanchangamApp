import '../models/birth_details.dart';
import '../services/panchang_engine.dart';
import '../services/sunrise_service.dart';
import '../services/panchangam_service.dart';
import '../services/panchang_timing_service.dart';

class VedicBirthdayService {
  // Find all dates in target year where both birth Tithi and Nakshatra match
  static List<Map<String, dynamic>> findVedicBirthdays(
      BirthDetails birthDetails, double timezoneOffset, int targetYear,
      {bool allowClosestMatch = false} // New parameter for fallback
      ) {
    List<Map<String, dynamic>> matches = [];

    // Get birth Tithi, Nakshatra, and Telugu month using PanchangamService for proper sunrise calculation
    final birthPanchang =
        PanchangamService.calculatePanchang(birthDetails, timezoneOffset);
    final birthTithi = birthPanchang['tithi'] as int;
    final birthNakshatra = birthPanchang['nakshatra'] as int;
    final birthLunarMonth = birthPanchang['lunar_month'] as String;

    // First try to find exact matches
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = _daysInMonth(targetYear, month);

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime currentDate = DateTime(targetYear, month, day);
        final targetMinutes = birthDetails.hour * 60 + birthDetails.minute;
        Map<String, dynamic>? bestMatch;
        int bestDiffMinutes = 999999;

        // Check every 30 minutes during the day and pick the closest time to the birth time-of-day
        for (int hour = 0; hour < 24; hour++) {
          for (int minute = 0; minute < 60; minute += 30) {
            final currentTimeLocal =
                DateTime(targetYear, month, day, hour, minute);
            final currentTimeUtc =
                _toUtcFromLocal(currentTimeLocal, timezoneOffset);
            final panchang = PanchangEngine.panchangAtUTC(
              currentTimeUtc.year,
              currentTimeUtc.month,
              currentTimeUtc.day,
              currentTimeUtc.hour,
              currentTimeUtc.minute,
              0,
            );

            final currentTithi = panchang['tithi_number'] as int;
            final currentNakshatra = panchang['nakshatra'] as int;
            final currentLunarMonth = panchang['lunar_month'] as String;

            // Check if Tithi, Nakshatra, and Telugu month all match
            if (currentTithi == birthTithi &&
                currentNakshatra == birthNakshatra &&
                currentLunarMonth == birthLunarMonth) {
              final diffMinutes = (hour * 60 + minute - targetMinutes).abs();
              if (diffMinutes < bestDiffMinutes) {
                bestDiffMinutes = diffMinutes;
                bestMatch = {
                  'date': currentDate,
                  'time': currentTimeLocal,
                  'tithi': currentTithi,
                  'nakshatra': currentNakshatra,
                  'tithi_name': _getTithiName(currentTithi),
                  'tithi_name_te': _getTithiNameTelugu(currentTithi),
                  'nakshatra_name': _getNakshatraName(currentNakshatra),
                  'nakshatra_name_te':
                      _getNakshatraNameTelugu(currentNakshatra),
                  'lunar_month': currentLunarMonth,
                  'is_exact_match': true,
                  'match_type': 'Exact Match',
                };
              }
            }
          }
        }

        if (bestMatch != null) {
          matches.add(bestMatch);
        }
      }
    }

    // If no exact matches and fallback is enabled, find closest matches
    if (matches.isEmpty && allowClosestMatch) {
      matches.addAll(_findClosestMatches(targetYear, birthTithi, birthNakshatra,
          birthLunarMonth, timezoneOffset));
    }

    return matches;
  }

  // Helper method to get Tithi name
  static String _getTithiName(int tithiIndex) {
    const List<String> tithiNames = [
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

    // Adjust for 1-based indexing
    final adjustedIndex = tithiIndex - 1;
    if (adjustedIndex >= 0 && adjustedIndex < tithiNames.length) {
      return tithiNames[adjustedIndex];
    }
    return 'Unknown';
  }

  static String _getTithiNameTelugu(int tithiIndex) {
    const List<String> tithiNamesTe = [
      'Sukla Padyami',
      'Sukla Vidiya',
      'Sukla Tadiya',
      'Sukla Chavithi',
      'Sukla Panchami',
      'Sukla Shashthi',
      'Sukla Saptami',
      'Sukla Ashtami',
      'Sukla Navami',
      'Sukla Dashami',
      'Sukla Ekadashi',
      'Sukla Dwadashi',
      'Sukla Trayodashi',
      'Sukla Chaturdashi',
      'Pournami',
      'Krishna Padyami',
      'Krishna Vidiya',
      'Krishna Tadiya',
      'Krishna Chavithi',
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

    final adjustedIndex = tithiIndex - 1;
    if (adjustedIndex >= 0 && adjustedIndex < tithiNamesTe.length) {
      return tithiNamesTe[adjustedIndex];
    }
    return 'Unknown';
  }

  // Helper method to get Nakshatra name
  static String _getNakshatraName(int nakshatraIndex) {
    const List<String> nakshatraNames = [
      'Ashwini',
      'Bharani',
      'Krittika',
      'Rohini',
      'Mrigashira',
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

    // Adjust for 1-based indexing
    final adjustedIndex = nakshatraIndex - 1;
    if (adjustedIndex >= 0 && adjustedIndex < nakshatraNames.length) {
      return nakshatraNames[adjustedIndex];
    }
    return 'Unknown';
  }

  static String _getNakshatraNameTelugu(int nakshatraIndex) {
    const List<String> nakshatraNamesTe = [
      'Ashwini',
      'Bharani',
      'Krittika',
      'Rohini',
      'Mrugashira',
      'Ardra',
      'Punarvasu',
      'Pushyami',
      'Ashlesha',
      'Makha',
      'Pubba',
      'Uttara',
      'Hasta',
      'Chitta',
      'Swati',
      'Vishakha',
      'Anuradha',
      'Jyeshta',
      'Moola',
      'Poorvashada',
      'Uttarashada',
      'Shravana',
      'Dhanishta',
      'Shatabhisha',
      'Poorvabhadra',
      'Uttarabhadra',
      'Revati'
    ];

    final adjustedIndex = nakshatraIndex - 1;
    if (adjustedIndex >= 0 && adjustedIndex < nakshatraNamesTe.length) {
      return nakshatraNamesTe[adjustedIndex];
    }
    return 'Unknown';
  }

  static DateTime _toUtcFromLocal(DateTime localTime, double tzOffsetHours) {
    final offsetMinutes = (tzOffsetHours * 60).round();
    return localTime.subtract(Duration(minutes: offsetMinutes));
  }

  // Get timing details for a specific match
  static Map<String, dynamic> getMatchTiming(
    BirthDetails birthDetails,
    DateTime matchDate,
    DateTime matchTimeLocal,
    String matchType,
  ) {
    final timing =
        PanchangTimingService.getTithiNakshatraTiming(birthDetails, matchDate);

    // Get birth details for comparison
    final birthPanchang = PanchangamService.calculatePanchang(
        birthDetails, birthDetails.timezone);
    final birthTithi = birthPanchang['tithi'] as int;
    final birthNakshatra = birthPanchang['nakshatra'] as int;
    final birthLunarMonth = birthPanchang['lunar_month'] as String;

    // Find the specific Tithi and Nakshatra that match the birth details
    Map<String, dynamic>? matchingTithi;
    Map<String, dynamic>? matchingNakshatra;

    final tithiTimings = timing['tithi_timings'] as List;
    final nakshatraTimings = timing['nakshatra_timings'] as List;

    // Find matching Tithi interval that contains the match time
    if (matchType.contains('Tithi')) {
      for (final tithi in tithiTimings) {
        if (tithi['tithi'] != birthTithi) continue;
        final start = tithi['start_time'] as DateTime?;
        final end = tithi['end_time'] as DateTime?;
        if (start == null || end == null) continue;
        final contains = (matchTimeLocal.isAtSameMomentAs(start) ||
                matchTimeLocal.isAfter(start)) &&
            matchTimeLocal.isBefore(end);
        if (contains) {
          matchingTithi = tithi as Map<String, dynamic>;
          break;
        }
      }

      // Fallback: pick first matching tithi if a containing interval wasn't found
      matchingTithi ??= tithiTimings
          .cast<Map<String, dynamic>>()
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (t) => t != null && t['tithi'] == birthTithi,
            orElse: () => null,
          );
    }

    // Find matching Nakshatra interval that contains the match time
    if (matchType.contains('Nakshatra')) {
      for (final nakshatra in nakshatraTimings) {
        if (nakshatra['nakshatra'] != birthNakshatra) continue;
        final start = nakshatra['start_time'] as DateTime?;
        final end = nakshatra['end_time'] as DateTime?;
        if (start == null || end == null) continue;
        final contains = (matchTimeLocal.isAtSameMomentAs(start) ||
                matchTimeLocal.isAfter(start)) &&
            matchTimeLocal.isBefore(end);
        if (contains) {
          matchingNakshatra = nakshatra as Map<String, dynamic>;
          break;
        }
      }

      // Fallback: pick first matching nakshatra if a containing interval wasn't found
      matchingNakshatra ??= nakshatraTimings
          .cast<Map<String, dynamic>>()
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (n) => n != null && n['nakshatra'] == birthNakshatra,
            orElse: () => null,
          );
    }

    return {
      'match_date': matchDate,
      'match_time': matchTimeLocal,
      'match_type': matchType,
      'tithi_timing': matchingTithi,
      'nakshatra_timing': matchingNakshatra,
      'birth_tithi': birthTithi,
      'birth_nakshatra': birthNakshatra,
      'birth_lunar_month': birthLunarMonth,
    };
  }

  // Find dates with matching Tithi + Nakshatra (different month is OK)
  static List<Map<String, dynamic>> findTithiNakshatraMatches(
    BirthDetails birthDetails,
    double timezoneOffset,
    int targetYear,
  ) {
    List<Map<String, dynamic>> matches = [];

    // Get birth Tithi and Nakshatra
    final birthPanchang =
        PanchangamService.calculatePanchang(birthDetails, timezoneOffset);
    final birthTithi = birthPanchang['tithi'] as int;
    final birthNakshatra = birthPanchang['nakshatra'] as int;

    for (int month = 1; month <= 12; month++) {
      final daysInMonth = _daysInMonth(targetYear, month);

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime currentDate = DateTime(targetYear, month, day);

        final targetMinutes = birthDetails.hour * 60 + birthDetails.minute;
        Map<String, dynamic>? bestMatch;
        int bestDiffMinutes = 999999;

        for (int hour = 0; hour < 24; hour++) {
          for (int minute = 0; minute < 60; minute += 30) {
            final currentTimeLocal =
                DateTime(targetYear, month, day, hour, minute);
            final currentTimeUtc =
                _toUtcFromLocal(currentTimeLocal, timezoneOffset);
            final panchang = PanchangEngine.panchangAtUTC(
              currentTimeUtc.year,
              currentTimeUtc.month,
              currentTimeUtc.day,
              currentTimeUtc.hour,
              currentTimeUtc.minute,
              0,
            );

            final currentTithi = panchang['tithi_number'] as int;
            final currentNakshatra = panchang['nakshatra'] as int;

            // Check if Tithi + Nakshatra match
            if (currentTithi == birthTithi &&
                currentNakshatra == birthNakshatra) {
              final diffMinutes = (hour * 60 + minute - targetMinutes).abs();
              if (diffMinutes < bestDiffMinutes) {
                bestDiffMinutes = diffMinutes;
                bestMatch = {
                  'date': currentDate,
                  'time': currentTimeLocal,
                  'tithi': currentTithi,
                  'nakshatra': currentNakshatra,
                  'tithi_name': _getTithiName(currentTithi),
                  'tithi_name_te': _getTithiNameTelugu(currentTithi),
                  'nakshatra_name': _getNakshatraName(currentNakshatra),
                  'nakshatra_name_te':
                      _getNakshatraNameTelugu(currentNakshatra),
                  'lunar_month': panchang['lunar_month'],
                  'match_type': 'Tithi+Nakshatra',
                };
              }
            }
          }
        }

        if (bestMatch != null) {
          matches.add(bestMatch);
        }

        // Limit to 3 results to avoid too many duplicates
        if (matches.length >= 3) {
          break;
        }
      }

      // Limit to 3 results to avoid too many duplicates
      if (matches.length >= 3) {
        break;
      }
    }

    return matches;
  }

  // Find dates with matching Tithi + Telugu Month
  static List<Map<String, dynamic>> findTithiMonthMatches(
    BirthDetails birthDetails,
    double timezoneOffset,
    int targetYear,
  ) {
    List<Map<String, dynamic>> matches = [];

    // Get birth Tithi and Telugu month
    final birthPanchang =
        PanchangamService.calculatePanchang(birthDetails, timezoneOffset);
    final birthTithi = birthPanchang['tithi'] as int;
    final birthLunarMonth = birthPanchang['lunar_month'] as String;

    for (int month = 1; month <= 12; month++) {
      final daysInMonth = _daysInMonth(targetYear, month);

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime currentDate = DateTime(targetYear, month, day);

        final targetMinutes = birthDetails.hour * 60 + birthDetails.minute;
        Map<String, dynamic>? bestMatch;
        int bestDiffMinutes = 999999;

        for (int hour = 0; hour < 24; hour++) {
          for (int minute = 0; minute < 60; minute += 30) {
            final currentTimeLocal =
                DateTime(targetYear, month, day, hour, minute);
            final currentTimeUtc =
                _toUtcFromLocal(currentTimeLocal, timezoneOffset);
            final panchang = PanchangEngine.panchangAtUTC(
              currentTimeUtc.year,
              currentTimeUtc.month,
              currentTimeUtc.day,
              currentTimeUtc.hour,
              currentTimeUtc.minute,
              0,
            );

            final currentTithi = panchang['tithi_number'] as int;
            final currentLunarMonth = panchang['lunar_month'] as String;

            // Check if Tithi + Telugu Month match
            if (currentTithi == birthTithi &&
                currentLunarMonth == birthLunarMonth) {
              final diffMinutes = (hour * 60 + minute - targetMinutes).abs();
              if (diffMinutes < bestDiffMinutes) {
                bestDiffMinutes = diffMinutes;
                bestMatch = {
                  'date': currentDate,
                  'time': currentTimeLocal,
                  'tithi': currentTithi,
                  'nakshatra': panchang['nakshatra'],
                  'tithi_name': _getTithiName(currentTithi),
                  'tithi_name_te': _getTithiNameTelugu(currentTithi),
                  'nakshatra_name': _getNakshatraName(panchang['nakshatra']),
                  'nakshatra_name_te':
                      _getNakshatraNameTelugu(panchang['nakshatra']),
                  'lunar_month': currentLunarMonth,
                  'match_type': 'Tithi+Month',
                };
              }
            }
          }
        }

        if (bestMatch != null) {
          matches.add(bestMatch);
        }

        // Limit to 3 results to avoid too many duplicates
        if (matches.length >= 3) {
          break;
        }
      }

      // Limit to 3 results to avoid too many duplicates
      if (matches.length >= 3) {
        break;
      }
    }

    return matches;
  }

  // Find dates with matching Nakshatra + Telugu Month
  static List<Map<String, dynamic>> findNakshatraMonthMatches(
    BirthDetails birthDetails,
    double timezoneOffset,
    int targetYear,
  ) {
    List<Map<String, dynamic>> matches = [];

    // Get birth Nakshatra and Telugu month
    final birthPanchang =
        PanchangamService.calculatePanchang(birthDetails, timezoneOffset);
    final birthNakshatra = birthPanchang['nakshatra'] as int;
    final birthLunarMonth = birthPanchang['lunar_month'] as String;

    for (int month = 1; month <= 12; month++) {
      final daysInMonth = _daysInMonth(targetYear, month);

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime currentDate = DateTime(targetYear, month, day);

        final targetMinutes = birthDetails.hour * 60 + birthDetails.minute;
        Map<String, dynamic>? bestMatch;
        int bestDiffMinutes = 999999;

        for (int hour = 0; hour < 24; hour++) {
          for (int minute = 0; minute < 60; minute += 30) {
            final currentTimeLocal =
                DateTime(targetYear, month, day, hour, minute);
            final currentTimeUtc =
                _toUtcFromLocal(currentTimeLocal, timezoneOffset);
            final panchang = PanchangEngine.panchangAtUTC(
              currentTimeUtc.year,
              currentTimeUtc.month,
              currentTimeUtc.day,
              currentTimeUtc.hour,
              currentTimeUtc.minute,
              0,
            );

            final currentNakshatra = panchang['nakshatra'] as int;
            final currentLunarMonth = panchang['lunar_month'] as String;

            // Check if Nakshatra + Telugu Month match
            if (currentNakshatra == birthNakshatra &&
                currentLunarMonth == birthLunarMonth) {
              final diffMinutes = (hour * 60 + minute - targetMinutes).abs();
              if (diffMinutes < bestDiffMinutes) {
                bestDiffMinutes = diffMinutes;
                bestMatch = {
                  'date': currentDate,
                  'time': currentTimeLocal,
                  'tithi': panchang['tithi_number'],
                  'nakshatra': currentNakshatra,
                  'tithi_name': _getTithiName(panchang['tithi_number']),
                  'tithi_name_te':
                      _getTithiNameTelugu(panchang['tithi_number']),
                  'nakshatra_name': _getNakshatraName(currentNakshatra),
                  'nakshatra_name_te':
                      _getNakshatraNameTelugu(currentNakshatra),
                  'lunar_month': currentLunarMonth,
                  'match_type': 'Nakshatra+Month',
                };
              }
            }
          }
        }

        if (bestMatch != null) {
          matches.add(bestMatch);
        }

        // Limit to 3 results to avoid too many duplicates
        if (matches.length >= 3) {
          break;
        }
      }

      // Limit to 3 results to avoid too many duplicates
      if (matches.length >= 3) {
        break;
      }
    }

    return matches;
  }

  static List<Map<String, dynamic>> _findClosestMatches(
    int targetYear,
    int birthTithi,
    int birthNakshatra,
    String birthLunarMonth,
    double timezoneOffset,
  ) {
    List<Map<String, dynamic>> allMatches = [];

    // Priority 1: Find dates with matching Tithi + Nakshatra (different month is OK)
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = _daysInMonth(targetYear, month);

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime currentDate = DateTime(targetYear, month, day);

        for (int hour = 0; hour < 24; hour++) {
          for (int minute = 0; minute < 60; minute += 30) {
            final currentTimeLocal =
                DateTime(targetYear, month, day, hour, minute);
            final currentTimeUtc =
                _toUtcFromLocal(currentTimeLocal, timezoneOffset);
            final panchang = PanchangEngine.panchangAtUTC(
              currentTimeUtc.year,
              currentTimeUtc.month,
              currentTimeUtc.day,
              currentTimeUtc.hour,
              currentTimeUtc.minute,
              0,
            );

            final currentTithi = panchang['tithi_number'] as int;
            final currentNakshatra = panchang['nakshatra'] as int;

            // Check if Tithi + Nakshatra match (ignore month for closest)
            if (currentTithi == birthTithi &&
                currentNakshatra == birthNakshatra) {
              allMatches.add({
                'date': currentDate,
                'time': currentTimeLocal,
                'tithi': currentTithi,
                'nakshatra': currentNakshatra,
                'tithi_name': _getTithiName(currentTithi),
                'nakshatra_name': _getNakshatraName(currentNakshatra),
                'lunar_month': panchang['lunar_month'],
                'is_exact_match': false,
                'match_type': 'Tithi+Nakshatra',
                'priority': 1,
              });
              return [allMatches.first]; // Return first Tithi+Nakshatra match
            }
          }
        }
      }
    }

    // Priority 2: If no Tithi+Nakshatra match, find Tithi + Telugu Month match
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = _daysInMonth(targetYear, month);

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime currentDate = DateTime(targetYear, month, day);

        for (int hour = 0; hour < 24; hour++) {
          for (int minute = 0; minute < 60; minute += 30) {
            final currentTimeLocal =
                DateTime(targetYear, month, day, hour, minute);
            final currentTimeUtc =
                _toUtcFromLocal(currentTimeLocal, timezoneOffset);
            final panchang = PanchangEngine.panchangAtUTC(
              currentTimeUtc.year,
              currentTimeUtc.month,
              currentTimeUtc.day,
              currentTimeUtc.hour,
              currentTimeUtc.minute,
              0,
            );

            final currentTithi = panchang['tithi_number'] as int;
            final currentLunarMonth = panchang['lunar_month'] as String;

            // Check if Tithi + Telugu Month match
            if (currentTithi == birthTithi &&
                currentLunarMonth == birthLunarMonth) {
              allMatches.add({
                'date': currentDate,
                'time': currentTimeLocal,
                'tithi': currentTithi,
                'nakshatra': panchang['nakshatra'],
                'tithi_name': _getTithiName(currentTithi),
                'nakshatra_name': _getNakshatraName(panchang['nakshatra']),
                'lunar_month': currentLunarMonth,
                'is_exact_match': false,
                'match_type': 'Tithi+Month',
                'priority': 2,
              });
              return [allMatches.first]; // Return first Tithi+Month match
            }
          }
        }
      }
    }

    // Priority 3: If no Tithi+Month match, find Nakshatra + Telugu Month match
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = _daysInMonth(targetYear, month);

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime currentDate = DateTime(targetYear, month, day);

        for (int hour = 0; hour < 24; hour++) {
          for (int minute = 0; minute < 60; minute += 30) {
            final currentTimeLocal =
                DateTime(targetYear, month, day, hour, minute);
            final currentTimeUtc =
                _toUtcFromLocal(currentTimeLocal, timezoneOffset);
            final panchang = PanchangEngine.panchangAtUTC(
              currentTimeUtc.year,
              currentTimeUtc.month,
              currentTimeUtc.day,
              currentTimeUtc.hour,
              currentTimeUtc.minute,
              0,
            );

            final currentNakshatra = panchang['nakshatra'] as int;
            final currentLunarMonth = panchang['lunar_month'] as String;

            // Check if Nakshatra + Telugu Month match
            if (currentNakshatra == birthNakshatra &&
                currentLunarMonth == birthLunarMonth) {
              allMatches.add({
                'date': currentDate,
                'time': currentTimeLocal,
                'tithi': panchang['tithi_number'],
                'nakshatra': currentNakshatra,
                'tithi_name': _getTithiName(panchang['tithi_number']),
                'nakshatra_name': _getNakshatraName(currentNakshatra),
                'lunar_month': currentLunarMonth,
                'is_exact_match': false,
                'match_type': 'Nakshatra+Month',
                'priority': 3,
              });
              return [allMatches.first]; // Return first Nakshatra+Month match
            }
          }
        }
      }
    }

    return [];
  }

  static List<DateTime> findTithiBirthdays(
    BirthDetails birthDetails,
    double timezoneOffset,
    int targetYear,
  ) {
    List<DateTime> matches = [];

    // Get birth Tithi and lunar month
    final birthPanchang =
        PanchangamService.calculatePanchang(birthDetails, timezoneOffset);
    final birthTithi = birthPanchang['tithi'] as int; // Use the numeric field
    final birthLunarMonth = birthPanchang['lunar_month'] as String;

    // Use the PanchangamService method with sunrise calculation
    final match = PanchangamService.findTithiBirthday(
      targetYear,
      birthDetails.latitude,
      birthDetails.longitude,
      birthTithi,
      birthLunarMonth,
      SunriseService.accurateSunriseUTC,
    );

    if (match != null) {
      matches.add(match);
    }

    return matches;
  }

  // Find Nakshatra birthdays in target year
  static List<DateTime> findNakshatraBirthdays(
    BirthDetails birthDetails,
    double timezoneOffset,
    int targetYear,
  ) {
    List<DateTime> matches = [];

    // Get birth Nakshatra and Telugu month
    final birthPanchang =
        PanchangamService.calculatePanchang(birthDetails, timezoneOffset);
    final birthNakshatra =
        birthPanchang['nakshatra'] as int; // Use the numeric field
    final birthLunarMonth =
        birthPanchang['lunar_month'] as String; // Get Telugu month

    // Scan through each day of the target year for Nakshatra + Telugu month match
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = _daysInMonth(targetYear, month);

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime currentDate = DateTime(targetYear, month, day);

        // Check at sunrise for traditional calculation
        final sunriseUT = SunriseService.accurateSunriseUTC(
            currentDate, birthDetails.latitude, birthDetails.longitude);
        final panchang = PanchangEngine.panchangAtSunrise(
          targetYear,
          month,
          day,
          sunriseUT,
        );

        final currentNakshatra = panchang['nakshatra'] as int;
        final currentLunarMonth = panchang['lunar_month'] as String;

        // Check if both Nakshatra and Telugu month match
        if (currentNakshatra == birthNakshatra &&
            currentLunarMonth == birthLunarMonth) {
          matches.add(currentDate);
          break; // Found the match for this Nakshatra in the correct month
        }
      }

      if (matches.isNotEmpty) {
        break; // Found the Nakshatra birthday, stop searching
      }
    }

    return matches;
  }

  static int _daysInMonth(int y, int m) {
    switch (m) {
      case 1:
      case 3:
      case 5:
      case 7:
      case 8:
      case 10:
      case 12:
        return 31;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      case 2:
        return y % 400 == 0 || (y % 4 == 0 && y % 100 != 0) ? 29 : 28;
      default:
        return 30;
    }
  }
}
