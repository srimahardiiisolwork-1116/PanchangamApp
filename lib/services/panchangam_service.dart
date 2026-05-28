import '../models/birth_details.dart';
import '../models/enums.dart';
import '../models/panchangam_models.dart';
import '../services/panchang_engine.dart';
import 'astro_math.dart';

class PanchangamService {
  static const List<String> _nakshatraNames = [
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

  static const List<String> _tithiNames = [
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

  // Compute Nakshatra index (0..26) from lunar longitude
  int nakshatraIndexFromLongitude(double moonLon) {
    final idx = (Astro.normalizeAngle(moonLon) / Nakshatra.spanDegrees).floor();
    return idx.clamp(0, 26);
  }

  // Compute Tithi index (0..29) based on Moon - Sun angular separation
  int tithiIndexFromLongitudes(double moonLon, double sunLon) {
    final diff = Astro.normalizeAngle(moonLon - sunLon);
    final idx = (diff / Tithi.spanDegrees).floor();
    return idx.clamp(0, 29);
  }

  Paksha pakshaFromTithi(int tithiIndex) {
    return tithiIndex < 15 ? Paksha.shukla : Paksha.krishna;
  }

  // Approx Telugu month using Sun's longitude and new moon proximity
  String teluguMonthFrom(double sunLon, int tithiIndex) {
    // Month roughly tracks Sun's sign after new moon. Map solar longitude to month index.
    final solarMonthIndex =
        ((Astro.normalizeAngle(sunLon) / 30.0).floor()) % 12;
    // In Shukla Paksha, the lunar month name equals the solar month index + 1.
    // In Krishna Paksha, keep same month as started at Purnima/Amavasya boundary.
    final idx = solarMonthIndex; // simplified but consistent
    return TeluguMonth.names[idx];
  }

  static Map<String, dynamic> calculatePanchang(
    BirthDetails birthDetails,
    double timezoneOffset,
  ) {
    final birthLocal = DateTime(
      birthDetails.year,
      birthDetails.month,
      birthDetails.day,
      birthDetails.hour,
      birthDetails.minute,
      birthDetails.second,
    );

    final jdUtc = Astro.julianDayFromLocal(birthLocal, timezoneOffset);
    final panchang = PanchangEngine.panchangAtUTC_fromJD(jdUtc);

    return {
      'nakshatra': panchang['nakshatra'], // Return the number (1-27)
      'nakshatra_name': _nakshatraNames[
          panchang['nakshatra'] - 1], // Return the name separately
      'tithi': panchang['tithi_number'], // Return the number (1-30)
      'tithi_name': _tithiNames[
          panchang['tithi_number'] - 1], // Return the name separately
      'paksha': panchang['paksha'],
      'lunar_month': panchang['lunar_month'],
      'tzOffset': timezoneOffset,
      'julianDay': panchang['julian_day'],
      'ayanamsa': panchang['ayanamsa'],
      'sunLongitudeTropical': panchang['sun_longitude_tropical'],
      'moonLongitudeTropical': panchang['moon_longitude_tropical'],
      'sunLongitudeSidereal': panchang['sun_longitude_sidereal'],
      'moonLongitudeSidereal': panchang['moon_longitude_sidereal'],
    };
  }

  // Core calculation for a local birth input
  PanchangamResult calculate(BirthInput input) {
    final birthDetails = BirthDetails(
      year: input.dateTime.year,
      month: input.dateTime.month,
      day: input.dateTime.day,
      hour: input.dateTime.hour,
      minute: input.dateTime.minute,
      second: input.dateTime.second,
      timezone: input.tzOffsetHours,
      latitude: input.latitude,
      longitude: input.longitude,
    );

    final panchang = calculatePanchang(birthDetails, input.tzOffsetHours);

    final nIdx = nakshatraIndexFromLongitude(panchang['moonLongitudeSidereal']);
    final tIdx = tithiIndexFromLongitudes(
        panchang['moonLongitudeSidereal'], panchang['sunLongitudeSidereal']);
    final paksha = pakshaFromTithi(tIdx);
    final month = teluguMonthFrom(panchang['sunLongitudeSidereal'], tIdx);

    return PanchangamResult(
      nakshatraName: Nakshatra.names[nIdx],
      nakshatraIndex: nIdx,
      tithiName: _tithiNameWithPaksha(tIdx),
      tithiIndex: tIdx,
      paksha: paksha,
      teluguMonth: month,
    );
  }

  String _tithiNameWithPaksha(int tIdx) {
    final p = pakshaFromTithi(tIdx);
    final baseIdx = tIdx % 15;
    String base;
    if (baseIdx == 14) {
      base = p == Paksha.shukla ? 'Purnima' : 'Amavasya';
    } else {
      base = Tithi.names[baseIdx];
    }
    final pakshaName = p == Paksha.shukla ? 'Shukla' : 'Krishna';
    return '$pakshaName Paksha $base';
  }

  // Find next date in the current year when the same Nakshatra occurs in the same Telugu month
  BirthdayResults birthdaysForYear(BirthInput birth, int year) {
    final base = calculate(birth);
    final start = DateTime(year, 1, 1, 0, 0);
    final end = DateTime(year, 12, 31, 23, 59);

    final nextNakDate = _searchNextMatching(
        start,
        end,
        birth,
        (r) =>
            r.nakshatraIndex == base.nakshatraIndex &&
            r.teluguMonth == base.teluguMonth);

    final nextTithiDate = _searchNextMatching(
        start, end, birth, (r) => (r.tithiIndex == base.tithiIndex));

    return BirthdayResults(
      nakshatraBirthday: nextNakDate ?? start,
      tithiBirthday: nextTithiDate ?? start,
    );
  }

  // 1️⃣2️⃣ FIND TITHI BIRTHDAY IN YEAR
  static DateTime? findTithiBirthday(
    int year,
    double lat,
    double lon,
    int birthTithi,
    String birthMonth,
    double Function(DateTime, double, double) sunriseUTC,
  ) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);

    for (DateTime day = start;
        day.isBefore(end) || day.isAtSameMomentAs(end);
        day = day.add(const Duration(days: 1))) {
      final sunriseUT = sunriseUTC(day, lat, lon);
      final panchang = PanchangEngine.panchangAtSunrise(
        day.year,
        day.month,
        day.day,
        sunriseUT,
      );

      if (panchang['tithi_number'] == birthTithi &&
          panchang['lunar_month'] == birthMonth) {
        return day;
      }
    }
    return null;
  }

