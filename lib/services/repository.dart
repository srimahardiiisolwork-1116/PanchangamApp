import 'package:hive_flutter/hive_flutter.dart';

import '../models/panchangam_models.dart';
import '../models/person.dart';

class Repository {
  static const _legacyPeopleBox = 'people';
  static const _legacyBirthdaysBox = 'birthdays';

  Repository({String? userScope}) : _scope = _safeScope(userScope);

  final String _scope;
  Future<void>? _migration;

  String get _peopleBox => '${_legacyPeopleBox}_$_scope';
  String get _birthdaysBox => '${_legacyBirthdaysBox}_$_scope';

  static String _safeScope(String? scope) {
    final value = scope?.trim() ?? '';
    if (value.isEmpty) return 'local';
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  Future<Box> _open(String name) async => Hive.openBox(name);

  Future<void> _ensureLegacyMigrated() =>
      _migration ??= _migrateLegacyRecords();

  Future<void> _migrateLegacyRecords() async {
    if (_scope == 'local') return;

    final legacyPeople = await _open(_legacyPeopleBox);
    final legacyBirthdays = await _open(_legacyBirthdaysBox);
    if (legacyPeople.isEmpty && legacyBirthdays.isEmpty) return;

    final people = await _open(_peopleBox);
    final birthdays = await _open(_birthdaysBox);
    final migratedIds = <dynamic, String>{};

    for (final entry in legacyPeople.toMap().entries) {
      final data = Map<String, dynamic>.from(entry.value as Map);
      final oldId = data['id']?.toString().trim() ?? '';
      final id = oldId.isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : oldId;
      data['id'] = id;
      migratedIds[entry.key] = id;
      await people.put(id, data);
    }
    for (final entry in legacyBirthdays.toMap().entries) {
      final id = migratedIds[entry.key] ?? entry.key;
      await birthdays.put(id, entry.value);
    }

    await legacyPeople.clear();
    await legacyBirthdays.clear();
  }

  Future<void> savePerson(Person person) async {
    await _ensureLegacyMigrated();
    final box = await _open(_peopleBox);
    final id = person.id.trim().isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : person.id;
    final data = person.toJson()..['id'] = id;
    await box.put(id, data);
  }

  Future<List<Person>> getPeople() async {
    await _ensureLegacyMigrated();
    final box = await _open(_peopleBox);
    final people = box.values
        .map(
            (value) => Person.fromJson(Map<String, dynamic>.from(value as Map)))
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return people;
  }

  Future<void> deletePerson(String id) async {
    await _ensureLegacyMigrated();
    final people = await _open(_peopleBox);
    await people.delete(id);
    final birthdays = await _open(_birthdaysBox);
    await birthdays.delete(id);
  }

  Future<void> saveYearly(
    String personId,
    List<YearlyBirthdays> list,
  ) async {
    await _ensureLegacyMigrated();
    final box = await _open(_birthdaysBox);
    final data = list.map((entry) => entry.toJson()).toList();
    await box.put(personId, data);
  }

  Future<Map<int, BirthdayPair>> getYearly(String personId) async {
    await _ensureLegacyMigrated();
    final box = await _open(_birthdaysBox);
    final raw = box.get(personId);
    if (raw == null) return {};
    final list = (raw as List)
        .map((value) =>
            YearlyBirthdays.fromJson(Map<String, dynamic>.from(value as Map)))
        .toList();
    return {for (final entry in list) entry.year: entry.pair};
  }
}
