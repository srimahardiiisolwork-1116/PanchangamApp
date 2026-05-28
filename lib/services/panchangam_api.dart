import '../models/panchangam_models.dart';
import '../services/panchangam_service.dart';

abstract class PanchangamEngine {
  PanchangamResult calculate(BirthInput input);
  BirthdayResults birthdaysForYear(BirthInput birth, int year);
}

class OfflinePanchangamEngine implements PanchangamEngine {
  final PanchangamService svc;
  OfflinePanchangamEngine(this.svc);
  @override
  PanchangamResult calculate(BirthInput input) => svc.calculate(input);
  @override
  BirthdayResults birthdaysForYear(BirthInput birth, int year) =>
      svc.birthdaysForYear(birth, year);
}
