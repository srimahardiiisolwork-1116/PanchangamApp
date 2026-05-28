import '../models/birth_details.dart';
// Sanskrit domain constants intentionally use their established names.
// ignore_for_file: constant_identifier_names

import 'astronomy_service.dart';
import 'astro_math.dart';

class PanchangService {
  final AstronomyService astronomy;
  PanchangService(this.astronomy);

  static const NAKSHATRAS = [
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
    'Dhanishtha',
    'Shatabhisha',
    'Purva Bhadrapada',
    'Uttara Bhadrapada',
    'Revati',
  ];

  static const TITHIS = [
    'Pratipada',
    'Dvitiya',
    'Tritiya',
    'Chaturthi',
    'Panchami',
    'Shashthi',
    'Saptami',
    'Ashtami',
    'Navami',
    'Dashami',
    'Ekadashi',
    'Dvadashi',
    'Trayodashi',
    'Chaturdashi',
    'Purnima',
    'Pratipada',
    'Dvitiya',
    'Tritiya',
    'Chaturthi',
    'Panchami',
    'Shashthi',
    'Saptami',
    'Ashtami',
    'Navami',
    'Dashami',
    'Ekadashi',
    'Dvadashi',
    'Trayodashi',
    'Chaturdashi',
    'Amavasya',
  ];

  String calculateNakshatra(double moonLong) {
    int index = (moonLong / (360 / 27)).floor();
    if (index < 0) index = 0;
    if (index > 26) index = 26;
    return NAKSHATRAS[index];
  }

  String calculateTithi(double moonLong, double sunLong) {
    double diff = moonLong - sunLong;
    if (diff < 0) diff += 360;
    int num = (diff / 12).floor();
    if (num < 0) num = 0;
    if (num > 29) num = 29;
    return TITHIS[num];
  }

  Map<String, String> calculatePanchang(BirthDetails d) {
    final utc = astronomy.convertToUTC(d);
    final jd = astronomy.julianDay(
      utc['Y'] as int,
      utc['M'] as int,
      utc['D'] as int,
      utc['UT'] as double,
    );

    final ayan = Astro.lahiriAyanamsa(jd);
    final sunLong = Astro.normalizeAngle(astronomy.sunLongitude(jd) - ayan);
    final moonLong = Astro.normalizeAngle(astronomy.moonLongitude(jd) - ayan);

    return {
      'nakshatra': calculateNakshatra(moonLong),
      'tithi': calculateTithi(moonLong, sunLong),
    };
  }
}
