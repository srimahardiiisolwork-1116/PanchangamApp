import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/panchangam_models.dart';
import '../services/panchangam_service.dart';
import '../services/geocoding_service.dart';
import '../services/panchangam_api.dart';
import '../services/repository.dart';
import '../services/timezone_service.dart';
import 'auth_providers.dart';

final panchangamServiceProvider = Provider((ref) => PanchangamService());

class City {
  final String name;
  final double lat;
  final double lon;
  final double tzOffset; // hours
  City(
      {required this.name,
      required this.lat,
      required this.lon,
      required this.tzOffset});
}

final citiesProvider = FutureProvider<List<City>>((ref) async {
  final data = await rootBundle.loadString('assets/data/cities.json');
  final jsonList = json.decode(data) as List;
  return jsonList
      .map((e) => City(
            name: e['name'],
            lat: (e['lat'] as num).toDouble(),
            lon: (e['lon'] as num).toDouble(),
            tzOffset: (e['tz'] as num).toDouble(),
          ))
      .toList();
});

final birthInputProvider = StateProvider<BirthInput?>((ref) => null);

// Profiles are kept separate for each authenticated account on the device.
final repositoryProvider = Provider<Repository>((ref) {
  final userId = ref.watch(authStateProvider).asData?.value?.uid;
  return Repository(userScope: userId);
});

// Online geocoding service (Nominatim)
final geocodingProvider = Provider((ref) => GeocodingService());

// Search cities online (family by query)
final geocodeResultsProvider = FutureProvider.family((ref, String query) async {
  final svc = ref.read(geocodingProvider);
  return svc.search(query, countryCodes: 'in');
});

// Timezone service: uses online API when key is present, else fixed IST (+5.5)
final timezoneServiceProvider = Provider<TimezoneService>((ref) {
  const googleKey = String.fromEnvironment('GOOGLE_TIMEZONE_API_KEY');
  const tzdbKey = String.fromEnvironment('TIMEZONEDB_API_KEY');

  if (googleKey.isNotEmpty) return GoogleTimezoneService(googleKey);
  if (tzdbKey.isNotEmpty) return TimezoneDBService(tzdbKey);
  return FallbackFixedTimezoneService(5.5);
});

// Hybrid Panchangam provider: uses external API when keys are present, else offline
final hybridPanchangamProvider = Provider<PanchangamEngine>((ref) {
  final offline = ref.watch(panchangamServiceProvider);
  return OfflinePanchangamEngine(offline);
});
