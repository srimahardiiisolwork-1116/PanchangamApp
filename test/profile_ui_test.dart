import 'package:dateapp/models/person.dart';
import 'package:dateapp/providers/providers.dart';
import 'package:dateapp/services/repository.dart';
import 'package:dateapp/ui/screens/calendar_screen.dart';
import 'package:dateapp/ui/screens/person_details_form.dart';
import 'package:dateapp/ui/screens/year_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

class _TestRepository extends Repository {
  _TestRepository(this.people);

  final List<Person> people;
  String? deletedId;

  @override
  Future<List<Person>> getPeople() async => List.of(people);

  @override
  Future<void> deletePerson(String id) async {
    deletedId = id;
    people.removeWhere((person) => person.id == id);
  }
}

Person _person({String id = '1', String name = 'Avinash'}) => Person(
      id: id,
      name: name,
      birthDateTimeLocal: DateTime(2001, 9, 8, 10, 30),
      latitude: 17.385,
      longitude: 78.4867,
      placeName: 'Hyderabad, IN',
      tzOffsetHours: 5.5,
    );

Widget _app(Repository repository, Widget home) => ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(home: home),
    );

void main() {
  testWidgets('find screen remains layout-safe while keyboard is visible',
      (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(_TestRepository([_person()]), const YearSelectionScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find Birthday Matches'), findsOneWidget);
    expect(find.text('Search saved profiles'), findsOneWidget);
  });

  testWidgets('compact calendar header fits phone widths', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_TestRepository([]), const CalendarScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text(DateFormat('MMM yyyy').format(DateTime.now())),
      findsWidgets,
    );
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('saved profiles can be deleted after confirmation',
      (tester) async {
    final repository = _TestRepository([_person()]);
    await tester.pumpWidget(_app(repository, const YearSelectionScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedId, '1');
    expect(find.text('No people found. Please add a person first.'),
        findsOneWidget);
  });

  testWidgets('edit action opens the existing profile form', (tester) async {
    await tester.pumpWidget(
      _app(_TestRepository([_person()]), const YearSelectionScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.byType(PersonDetailsForm), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Avinash'), findsOneWidget);
  });
}
