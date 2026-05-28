// Standard astronomy formula symbols are kept as written for readability.
// ignore_for_file: non_constant_identifier_names

import 'dart:math';

import '../models/birth_details.dart';
import 'astro_math.dart';

class AstronomyService {
  double normalize(double angle) {
    angle %= 360;
    if (angle < 0) angle += 360;
    return angle;
  }

  double degToRad(double deg) => deg * pi / 180;

  Map<String, dynamic> convertToUTC(BirthDetails d) {
    final local = DateTime(
      d.year,
      d.month,
      d.day,
      d.hour,
      d.minute,
      d.second,
    );

    final offsetMs = (d.timezone * 3600 * 1000).round();
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

    final UT = utc.hour +
        utc.minute / 60 +
        utc.second / 3600 +
        utc.millisecond / 3.6e6;
    return {"Y": utc.year, "M": utc.month, "D": utc.day, "UT": UT};
  }

  double julianDay(int Y, int M, int D, double UT) {
    if (M <= 2) {
      Y -= 1;
      M += 12;
    }
    int A = (Y / 100).floor();
    int B = 2 - A + (A / 4).floor();

    return (365.25 * (Y + 4716)).floor() +
        (30.6001 * (M + 1)).floor() +
        D +
        B -
        1524.5 +
        UT / 24;
  }

  double sunLongitude(double jd) {
    return Astro.sunEclipticLongitude(jd);
  }

  double moonLongitude(double jd) {
    return Astro.moonEclipticLongitude(jd);
  }
}
