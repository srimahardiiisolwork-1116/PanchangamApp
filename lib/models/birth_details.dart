class BirthDetails {
  int year, month, day, hour, minute, second;
  double timezone;
  double latitude;
  double longitude;

  BirthDetails({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.second,
    required this.timezone,
    required this.latitude,
    required this.longitude,
  });

  BirthDetails copyWith({
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
    int? second,
  }) {
    return BirthDetails(
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      second: second ?? this.second,
      timezone: timezone,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
