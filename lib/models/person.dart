class Person {
  final String id; // unique per user scope
  final String name;
  final DateTime birthDateTimeLocal;
  final double latitude;
  final double longitude;
  final String placeName;
  final double tzOffsetHours; // at time of birth

  Person({
    required this.id,
    required this.name,
    required this.birthDateTimeLocal,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.tzOffsetHours,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'birth': birthDateTimeLocal.toIso8601String(),
        'lat': latitude,
        'lon': longitude,
        'place': placeName,
        'tz': tzOffsetHours,
      };

  static Person fromJson(Map<String, dynamic> j) => Person(
        id: j['id'],
        name: j['name'],
        birthDateTimeLocal: DateTime.parse(j['birth']),
        latitude: (j['lat'] as num).toDouble(),
        longitude: (j['lon'] as num).toDouble(),
        placeName: j['place'],
        tzOffsetHours: (j['tz'] as num).toDouble(),
      );
}
