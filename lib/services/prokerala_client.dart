import 'dart:convert';
import 'package:http/http.dart' as http;

class ProkeralaClient {
  final String clientId;
  final String clientSecret;

  String? _accessToken;
  DateTime? _tokenExpiry;

  ProkeralaClient({required this.clientId, required this.clientSecret});

  Future<String> _getToken() async {
    final now = DateTime.now();
    if (_accessToken != null &&
        _tokenExpiry != null &&
        now.isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }
    final url = Uri.parse('https://api.prokerala.com/token');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('Prokerala token error: ${resp.statusCode} ${resp.body}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String?;
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3500;
    _tokenExpiry = now.add(Duration(seconds: expiresIn - 60));
    if (_accessToken == null) {
      throw Exception('No access_token in token response');
    }
    return _accessToken!;
  }

  Future<Map<String, dynamic>> _getJson(
      String url, Map<String, String> params) async {
    final token = await _getToken();
    final uri = Uri.parse(url).replace(queryParameters: params);
    final resp =
        await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 401) {
      // refresh and retry once
      _accessToken = null;
      await _getToken();
      final retry = await http
          .get(uri, headers: {'Authorization': 'Bearer ${_accessToken!}'});
      if (retry.statusCode != 200) {
        throw Exception(
            'Prokerala GET failed: ${retry.statusCode} ${retry.body}');
      }
      return json.decode(retry.body) as Map<String, dynamic>;
    }
    if (resp.statusCode != 200) {
      throw Exception('Prokerala GET failed: ${resp.statusCode} ${resp.body}');
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPanchang({
    required DateTime dateTimeLocal,
    required double lat,
    required double lon,
    String timezone = 'Asia/Kolkata',
    int ayanamsa = 1,
  }) async {
    return _getJson('https://api.prokerala.com/v2/astrology/panchang', {
      'ayanamsa': '$ayanamsa',
      'datetime': dateTimeLocal.toIso8601String().split('.').first,
      'latitude': '$lat',
      'longitude': '$lon',
      'timezone': timezone,
    });
  }

  Future<List<DateTime>> findTithi({
    required int tithiNumber,
    required String paksha,
    required int year,
    required double lat,
    required double lon,
    String timezone = 'Asia/Kolkata',
  }) async {
    final data =
        await _getJson('https://api.prokerala.com/v2/astrology/find-tithi', {
      'tithi': '$tithiNumber',
      'paksha': paksha,
      'from': '$year-01-01',
      'to': '$year-12-31',
      'latitude': '$lat',
      'longitude': '$lon',
      'timezone': timezone,
    });
    final list = (data['data'] as List?) ?? [];
    return list
        .map((e) => DateTime.parse((e['date'] ?? e['datetime']) as String))
        .toList();
  }

  Future<List<DateTime>> findNakshatra({
    required String nakshatraName,
    required int year,
    required double lat,
    required double lon,
    String timezone = 'Asia/Kolkata',
  }) async {
    final data = await _getJson(
        'https://api.prokerala.com/v2/astrology/find-nakshatra', {
      'nakshatra': nakshatraName,
      'from': '$year-01-01',
      'to': '$year-12-31',
      'latitude': '$lat',
      'longitude': '$lon',
      'timezone': timezone,
    });
    final list = (data['data'] as List?) ?? [];
    return list
        .map((e) => DateTime.parse((e['date'] ?? e['datetime']) as String))
        .toList();
  }
}
