import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/person.dart';
import '../models/panchangam_models.dart';

class CalendarService {
  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  static const _calendarName = 'Telugu Birthdays';

  Future<void> ensurePermissions() async {
    final status = await Permission.calendarFullAccess.request();
    if (!status.isGranted) {
      throw Exception('Calendar access was not granted.');
    }
  }

  Future<Calendar?> _getOrCreateCalendar() async {
    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data ?? [];
    final existing = calendars.firstWhere(
      (c) => (c.name ?? '').toLowerCase() == _calendarName.toLowerCase(),
      orElse: () => Calendar(id: null),
    );
    if (existing.id != null) return existing;

    // Try to create a local calendar if supported (Android). iOS usually doesn't support creating new calendars programmatically
    final createResult = await _plugin.createCalendar(_calendarName);
    if (createResult.isSuccess && createResult.data?.isNotEmpty == true) {
      final id = createResult.data!;
      final newCal = (await _plugin.retrieveCalendars())
          .data
          ?.firstWhere((c) => c.id == id);
      return newCal;
    }
    // Fallback to first writable calendar
    return calendars.firstWhere((c) => c.isReadOnly != true,
        orElse: () => calendars.isNotEmpty ? calendars.first : null);
  }

  Future<void> createOrUpdateBirthdays(
      Person person, List<YearlyBirthdays> list) async {
    final calendar = await _getOrCreateCalendar();
    if (calendar == null || calendar.id == null) return;

    for (final y in list) {
      await _createAllDayEvent(calendar.id!,
          '${person.name} — Tithi Birthday ${y.year}', y.pair.tithi);
      await _createAllDayEvent(calendar.id!,
          '${person.name} — Nakshatra Birthday ${y.year}', y.pair.nakshatra);
    }
  }

  Future<void> _createAllDayEvent(
      String calendarId, String title, DateTime date) async {
    // All-day event on the computed date
    final start = tz.TZDateTime(tz.local, date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final event = Event(calendarId,
        title: title,
        start: start,
        end: end,
        allDay: true,
        reminders: [
          Reminder(minutes: 0)
        ] // same-day reminder; can be customized later
        );
    await _plugin.createOrUpdateEvent(event);
  }
}
