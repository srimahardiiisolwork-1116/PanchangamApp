import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  final String apiKey;

  LocationService(this.apiKey);

  Future<List<LocationResult>> searchLocations(String query) async {
    if (query.isEmpty) return [];

    // For now, return some common Indian cities with their coordinates
    // In production, you would use TimeZoneDB API here
    final commonCities = [
      LocationResult(
          name: 'Hyderabad',
          country: 'IN',
          latitude: 17.3850,
          longitude: 78.4867,
          timezone: 5.5),
      LocationResult(
          name: 'Vijayawada',
          country: 'IN',
          latitude: 16.5062,
          longitude: 80.6480,
          timezone: 5.5),
      LocationResult(
          name: 'Visakhapatnam',
          country: 'IN',
          latitude: 17.6868,
          longitude: 83.2185,
          timezone: 5.5),
      LocationResult(
          name: 'Tirupati',
          country: 'IN',
          latitude: 13.6288,
          longitude: 79.4192,
          timezone: 5.5),
      LocationResult(
          name: 'Warangal',
          country: 'IN',
          latitude: 17.9689,
          longitude: 79.5941,
          timezone: 5.5),
      LocationResult(
          name: 'Guntur',
          country: 'IN',
          latitude: 16.3067,
          longitude: 80.4365,
          timezone: 5.5),
      LocationResult(
          name: 'Nellore',
          country: 'IN',
          latitude: 14.4426,
          longitude: 79.9865,
          timezone: 5.5),
      LocationResult(
          name: 'Kurnool',
          country: 'IN',
          latitude: 15.8281,
          longitude: 78.0373,
          timezone: 5.5),
      LocationResult(
          name: 'Ongole',
          country: 'IN',
          latitude: 15.5057,
          longitude: 80.0499,
          timezone: 5.5),
      LocationResult(
          name: 'Rajahmundry',
          country: 'IN',
          latitude: 17.0005,
          longitude: 81.8040,
          timezone: 5.5),
      LocationResult(
          name: 'Bangalore',
          country: 'IN',
          latitude: 12.9716,
          longitude: 77.5946,
          timezone: 5.5),
      LocationResult(
          name: 'Chennai',
          country: 'IN',
          latitude: 13.0827,
          longitude: 80.2707,
          timezone: 5.5),
      LocationResult(
          name: 'Mumbai',
          country: 'IN',
          latitude: 19.0760,
          longitude: 72.8777,
          timezone: 5.5),
      LocationResult(
          name: 'Delhi',
          country: 'IN',
          latitude: 28.7041,
          longitude: 77.1025,
          timezone: 5.5),
      LocationResult(
          name: 'Kolkata',
          country: 'IN',
          latitude: 22.5726,
          longitude: 88.3639,
          timezone: 5.5),
    ];

    // Filter cities based on query
    final filteredCities = commonCities
        .where((city) =>
            city.name.toLowerCase().contains(query.toLowerCase()) ||
            city.displayName.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return filteredCities;
  }

  Future<LocationResult?> getLocationByCoordinates(
      double lat, double lon) async {
    final url =
        Uri.parse('https://api.timezonedb.com/v2.1/get-time-zone').replace(
      queryParameters: {
        'key': apiKey,
        'format': 'json',
        'by': 'position',
        'lat': '$lat',
        'lng': '$lon',
      },
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('Failed to get location: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        return null;
      }

      return LocationResult(
        name: data['cityName'] ?? 'Unknown',
        country: data['countryCode'] ?? '',
        latitude: lat,
        longitude: lon,
        timezone: (data['gmtOffset'] as num? ?? 19800) / 3600.0,
      );
    } catch (_) {
      return null;
    }
  }
}

class LocationResult {
  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final double timezone;

  LocationResult({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  String get displayName => '$name, $country';

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'lat': latitude,
        'lon': longitude,
        'tz': timezone,
      };
}
