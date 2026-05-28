// Standard astronomy formula symbols are kept as written for readability.
// ignore_for_file: non_constant_identifier_names

import 'dart:math' as math;

class Astro {
  static const double deg2rad = math.pi / 180.0;
  static const double rad2deg = 180.0 / math.pi;

  static double normalizeAngle(double deg) {
    var d = deg % 360.0;
    if (d < 0) d += 360.0;
    return d;
  }

  static double sinDeg(double x) => math.sin(x * deg2rad);
  static double cosDeg(double x) => math.cos(x * deg2rad);
  static double atan2Deg(double y, double x) => math.atan2(y, x) * rad2deg;

  // Lahiri Ayanamsa (approx) in degrees.
  // This is used to convert tropical longitude to sidereal: sidereal = tropical - ayanamsa.
  // The approximation is sufficient for devotional/calendar style computations.
  static double lahiriAyanamsa(double jd) {
    // Based on a standard low-precision polynomial using Julian centuries from 1900.0.
    final T = (jd - 2415020.0) / 36525.0;
    final ayan = 22.460148 + 1.396042 * T + 0.000308 * T * T;
    return normalizeAngle(ayan);
  }

  // Julian Day from UTC date-time
  static double julianDayUTC(DateTime utc) {
    final y = utc.year;
    final m = utc.month;
    final d = utc.day;
    final hour = utc.hour +
        utc.minute / 60 +
        utc.second / 3600 +
        utc.millisecond / 3.6e6;

    int Y = y;
    int M = m;
    if (M <= 2) {
      Y -= 1;
      M += 12;
    }

    final A = (Y / 100).floor();
    final B = 2 - A + (A / 4).floor();

    final dayFraction = hour / 24.0;
    final JD = (365.25 * (Y + 4716)).floor() +
        (30.6001 * (M + 1)).floor() +
        d +
        dayFraction +
        B -
        1524.5;
    return JD;
  }

  // Convert local time with tz offset to UTC JD
  static double julianDayFromLocal(DateTime local, double tzOffsetHours) {
    // Interpret `local` as civil time at the place of birth with a known offset from UTC.
    // Convert to an equivalent UTC instant by subtracting the offset (handles fractional hours).
    final offsetMs = (tzOffsetHours * 3600 * 1000).round();
    final localAsUtcClock = DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
    );
    final utc = localAsUtcClock.subtract(Duration(milliseconds: offsetMs));
    return julianDayUTC(utc);
  }

  // Low-precision solar longitude (ecliptic) in degrees, apparent
  static double sunEclipticLongitude(double jd) {
    final T = (jd - 2451545.0) / 36525.0;
    final L0 = normalizeAngle(280.46646 + 36000.76983 * T + 0.0003032 * T * T);
    final M = normalizeAngle(357.52911 + 35999.05029 * T - 0.0001537 * T * T);
    final C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * sinDeg(M) +
        (0.019993 - 0.000101 * T) * sinDeg(2 * M) +
        0.000289 * sinDeg(3 * M);
    var trueLong = L0 + C;
    // Nutation/aberration small correction for apparent longitude
    final omega = 125.04 - 1934.136 * T;
    final lambda = trueLong - 0.00569 - 0.00478 * sinDeg(omega);
    return normalizeAngle(lambda);
  }

  // Low-precision lunar ecliptic longitude in degrees (Meeus simplified)
  static double moonEclipticLongitude(double jd) {
    final T = (jd - 2451545.0) / 36525.0;
    final L1 = normalizeAngle(218.3164477 +
        481267.88123421 * T -
        0.0015786 * T * T +
        T * T * T / 538841.0 -
        T * T * T * T / 65194000.0);
    final D = normalizeAngle(297.8501921 +
        445267.1114034 * T -
        0.0018819 * T * T +
        T * T * T / 545868 -
        T * T * T * T / 113065000);
    final M = normalizeAngle(357.5291092 +
        35999.0502909 * T -
        0.0001536 * T * T +
        T * T * T / 24490000);
    final Mp = normalizeAngle(134.9633964 +
        477198.8675055 * T +
        0.0087414 * T * T +
        T * T * T / 69699 -
        T * T * T * T / 14712000);
    final F = normalizeAngle(93.2720950 +
        483202.0175233 * T -
        0.0036539 * T * T -
        T * T * T / 3526000 +
        T * T * T * T / 863310000);

    // A limited set of periodic terms for longitude (in arcseconds)
    final terms = [
      // D, M, Mp, F, coeff (arcsec)
      [0, 0, 1, 0, 6288774],
      [2, 0, -1, 0, 1274027],
      [2, 0, 0, 0, 658314],
      [0, 0, 2, 0, 213618],
      [0, 1, 0, 0, -185116],
      [0, 0, 0, 2, -114332],
      [2, 0, -2, 0, 58793],
      [2, -1, -1, 0, 57066],
      [2, 0, 1, 0, 53322],
      [2, -1, 0, 0, 45758],
      [0, 1, -1, 0, -40923],
      [1, 0, 0, 0, -34720],
      [0, 1, 1, 0, -30383],
      [2, 0, 0, -2, 15327],
      [0, 0, 1, 2, -12528],
      [0, 0, 1, -2, 10980],
      [4, 0, -1, 0, 10675],
      [0, 0, 3, 0, 10034],
      [4, 0, -2, 0, 8548],
      [2, 1, -1, 0, -7888],
    ];

    double sum = 0.0;
    for (final t in terms) {
      final arg = t[0] * D + t[1] * M + t[2] * Mp + t[3] * F;
      sum += t[4] * sinDeg(arg);
    }

    final deltaLon = sum / 3600.0; // arcsec to degrees
    final lon = L1 + deltaLon;
    return normalizeAngle(lon);
  }
}
