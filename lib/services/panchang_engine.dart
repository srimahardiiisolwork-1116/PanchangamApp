// Standard astronomy formula symbols are kept as written for readability.
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'dart:math';

class PanchangEngine {
  static const double J2000 = 2451545.0;
  static const double TITHI_SIZE = 12.0;
  static const double NAKSHATRA_SIZE = 13.3333333333333;

  // 1️⃣ NORMALIZE ANGLE
  static double normalize(double angle) {
    angle = angle % 360;
    if (angle < 0) {
      angle += 360;
    }
    return angle;
  }

  // 2️⃣ JULIAN DAY FROM UTC DATETIME
  static double julianDay(int Y, int M, int D, int H, int Min, double S) {
    double UT = H + Min / 60 + S / 3600;

    if (M <= 2) {
      Y -= 1;
      M += 12;
    }

    int A = (Y / 100).floor();
    double B = 2 - A + (A / 4).floor().toDouble();

    double JD = (365.25 * (Y + 4716)).floor() +
        (30.6001 * (M + 1)).floor() +
        D +
        B -
        1524.5 +
        UT / 24;

    return JD;
  }

  // 3️⃣ SUN LONGITUDE (TROPICAL)
  static double sunLongitude(double JD) {
    double T = (JD - J2000) / 36525;

    double L0 = normalize(280.46646 + 36000.76983 * T);
    double M = normalize(357.52911 + 35999.05029 * T);

    double C = (1.914602 - 0.004817 * T) * sin(_degToRad(M)) +
        0.019993 * sin(_degToRad(2 * M)) +
        0.000289 * sin(_degToRad(3 * M));

    return normalize(L0 + C);
  }

  // 4️⃣ MOON LONGITUDE (TROPICAL)
  static double moonLongitude(double JD) {
    double T = (JD - J2000) / 36525;

    double Lm = 218.316 + 481267.881 * T;
    double Mm = 134.963 + 477198.867 * T;
    double D = 297.850 + 445267.111 * T;

    Lm = Lm +
        6.289 * sin(_degToRad(Mm)) +
        1.274 * sin(_degToRad(2 * D - Mm)) +
        0.658 * sin(_degToRad(2 * D)) +
        0.214 * sin(_degToRad(2 * Mm));

    return normalize(Lm);
  }

  // 5️⃣ AYANAMSA (LAHIRI)
  static double ayanamsa(double JD) {
    double T = (JD - J2000) / 36525;
    return 22.460148 + 1.396042 * T + 0.000087 * T * T;
  }

  // 6️⃣ SIDEREAL LONGITUDES
  static (double, double) siderealLongitudes(double JD) {
    double Ls = sunLongitude(JD);
    double Lm = moonLongitude(JD);
    double ay = ayanamsa(JD);

    double Ls_sid = normalize(Ls - ay);
    double Lm_sid = normalize(Lm - ay);

    return (Ls_sid, Lm_sid);
  }

  // 7️⃣ COMPUTE TITHI
  static (int, String) computeTithi(double Lm_sid, double Ls_sid) {
    double diff = normalize(Lm_sid - Ls_sid);

    int tithi_number = (diff / TITHI_SIZE).floor() + 1;
    String paksha = tithi_number <= 15 ? "Shukla" : "Krishna";

    return (tithi_number, paksha);
  }

  // 8️⃣ COMPUTE NAKSHATRA
  static int computeNakshatra(double Lm_sid) {
    int nak_num = (Lm_sid / NAKSHATRA_SIZE).floor() + 1;
    return nak_num;
  }

  // 9️⃣ LUNAR MONTH FROM SUN SIGN
  static String lunarMonth(double Ls_sid) {
    int sign = (Ls_sid / 30).floor();

    List<String> months = [
      "Chaitra",
      "Vaishakha",
      "Jyeshta",
      "Ashadha",
      "Shravana",
      "Bhadrapada",
      "Ashwayuja",
      "Kartika",
      "Margashira",
      "Pushya",
      "Magha",
      "Phalguna"
    ];

    return months[sign];
  }

  // 🔟 PANCHANG AT ANY MOMENT (CORE FUNCTION)
  static Map<String, dynamic> panchangAtUTC(
      int Y, int M, int D, int H, int Min, double S) {
    double JD = julianDay(Y, M, D, H, Min, S);

    var (Ls, Lm) = siderealLongitudes(JD);

    var (tithi, paksha) = computeTithi(Lm, Ls);
    int nakshatra = computeNakshatra(Lm);
    String lunar_month = lunarMonth(Ls);

    return {
      "tithi_number": tithi,
      "paksha": paksha,
      "nakshatra": nakshatra,
      "lunar_month": lunar_month,
      "julian_day": JD,
      "sun_longitude_tropical": sunLongitude(JD),
      "moon_longitude_tropical": moonLongitude(JD),
      "sun_longitude_sidereal": Ls,
      "moon_longitude_sidereal": Lm,
      "ayanamsa": ayanamsa(JD),
    };
  }

  // 1️⃣1️⃣ PANCHANG AT SUNRISE OF A DATE
  static Map<String, dynamic> panchangAtSunrise(
      int Y, int M, int D, double sunrise_utc_hour) {
    double JD = julianDay(Y, M, D, sunrise_utc_hour.floor(), 0, 0);
    return panchangAtUTC_fromJD(JD);
  }

  static Map<String, dynamic> panchangAtUTC_fromJD(double JD) {
    var (Ls, Lm) = siderealLongitudes(JD);

    var (tithi, paksha) = computeTithi(Lm, Ls);
    int nakshatra = computeNakshatra(Lm);
    String lunar_month = lunarMonth(Ls);

    return {
      "tithi_number": tithi,
      "paksha": paksha,
      "nakshatra": nakshatra,
      "lunar_month": lunar_month,
      "julian_day": JD,
      "sun_longitude_tropical": sunLongitude(JD),
      "moon_longitude_tropical": moonLongitude(JD),
      "sun_longitude_sidereal": Ls,
      "moon_longitude_sidereal": Lm,
      "ayanamsa": ayanamsa(JD),
    };
  }

  // Helper function for degree to radian conversion
  static double _degToRad(double degrees) {
    return degrees * pi / 180;
  }
}
