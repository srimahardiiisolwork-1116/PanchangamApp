import 'dart:convert';
import 'package:http/http.dart' as http;

class GeonamesResult {
  final int geonameId;
  final String name;
  final String country;
  GeonamesResult(
      {required this.geonameId, required this.name, required this.country});
}

class GeonamesService {
  static const _baseUrl = 'https://api.geonames.org';
  static const _username = String.fromEnvironment('GEONAMES_USERNAME');
  static const _timeout = Duration(seconds: 10);

  static Future<GeonamesResult?> reverseLookup(double lat, double lon) async {
    if (_username.isEmpty) return null;
    final uri = Uri.parse('$_baseUrl/findNearbyPlaceNameJSON').replace(
        queryParameters: {'lat': '$lat', 'lng': '$lon', 'username': _username});
    try {
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final list = data['geonames'] as List?;
      if (list == null || list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final geonameId = int.tryParse(first['geonameId']?.toString() ?? '');
      final name = first['name'] as String?;
      final country = first['countryCode'] as String?;
      if (geonameId == null || name == null || country == null) return null;
      return GeonamesResult(geonameId: geonameId, name: name, country: country);
    } catch (e) {
      return null;
    }
  }
}
