import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/enums.dart';
import '../../models/birth_details.dart';
import '../../providers/providers.dart';
import '../../services/vedic_birthday_service.dart';
import 'vedic_birthday_screen.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(birthInputProvider);
    final engine = ref.read(hybridPanchangamProvider);

    if (input == null) {
      return const Scaffold(body: Center(child: Text('No input found')));
    }

    final result = engine.calculate(input);
    final year = DateTime.now().year;

    // Get current year birthdays using same three-method approach as VedicBirthdayScreen
    final birthDetails = BirthDetails(
      year: input.dateTime.year,
      month: input.dateTime.month,
      day: input.dateTime.day,
      hour: input.dateTime.hour,
      minute: input.dateTime.minute,
      second: input.dateTime.second,
      timezone: input.tzOffsetHours,
      latitude: input.latitude,
      longitude: input.longitude,
    );

    final tithiNakshatraMatches =
        VedicBirthdayService.findTithiNakshatraMatches(
            birthDetails, input.tzOffsetHours, year);
    final tithiMonthMatches = VedicBirthdayService.findTithiMonthMatches(
        birthDetails, input.tzOffsetHours, year);
    final nakshatraMonthMatches =
        VedicBirthdayService.findNakshatraMonthMatches(
            birthDetails, input.tzOffsetHours, year);

    // Combine all results
    List<Map<String, dynamic>> allCurrentYearMatches = [];
    allCurrentYearMatches.addAll(tithiNakshatraMatches);
    allCurrentYearMatches.addAll(tithiMonthMatches);
    allCurrentYearMatches.addAll(nakshatraMonthMatches);

    // Remove duplicates and sort
    Map<String, Map<String, dynamic>> uniqueResults = {};
    for (final result in allCurrentYearMatches) {
      final key = '${result['date']}_${result['time']}';
      uniqueResults[key] = result;
    }

    final currentYearMatches = uniqueResults.values.toList()
      ..sort(
          (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton(
                onPressed: () {
                  final d = BirthDetails(
                    year: input.dateTime.year,
                    month: input.dateTime.month,
                    day: input.dateTime.day,
                    hour: input.dateTime.hour,
                    minute: input.dateTime.minute,
                    second: input.dateTime.second,
                    timezone: input.tzOffsetHours,
                    latitude: input.latitude,
                    longitude: input.longitude,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => VedicBirthdayScreen(birth: d)),
                  );
                },
                child: const Text('Find Vedic Birthdays (Offline Scan)'),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  title: Text('Birth Nakshatram: ${result.nakshatraName}'),
                  subtitle: const Text('Birth star per Telugu Panchangam'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ),
              Card(
                child: ListTile(
                  title: Text('Birth Tithi: ${result.tithiName}'),
                  subtitle: Text(
                      'Paksha: ${result.paksha == Paksha.shukla ? 'Shukla' : 'Krishna'}'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ),
              Card(
                child: ListTile(
                  title: Text('Telugu Lunar Month: ${result.teluguMonth}'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ),
              const SizedBox(height: 12),
              Text('Current Year Birthdays ($year)',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...currentYearMatches.map(
                (match) {
                  final matchData = match;
                  final matchDate = matchData['date'] as DateTime;
                  final matchTime = matchData['time'] as DateTime;
                  final matchType = matchData['match_type'] as String;

                  // Get timing details for this match
                  final timing = VedicBirthdayService.getMatchTiming(
                    birthDetails,
                    matchDate,
                    matchTime,
                    matchType,
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: Text(_fmt(matchDate)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${matchData['match_type']} - ${_fmtTime(matchTime)}'),
                          Text(
                              'Tithi: ${matchData['tithi_name']} (${matchData['tithi']})'),
                          Text(
                              'Nakshatra: ${matchData['nakshatra_name']} (${matchData['nakshatra']})'),
                          Text('Masam: ${matchData['lunar_month']}'),

                          // Show timing details
                          if (timing['tithi_timing'] != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${timing['tithi_timing']['tithi_name']} Tithi',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                      'Begins: ${_formatDateTime(timing['tithi_timing']['start_time'])}'),
                                  Text(
                                      'Ends:   ${_formatDateTime(timing['tithi_timing']['end_time'])}'),
                                ],
                              ),
                            ),
                          ],

                          if (timing['nakshatra_timing'] != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${timing['nakshatra_timing']['nakshatra_name']} Nakshatra',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                      'Begins: ${_formatDateTime(timing['nakshatra_timing']['start_time'])}'),
                                  Text(
                                      'Ends:   ${_formatDateTime(timing['nakshatra_timing']['end_time'])}'),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('Explanation'),
              const SizedBox(height: 8),
              const Text(
                  'Calculations are done fully offline using standard low-precision astronomy suitable for devotional calendar usage.'),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'} on ${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}';
  }
}
