import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/panchangam_models.dart';
import '../../providers/providers.dart';
import '../../services/geocoding_service.dart';
import '../../models/person.dart';
import '../../services/calendar_service.dart';
import 'results_screen.dart';

class InputScreen extends ConsumerStatefulWidget {
  const InputScreen({super.key});

  @override
  ConsumerState<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<InputScreen> {
  DateTime? _date;
  TimeOfDay? _time;
  City? _city;
  final _cityController = TextEditingController();
  final _onlineController = TextEditingController();
  GeocodingResult? _selectedGeo;
  final _nameController = TextEditingController();
  bool _saveProfile = true;

  @override
  void dispose() {
    _cityController.dispose();
    _onlineController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(citiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nakshatra & Tithi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            Text('Date of Birth',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(now.year + 1),
                  initialDate: _date ?? now,
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Text(_date == null
                  ? 'Select Date'
                  : _date!.toLocal().toString().split(' ').first),
            ),
            const SizedBox(height: 16),
            Text('Time of Birth',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time ?? TimeOfDay.now(),
                );
                if (picked != null) setState(() => _time = picked);
              },
              child:
                  Text(_time == null ? 'Select Time' : _time!.format(context)),
            ),
            const SizedBox(height: 16),
            // Name
            Text('Name', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter full name',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _saveProfile,
              title: const Text('Save profile'),
              onChanged: (v) => setState(() => _saveProfile = v),
            ),
            const SizedBox(height: 16),
            Text('Place of Birth',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Online search first
            TextField(
              controller: _onlineController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Search city online (Nominatim)',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _buildOnlineSuggestions(context),
            const SizedBox(height: 16),
            Text('Or pick from offline list',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            citiesAsync.when(
              data: (cities) {
                final suggestions = _cityController.text.isEmpty
                    ? cities.take(10).toList()
                    : cities
                        .where((c) => c.name
                            .toLowerCase()
                            .contains(_cityController.text.toLowerCase()))
                        .take(10)
                        .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter city (offline list)',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: suggestions
                          .map((c) => ChoiceChip(
                                label: Text(c.name),
                                selected: _city?.name == c.name,
                                onSelected: (_) => setState(() {
                                  if (_city?.name == c.name) {
                                    _city = null;
                                  } else {
                                    _city = c;
                                  }
                                  _selectedGeo = null;
                                }),
                              ))
                          .toList(),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error loading cities: $e'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canProceed ? _onCalculate : null,
              child: const Text('Calculate'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canProceed =>
      _date != null &&
      _time != null &&
      _nameController.text.trim().isNotEmpty &&
      (_city != null || _selectedGeo != null);

  void _onCalculate() {
    if (!_canProceed) return;
    final dtLocal = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    if (_selectedGeo != null) {
      // Online lookup only for latitude/longitude + timezone offset.
      _resolveTimezoneAndProceed(dtLocal, _selectedGeo!);
    } else {
      final city = _city!;
      final input = BirthInput(
        dateTime: dtLocal,
        latitude: city.lat,
        longitude: city.lon,
        tzOffsetHours: city.tzOffset,
      );
      if (_saveProfile) {
        _persistFlow(input, placeName: city.name);
      }
      ref.read(birthInputProvider.notifier).state = input;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ResultsScreen()));
    }
  }

  Widget _buildOnlineSuggestions(BuildContext context) {
    final q = _onlineController.text.trim();
    if (q.isEmpty) return const SizedBox.shrink();
    final asyncResults = ref.watch(geocodeResultsProvider(q));
    return asyncResults.when(
      data: (list) {
        if (list.isEmpty) return const Text('No matches found');
        return Column(
          children: list
              .map((r) => ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(r.displayName,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        'lat: ${r.lat.toStringAsFixed(4)}, lon: ${r.lon.toStringAsFixed(4)}'),
                    selected: _selectedGeo?.displayName == r.displayName,
                    onTap: () => setState(() {
                      if (_selectedGeo?.displayName == r.displayName) {
                        _selectedGeo = null;
                      } else {
                        _selectedGeo = r;
                      }
                      _city = null;
                    }),
                  ))
              .toList(),
        );
      },
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, st) => Text('Geocoding error: $e'),
    );
  }

  Future<void> _resolveTimezoneAndProceed(
      DateTime dtLocal, GeocodingResult geo) async {
    final tzSvc = ref.read(timezoneServiceProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final offset = await tzSvc.offsetHours(geo.lat, geo.lon, dtLocal);
      if (!mounted) return;
      Navigator.of(context).pop();
      final input = BirthInput(
        dateTime: dtLocal,
        latitude: geo.lat,
        longitude: geo.lon,
        tzOffsetHours: offset,
      );
      if (_saveProfile) {
        _persistFlow(input, placeName: geo.displayName);
      }
      ref.read(birthInputProvider.notifier).state = input;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ResultsScreen()));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Timezone lookup failed: $e')));
    }
  }

  Future<void> _persistFlow(BirthInput input,
      {required String placeName}) async {
    final repo = ref.read(repositoryProvider);
    final engine = ref.read(hybridPanchangamProvider);
    final name = _nameController.text.trim();
    final id = '${DateTime.now().millisecondsSinceEpoch}_${name.hashCode}';
    final person = Person(
      id: id,
      name: name,
      birthDateTimeLocal: input.dateTime,
      latitude: input.latitude,
      longitude: input.longitude,
      placeName: placeName,
      tzOffsetHours: input.tzOffsetHours,
    );
    await repo.savePerson(person);
    final year = DateTime.now().year;
    List<YearlyBirthdays> list;
    final current = engine.birthdaysForYear(input, year);
    final next = engine.birthdaysForYear(input, year + 1);
    list = [
      YearlyBirthdays(
          year: year,
          pair: BirthdayPair(
              tithi: current.tithiBirthday,
              nakshatra: current.nakshatraBirthday)),
      YearlyBirthdays(
          year: year + 1,
          pair: BirthdayPair(
              tithi: next.tithiBirthday, nakshatra: next.nakshatraBirthday)),
    ];
    await repo.saveYearly(person.id, list);

    // Create basic calendar reminders (same-day all-day events)
    try {
      final calendar = CalendarService();
      await calendar.ensurePermissions();
      await calendar.createOrUpdateBirthdays(person, list);
    } catch (_) {}
  }
}
