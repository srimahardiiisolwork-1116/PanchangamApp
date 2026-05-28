import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final String displayName;
  final double lat;
  final double lon;
  GeocodingResult(
      {required this.displayName, required this.lat, required this.lon});
}

class GeocodingService {
  static const _timeout = Duration(seconds: 10);
  final String baseUrl;
  GeocodingService({this.baseUrl = 'https://nominatim.openstreetmap.org'});

  Future<List<GeocodingResult>> search(String query,
      {String? countryCodes}) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '8',
      if (countryCodes != null) 'countrycodes': countryCodes,
      'addressdetails': '0',
    });
    final resp = await http.get(uri, headers: {
      'User-Agent': 'dateapp/1.0 (telugu-panchangam)'
    }).timeout(_timeout);
    if (resp.statusCode != 200) return [];
    final list = json.decode(resp.body) as List;
    return list
        .map((e) => GeocodingResult(
              displayName: e['display_name'],
              lat: double.tryParse(e['lat']?.toString() ?? '') ?? 0,
              lon: double.tryParse(e['lon']?.toString() ?? '') ?? 0,
            ))
        .where((e) => e.lat != 0 || e.lon != 0)
        .toList();
  }

  Future<GeocodingResult?> reverse(double lat, double lon) async {
    final uri = Uri.parse('$baseUrl/reverse').replace(queryParameters: {
      'lat': '$lat',
      'lon': '$lon',
      'format': 'json',
      'zoom': '18',
    });
    final resp = await http.get(uri, headers: {
      'User-Agent': 'dateapp/1.0 (telugu-panchangam)'
    }).timeout(_timeout);
    if (resp.statusCode != 200) return null;

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final name = data['display_name']?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    return GeocodingResult(displayName: name, lat: lat, lon: lon);
  }
}