  // 1️⃣3️⃣ FIND NAKSHATRA BIRTHDAY
  static DateTime? findNakshatraBirthday(
    int year,
    double lat,
    double lon,
    int birthNak,
    double Function(DateTime, double, double) sunriseUTC,
  ) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);

    for (DateTime day = start;
        day.isBefore(end) || day.isAtSameMomentAs(end);
        day = day.add(const Duration(days: 1))) {
      final sunriseUT = sunriseUTC(day, lat, lon);
      final panchang = PanchangEngine.panchangAtSunrise(
        day.year,
        day.month,
        day.day,
        sunriseUT,
      );

      if (panchang['nakshatra'] == birthNak) {
        return day;
      }
    }
    return null;
  }

  DateTime? _searchNextMatching(DateTime start, DateTime end, BirthInput birth,
      bool Function(PanchangamResult) predicate) {
    // Step through days, refine by binary search around boundary
    DateTime? found;
    var current = start;
    while (current.isBefore(end)) {
      final r = calculate(birth.copyWith(dateTime: current));
      if (predicate(r)) {
        found = _refineToDay(birth, current, predicate);
        break;
      }
      current = current.add(const Duration(days: 1));
    }
    return found;
  }
}

extension on BirthInput {
  BirthInput copyWith(
      {DateTime? dateTime,
      double? latitude,
      double? longitude,
      double? tzOffsetHours}) {
    return BirthInput(
      dateTime: dateTime ?? this.dateTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tzOffsetHours: tzOffsetHours ?? this.tzOffsetHours,
    );
  }
}

extension _Refine on PanchangamService {
  DateTime _refineToDay(BirthInput birth, DateTime day,
      bool Function(PanchangamResult) predicate) {
    // Binary search over the 24 hours to find the first matching instant
    var lo = DateTime(day.year, day.month, day.day, 0, 0);
    var hi = DateTime(day.year, day.month, day.day, 23, 59);
    DateTime best = lo;
    for (int i = 0; i < 20; i++) {
      final mid = lo
          .add(Duration(milliseconds: (hi.difference(lo).inMilliseconds ~/ 2)));
      final r = calculate(birth.copyWith(dateTime: mid));
      if (predicate(r)) {
        best = mid;
        hi = mid.subtract(const Duration(minutes: 1));
      } else {
        lo = mid.add(const Duration(minutes: 1));
      }
    }
    return best;
  }
}
