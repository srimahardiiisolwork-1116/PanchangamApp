import 'package:dateapp/models/panchangam_models.dart';
import 'package:dateapp/services/panchangam_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final svc = PanchangamService();

  test('Nakshatra calculation is stable for known date', () {
    final input = BirthInput(
      dateTime: DateTime(2023, 9, 1, 12, 0),
      latitude: 17.3850,
      longitude: 78.4867,
      tzOffsetHours: 5.5,
    );
    final res = svc.calculate(input);
    expect(res.nakshatraIndex, inInclusiveRange(0, 26));
    expect(res.nakshatraName.isNotEmpty, true);
  });

  test('Tithi calculation returns valid range and paksha', () {
    final input = BirthInput(
      dateTime: DateTime(2024, 3, 10, 18, 30),
      latitude: 17.3850,
      longitude: 78.4867,
      tzOffsetHours: 5.5,
    );
    final res = svc.calculate(input);
    expect(res.tithiIndex, inInclusiveRange(0, 29));
    expect(res.tithiName.contains('Paksha'), true);
  });
}
