import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/providers.dart';
import '../../models/person.dart';
import '../../models/panchangam_models.dart';
import '../../models/birth_details.dart';
import '../../services/vedic_birthday_service.dart';
import 'calendar_screen.dart';
import 'person_details_form.dart';

class YearSelectionScreen extends ConsumerStatefulWidget {
  const YearSelectionScreen({super.key});

  @override
  ConsumerState<YearSelectionScreen> createState() =>
      _YearSelectionScreenState();
}

class _YearSelectionScreenState extends ConsumerState<YearSelectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personSearchController = TextEditingController();
  final _yearController = TextEditingController();
  late Future<List<Person>> _peopleFuture;
  Person? _selectedPerson;
  int? _selectedYear;
  bool _isLoading = false;
  List<Map<String, dynamic>> _matchingDates = [];

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _yearController.text = _selectedYear.toString();
    _peopleFuture = ref.read(repositoryProvider).getPeople();
  }

  @override
  void dispose() {
    _personSearchController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _reloadPeople() {
    setState(() {
      _selectedPerson = null;
      _matchingDates = [];
      _peopleFuture = ref.read(repositoryProvider).getPeople();
    });
  }

  Future<void> _editPerson(Person person) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PersonDetailsForm(existingPerson: person),
      ),
    );
    if (mounted && saved == true) _reloadPeople();
  }

  Future<void> _deletePerson(Person person) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete profile?'),
            content: Text('Delete ${person.name} and its saved birthday data?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    await ref.read(repositoryProvider).deletePerson(person.id);
    if (!mounted) return;
    _reloadPeople();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile deleted.')),
    );
  }

  Future<void> _calculateMatchingDates() async {
    if (_selectedPerson == null || _selectedYear == null) return;

    setState(() => _isLoading = true);

    try {
      final birthInput = BirthInput(
        dateTime: _selectedPerson!.birthDateTimeLocal,
        latitude: _selectedPerson!.latitude,
        longitude: _selectedPerson!.longitude,
        tzOffsetHours: _selectedPerson!.tzOffsetHours,
      );

      final birthDetails = BirthDetails(
        year: birthInput.dateTime.year,
        month: birthInput.dateTime.month,
        day: birthInput.dateTime.day,
        hour: birthInput.dateTime.hour,
        minute: birthInput.dateTime.minute,
        second: birthInput.dateTime.second,
        timezone: birthInput.tzOffsetHours.toDouble(),
        latitude: birthInput.latitude,
        longitude: birthInput.longitude,
      );

      // Get all three match types
      final tithiNakshatraMatches =
          VedicBirthdayService.findTithiNakshatraMatches(
              birthDetails, birthInput.tzOffsetHours, _selectedYear!);
      final tithiMonthMatches = VedicBirthdayService.findTithiMonthMatches(
          birthDetails, birthInput.tzOffsetHours, _selectedYear!);
      final nakshatraMonthMatches =
          VedicBirthdayService.findNakshatraMonthMatches(
              birthDetails, birthInput.tzOffsetHours, _selectedYear!);

      final allMatches = <Map<String, dynamic>>[];
      allMatches.addAll(tithiNakshatraMatches);
      allMatches.addAll(tithiMonthMatches);
      allMatches.addAll(nakshatraMonthMatches);

      // Remove duplicates and sort
      final uniqueMatches = <Map<String, dynamic>>[];
      final seenDates = <DateTime>{};

      for (final match in allMatches) {
        final date = match['date'] as DateTime;
        final dateKey = DateTime(date.year, date.month, date.day);
        if (!seenDates.contains(dateKey)) {
          seenDates.add(dateKey);
          uniqueMatches.add(match);
        }
      }

      uniqueMatches.sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      setState(() {
        _matchingDates = uniqueMatches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calculating dates: $e')),
        );
      }
    }
  }

  void _navigateToDate(Map<String, dynamic> match) {
    final matchDate = match['date'] as DateTime;

    // Navigate back to calendar screen with selected date
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CalendarScreen(
          initialDate: matchDate,
          highlightDate: matchDate,
        ),
      ),
    );
  }

  Widget _buildPersonSuggestions(List<Person> people) {
    final query = _personSearchController.text.trim().toLowerCase();
    final matchingPeople = people.where((person) {
      if (query.isEmpty) return true;
      return person.name.toLowerCase().contains(query) ||
          person.placeName.toLowerCase().contains(query);
    }).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _personSearchController,
              decoration: const InputDecoration(
                labelText: 'Search saved profiles',
                hintText: 'Enter a name or birthplace',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (matchingPeople.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No saved profiles match your search.'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 210),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: matchingPeople.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final person = matchingPeople[index];
                    final selected = person.id == _selectedPerson?.id;
                    return ListTile(
                      selected: selected,
                      leading: CircleAvatar(
                        child: selected
                            ? const Icon(Icons.check)
                            : Text(
                                person.name.isEmpty
                                    ? '?'
                                    : person.name[0].toUpperCase(),
                              ),
                      ),
                      title: Text(person.name),
                      subtitle: Text(
                        '${DateFormat('MMM dd, yyyy').format(person.birthDateTimeLocal)} - ${person.placeName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit profile',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editPerson(person),
                          ),
                          IconButton(
                            tooltip: 'Delete profile',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deletePerson(person),
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _selectedPerson = person;
                          _matchingDates = [];
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Birthday Matches'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              // Person Selection
              const Text(
                'Select Person',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Person>>(
                future: _peopleFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Error: ${snapshot.error}'),
                      ),
                    );
                  }

                  final people = snapshot.data ?? [];
                  if (people.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                                'No people found. Please add a person first.'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () async {
                                final saved =
                                    await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const PersonDetailsForm()),
                                );
                                if (mounted && saved == true) {
                                  _personSearchController.clear();
                                  _reloadPeople();
                                }
                              },
                              child: const Text('Add Person'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return _buildPersonSuggestions(people);
                },
              ),

              const SizedBox(height: 16),

              // Year Selection
              const Text(
                'Select Year',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'Enter Year',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _yearController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Colors.blue.withValues(alpha: 0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Colors.blue.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Colors.blue, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.blue.withValues(alpha: 0.05),
                            labelText: 'Year',
                            hintText: 'e.g., 2026',
                            prefixIcon:
                                const Icon(Icons.event, color: Colors.blue),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.today, color: Colors.blue),
                              onPressed: () {
                                setState(() {
                                  _selectedYear = DateTime.now().year;
                                  _yearController.text =
                                      _selectedYear.toString();
                                  _matchingDates = [];
                                });
                              },
                              tooltip: 'Set to current year',
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a year';
                            }
                            final year = int.tryParse(value);
                            if (year == null) {
                              return 'Please enter a valid year';
                            }
                            if (year < 1900 || year > 2100) {
                              return 'Year must be between 1900 and 2100';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            final year = int.tryParse(value);
                            if (year != null) {
                              setState(() {
                                _selectedYear = year;
                                _matchingDates = [];
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Calculate Button
              ElevatedButton.icon(
                onPressed: (_selectedPerson != null &&
                        _selectedYear != null &&
                        !_isLoading)
                    ? () {
                        if (_formKey.currentState!.validate()) {
                          _calculateMatchingDates();
                        }
                      }
                    : null,
                icon: const Icon(Icons.calculate),
                label: const Text('Calculate Matching Dates'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 16),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_matchingDates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Select a person and year, then tap "Calculate Matching Dates"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _matchingDates.length,
                  itemBuilder: (context, index) {
                    final match = _matchingDates[index];
                    final matchDate = match['date'] as DateTime;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${matchDate.day}')),
                        title: Text(
                          DateFormat('EEEE, MMMM dd, yyyy').format(matchDate),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${match['match_type']}'),
                            Text('Tithi: ${match['tithi_name']}'),
                            Text('Nakshatra: ${match['nakshatra_name']}'),
                            Text('Masam: ${match['lunar_month']}'),
                            Text(
                              'Time: ${DateFormat('h:mm a').format(match['time'] as DateTime)}',
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _navigateToDate(match),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
