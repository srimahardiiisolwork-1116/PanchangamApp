import 'dart:convert';
import 'package:http/http.dart' as http;

abstract class TimezoneService {
  Future<double> offsetHours(double lat, double lon, DateTime localDateTime);
}

class GoogleTimezoneService implements TimezoneService {
  static const _timeout = Duration(seconds: 10);
  final String apiKey;
  GoogleTimezoneService(this.apiKey);

  @override
  Future<double> offsetHours(
      double lat, double lon, DateTime localDateTime) async {
    // Google expects a UTC timestamp (seconds since epoch)
    final ts = localDateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    final url =
        Uri.parse('https://maps.googleapis.com/maps/api/timezone/json').replace(
      queryParameters: {
        'location': '$lat,$lon',
        'timestamp': '$ts',
        'key': apiKey,
      },
    );
    final resp = await http.get(url).timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception('Google TZ HTTP ${resp.statusCode}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      throw Exception('Google TZ error: ${data['status']}');
    }
    final rawOffset = (data['rawOffset'] as num).toDouble();
    final dstOffset = (data['dstOffset'] as num).toDouble();
    return (rawOffset + dstOffset) / 3600.0;
  }
}

class TimezoneDBService implements TimezoneService {
  static const _timeout = Duration(seconds: 10);
  final String apiKey;
  TimezoneDBService(this.apiKey);

  @override
  Future<double> offsetHours(
      double lat, double lon, DateTime localDateTime) async {
    // TimezoneDB provides gmtOffset in seconds for a given lat/lon *at a specific time*.
    // We pass a timestamp so DST is handled.
    // TimezoneDB expects a UTC timestamp. We don't know the offset yet, so we treat the
    // provided local time as a UTC clock time to get a stable approximation.
    final localAsUtcClock = DateTime.utc(
      localDateTime.year,
      localDateTime.month,
      localDateTime.day,
      localDateTime.hour,
      localDateTime.minute,
      localDateTime.second,
      localDateTime.millisecond,
    );
    final ts = localAsUtcClock.millisecondsSinceEpoch ~/ 1000;

    final url =
        Uri.parse('https://api.timezonedb.com/v2.1/get-time-zone').replace(
      queryParameters: {
        'key': apiKey,
        'format': 'json',
        'by': 'position',
        'lat': '$lat',
        'lng': '$lon',
        'time': '$ts',
      },
    );
    final resp = await http.get(url).timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception('TimezoneDB HTTP ${resp.statusCode}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      throw Exception('TimezoneDB error: ${data['status']}');
    }
    final gmtOffset = (data['gmtOffset'] as num).toDouble();
    return gmtOffset / 3600.0;
  }
}

class FallbackFixedTimezoneService implements TimezoneService {
  final double fixedOffset;
  FallbackFixedTimezoneService(this.fixedOffset);
  @override
  Future<double> offsetHours(
          double lat, double lon, DateTime localDateTime) async =>
      fixedOffset;
}
