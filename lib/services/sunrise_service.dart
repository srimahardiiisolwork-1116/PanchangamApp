import 'dart:math';

class SunriseService {
  // Simple sunrise calculation approximation
  // For production, consider using a more accurate algorithm or API
  static double sunriseUTC(DateTime date, double latitude, double longitude) {
    // Approximate sunrise time in UTC hours
    // This is a simplified calculation - for accurate results, use proper sunrise algorithms

    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;

    // Solar declination approximation
    final declination =
        23.45 * sin((360.0 * (284 + dayOfYear) / 365.0) * pi / 180);

    // Hour angle calculation
    final latRad = latitude * pi / 180;
    final decRad = declination * pi / 180;
    final hourAngle = acos(-tan(latRad) * tan(decRad)) * 180 / pi;

    // Sunrise time in UTC hours (simplified)
    double sunriseTimeInUTC = 12.0 - hourAngle / 15.0 - longitude / 15.0;

    // Normalize to 0-24 hours
    while (sunriseTimeInUTC < 0) {
      sunriseTimeInUTC += 24;
    }
    while (sunriseTimeInUTC >= 24) {
      sunriseTimeInUTC -= 24;
    }

    return sunriseTimeInUTC;
  }

  // More accurate sunrise calculation using solar position
  static double accurateSunriseUTC(
      DateTime date, double latitude, double longitude) {
    // Convert date to Julian Day
    final jd = _julianDay(date.year, date.month, date.day, 0, 0, 0);

    // Calculate solar noon
    final T = (jd - 2451545.0) / 36525;
    final solarNoon = _solarNoonCorrection(T, longitude);

    // Calculate sunrise
    final sunrise = solarNoon - _hourAngleSunrise(latitude, T);

    // Convert to UTC hours
    return sunrise % 24;
  }

  static double _julianDay(int Y, int M, int D, int H, int min, double S) {
    double ut = H + min / 60 + S / 3600;

    if (M <= 2) {
      Y -= 1;
      M += 12;
    }

    int A = (Y / 100).floor();
    double B = 2 - A + (A / 4).floor().toDouble();

    double jd = (365.25 * (Y + 4716)).floor() +
        (30.6001 * (M + 1)).floor() +
        D +
        B -
        1524.5 +
        ut / 24;

    return jd;
  }

  static double _solarNoonCorrection(double T, double longitude) {
    // Equation of time correction
    final E = 229.18 *
        (0.000075 +
            0.001868 * cos(T * 2 * pi) -
            0.032077 * sin(T * 2 * pi) -
            0.014615 * cos(T * 4 * pi) -
            0.040849 * sin(T * 4 * pi));

    // Solar noon in UTC
    return 12.0 - (longitude / 15.0) - (E / 60.0);
  }

  static double _hourAngleSunrise(double latitude, double T) {
    // Solar declination
    final declination =
        23.45 * sin((360.0 * (284 + T * 36525) / 365.0) * pi / 180);

    // Hour angle for sunrise
    final latRad = latitude * pi / 180;
    final decRad = declination * pi / 180;

    final hourAngle = acos(-tan(latRad) * tan(decRad)) * 180 / pi;

    return hourAngle / 15.0; // Convert to hours
  }
}
