import 'enums.dart';

class BirthInput {
  final DateTime dateTime; // in local time of place
  final double latitude; // degrees
  final double longitude; // degrees East positive
  final double tzOffsetHours; // local time zone offset from UTC at birth

  BirthInput({
    required this.dateTime,
    required this.latitude,
    required this.longitude,
    required this.tzOffsetHours,
  });
}

class PanchangamResult {
  final String nakshatraName;
  final int nakshatraIndex; // 0..26
  final String tithiName;
  final int tithiIndex; // 0..29
  final Paksha paksha;
  final String teluguMonth;

  PanchangamResult({
    required this.nakshatraName,
    required this.nakshatraIndex,
    required this.tithiName,
    required this.tithiIndex,
    required this.paksha,
    required this.teluguMonth,
  });
}

class BirthdayResults {
  final DateTime nakshatraBirthday;
  final DateTime tithiBirthday;

  BirthdayResults({
    required this.nakshatraBirthday,
    required this.tithiBirthday,
  });
}

class BirthdayPair {
  final DateTime tithi;
  final DateTime nakshatra;
  BirthdayPair({required this.tithi, required this.nakshatra});
  Map<String, dynamic> toJson() => {
        'tithi': tithi.toIso8601String(),
        'nakshatra': nakshatra.toIso8601String(),
      };
  static BirthdayPair fromJson(Map<String, dynamic> j) => BirthdayPair(
        tithi: DateTime.parse(j['tithi']),
        nakshatra: DateTime.parse(j['nakshatra']),
      );
}

class YearlyBirthdays {
  final int year;
  final BirthdayPair pair;
  YearlyBirthdays({required this.year, required this.pair});
  Map<String, dynamic> toJson() => {
        'year': year,
        'pair': pair.toJson(),
      };
  static YearlyBirthdays fromJson(Map<String, dynamic> j) => YearlyBirthdays(
        year: j['year'],
        pair: BirthdayPair.fromJson(j['pair'] as Map<String, dynamic>),
      );
}
