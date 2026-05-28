import 'package:flutter/material.dart';

import '../../models/birth_details.dart';
import '../../services/vedic_birthday_service.dart';

class VedicBirthdayScreen extends StatefulWidget {
  final BirthDetails birth;
  const VedicBirthdayScreen({super.key, required this.birth});

  @override
  State<VedicBirthdayScreen> createState() => _VedicBirthdayScreenState();
}

class _VedicBirthdayScreenState extends State<VedicBirthdayScreen> {
  late final TextEditingController _yearController;
  List<Map<String, dynamic>>? _results;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _yearController =
        TextEditingController(text: DateTime.now().year.toString());
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vedic Birthdays (Offline Scan)')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ListView(
          children: [
            TextField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Target year',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _calculate,
              child: _loading
                  ? const Text('Calculating...')
                  : const Text('Find birthdays'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 8),
            if (_results != null) ...[
              Text(
                'Panchangam birthday matches: ${_results!.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              ..._results!.map(
                (match) {
                  final matchData = match;
                  final matchDate = matchData['date'] as DateTime;
                  final matchTime = matchData['time'] as DateTime;
                  final matchType = matchData['match_type'] as String;

                  // Get timing details for this match
                  final timing = VedicBirthdayService.getMatchTiming(
                    widget.birth,
                    matchDate,
                    matchTime,
                    matchType,
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: Text(_fmtDate(matchDate)),
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
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _calculate() async {
    final year = int.tryParse(_yearController.text.trim());
    if (year == null || year < 1900 || year > 2500) {
      setState(() {
        _error = 'Enter a valid year';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _results = null;
    });

    try {
      // Get all three types of matches
      final tithiNakshatraMatches =
          VedicBirthdayService.findTithiNakshatraMatches(
        widget.birth,
        widget.birth.timezone,
        year,
      );

      final tithiMonthMatches = VedicBirthdayService.findTithiMonthMatches(
        widget.birth,
        widget.birth.timezone,
        year,
      );

      final nakshatraMonthMatches =
          VedicBirthdayService.findNakshatraMonthMatches(
        widget.birth,
        widget.birth.timezone,
        year,
      );

      // Combine all results
      List<Map<String, dynamic>> allResults = [];
      allResults.addAll(tithiNakshatraMatches);
      allResults.addAll(tithiMonthMatches);
      allResults.addAll(nakshatraMonthMatches);

      // Remove duplicates (same date/time) and sort by date
      Map<String, Map<String, dynamic>> uniqueResults = {};
      for (final result in allResults) {
        final key = '${result['date']}_${result['time']}';
        uniqueResults[key] = result;
      }

      final results = uniqueResults.values.toList()
        ..sort(
            (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

      if (!mounted) return;
      setState(() {
        _results = results; // Keep the full match maps, not just DateTime
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'} on ${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}';
  }
}
