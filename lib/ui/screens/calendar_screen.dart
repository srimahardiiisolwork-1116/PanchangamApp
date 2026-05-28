import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../providers/auth_providers.dart';
import '../../providers/providers.dart';
import '../../models/panchangam_models.dart';
import '../../models/person.dart';
import '../../models/birth_details.dart';
import '../../services/vedic_birthday_service.dart';
import '../../services/geonames_service.dart';
import '../../services/drikpanchang_service.dart';
import 'person_details_form.dart';
import 'year_selection_screen.dart';

enum _CalendarMenuAction { refresh, logout }

class CalendarScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final DateTime? highlightDate;

  const CalendarScreen({
    super.key,
    this.initialDate,
    this.highlightDate,
  });

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  final Map<int, Map<DateTime, List<Map<String, dynamic>>>> _eventsByYearCache =
      {};
  bool _isLoading = false;
  int _currentYear = DateTime.now().year;
  bool _showMonths = false;
  bool _showYears = false;
  int _loadRequest = 0;

  void _showMonthYearPicker() {
    setState(() {
      _showMonths = !_showMonths;
      _showYears = false;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _focusedDay = widget.initialDate!;
      _selectedDay = widget.initialDate!;
      _currentYear = widget.initialDate!.year;
    } else {
      _currentYear = _focusedDay.year;
    }
    _loadCalendarEventsForYear(_currentYear);
  }

  Future<void> _loadCalendarEventsForYear(int year,
      {bool forceReload = false}) async {
    final request = ++_loadRequest;
    if (!forceReload && _eventsByYearCache.containsKey(year)) {
      if (!mounted) return;
      setState(() {
        _events = _eventsByYearCache[year]!;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(repositoryProvider);
      final people = await repo.getPeople();
      final events = <DateTime, List<Map<String, dynamic>>>{};

      for (final person in people) {
        final birthInput = BirthInput(
          dateTime: person.birthDateTimeLocal,
          latitude: person.latitude,
          longitude: person.longitude,
          tzOffsetHours: person.tzOffsetHours,
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

        final tithiNakshatraMatches =
            VedicBirthdayService.findTithiNakshatraMatches(
                birthDetails, birthInput.tzOffsetHours, year);
        final tithiMonthMatches = VedicBirthdayService.findTithiMonthMatches(
            birthDetails, birthInput.tzOffsetHours, year);
        final nakshatraMonthMatches =
            VedicBirthdayService.findNakshatraMonthMatches(
                birthDetails, birthInput.tzOffsetHours, year);

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

        for (final match in uniqueMatches) {
          final matchDate = match['date'] as DateTime;
          final matchTimeLocal = match['time'] as DateTime;
          final dateKey =
              DateTime(matchDate.year, matchDate.month, matchDate.day);

          final timingDetails = VedicBirthdayService.getMatchTiming(
            birthDetails,
            matchDate,
            matchTimeLocal,
            match['match_type'] as String,
          );

          final tithiTiming =
              timingDetails['tithi_timing'] as Map<String, dynamic>?;
          final nakshatraTiming =
              timingDetails['nakshatra_timing'] as Map<String, dynamic>?;

          if (tithiTiming != null) {
            match['tithi_start_time'] = tithiTiming['start_time'];
            match['tithi_end_time'] = tithiTiming['end_time'];
          }
          if (nakshatraTiming != null) {
            match['nakshatra_start_time'] = nakshatraTiming['start_time'];
            match['nakshatra_end_time'] = nakshatraTiming['end_time'];
          }

          if (!events.containsKey(dateKey)) {
            events[dateKey] = [];
          }
          events[dateKey]!.add({
            'person': person,
            'match': match,
            'year': year,
          });
        }
      }

      if (!mounted || request != _loadRequest) return;
      setState(() {
        _events = events;
        _eventsByYearCache[year] = events;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || request != _loadRequest) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading calendar events: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  void _showTimingDialog(BuildContext context, Map<String, dynamic> event) {
    final person = event['person'] as Person;
    final match = event['match'] as Map<String, dynamic>;
    final date = match['date'] as DateTime;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('${person.name} - ${DateFormat('MMM dd, yyyy').format(date)}'),
        content: SizedBox(
          width: MediaQuery.of(context).orientation == Orientation.landscape
              ? 350
              : 450,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _loadTimingWithFallback(person, date, match),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final data = snapshot.data;
              if (data == null) {
                return const SizedBox(
                  height: 100,
                  child: Text('Failed to load timings.'),
                );
              }
              final offline = data['offline'] as bool;
              final tithi = data['tithi'] as Map<String, dynamic>?;
              final nakshatra = data['nakshatra'] as Map<String, dynamic>?;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Match Type: ${match['match_type']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: MediaQuery.of(context).orientation ==
                                Orientation.landscape
                            ? 12
                            : 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (offline)
                      Text(
                        'Note: Times are calculated offline and may differ by ~25 minutes from some Panchang sources.',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).orientation ==
                                  Orientation.landscape
                              ? 9
                              : 11,
                          color: Colors.grey[700],
                        ),
                      ),
                    if (offline) const SizedBox(height: 12),
                    if ((match['match_type'] as String).contains('Tithi') &&
                        tithi != null) ...[
                      if (tithi['start_time'] != null)
                        Text(
                          '${tithi['name'] ?? tithi['tithi_name']}${tithi['name_te'] != null ? ' (${tithi['name_te']})' : ''} Tithi Begins - ${_formatTime(tithi['start_time'])} on ${DateFormat('MMM dd, yyyy').format(tithi['start_time'] as DateTime)}',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).orientation ==
                                    Orientation.landscape
                                ? 10
                                : 12,
                          ),
                        ),
                      if (tithi['end_time'] != null)
                        Text(
                          '${tithi['name'] ?? tithi['tithi_name']}${tithi['name_te'] != null ? ' (${tithi['name_te']})' : ''} Tithi Ends - ${_formatTime(tithi['end_time'])} on ${DateFormat('MMM dd, yyyy').format(tithi['end_time'] as DateTime)}',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).orientation ==
                                    Orientation.landscape
                                ? 10
                                : 12,
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if ((match['match_type'] as String).contains('Nakshatra') &&
                        nakshatra != null) ...[
                      if (nakshatra['start_time'] != null)
                        Text(
                          '${nakshatra['name'] ?? nakshatra['nakshatra_name']}${nakshatra['name_te'] != null ? ' (${nakshatra['name_te']})' : ''} Nakshatra Begins - ${_formatTime(nakshatra['start_time'])} on ${DateFormat('MMM dd, yyyy').format(nakshatra['start_time'] as DateTime)}',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).orientation ==
                                    Orientation.landscape
                                ? 10
                                : 12,
                          ),
                        ),
                      if (nakshatra['end_time'] != null)
                        Text(
                          '${nakshatra['name'] ?? nakshatra['nakshatra_name']}${nakshatra['name_te'] != null ? ' (${nakshatra['name_te']})' : ''} Nakshatra Ends - ${_formatTime(nakshatra['end_time'])} on ${DateFormat('MMM dd, yyyy').format(nakshatra['end_time'] as DateTime)}',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).orientation ==
                                    Orientation.landscape
                                ? 10
                                : 12,
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _loadTimingWithFallback(
      Person person, DateTime date, Map<String, dynamic> match) async {
    // Try online first
    final connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults
        .any((result) => result != ConnectivityResult.none)) {
      final geo = await GeonamesService.reverseLookup(
          person.latitude, person.longitude);
      if (geo != null) {
        final online =
            await DrikPanchangService.fetchTimings(date, geo.geonameId);
        if (online != null) {
          final result = <String, dynamic>{'offline': false};
          if (online.tithi != null) {
            result['tithi'] = {
              'name': online.tithi!.name,
              'start_time': online.tithi!.start,
              'end_time': online.tithi!.end,
            };
          }
          if (online.nakshatra != null) {
            result['nakshatra'] = {
              'name': online.nakshatra!.name,
              'start_time': online.nakshatra!.start,
              'end_time': online.nakshatra!.end,
            };
          }
          return result;
        }
      }
    }

    // Fallback to offline
    final birthDetails = BirthDetails(
      year: person.birthDateTimeLocal.year,
      month: person.birthDateTimeLocal.month,
      day: person.birthDateTimeLocal.day,
      hour: person.birthDateTimeLocal.hour,
      minute: person.birthDateTimeLocal.minute,
      second: person.birthDateTimeLocal.second,
      timezone: person.tzOffsetHours,
      latitude: person.latitude,
      longitude: person.longitude,
    );

    final offlineTiming = VedicBirthdayService.getMatchTiming(
      birthDetails,
      date,
      match['time'] as DateTime,
      match['match_type'] as String,
    );

    final result = <String, dynamic>{'offline': true};
    if (offlineTiming['tithi_timing'] != null) {
      result['tithi'] = {
        'name': offlineTiming['tithi_timing']['tithi_name'],
        'name_te': offlineTiming['tithi_timing']['tithi_name_te'],
        'start_time': offlineTiming['tithi_timing']['start_time'],
        'end_time': offlineTiming['tithi_timing']['end_time'],
      };
    }
    if (offlineTiming['nakshatra_timing'] != null) {
      result['nakshatra'] = {
        'name': offlineTiming['nakshatra_timing']['nakshatra_name'],
        'name_te': offlineTiming['nakshatra_timing']['nakshatra_name_te'],
        'start_time': offlineTiming['nakshatra_timing']['start_time'],
        'end_time': offlineTiming['nakshatra_timing']['end_time'],
      };
    }
    return result;
  }

  String _formatTime(dynamic dateTime) {
    if (dateTime == null) return 'Not available';
    if (dateTime is DateTime) {
      return DateFormat('h:mm a').format(dateTime);
    }
    return dateTime.toString();
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_focusedDay);

    if (events.isEmpty) {
      return Center(
        child: Text(
          'No events for ${DateFormat('MMM dd, yyyy').format(_focusedDay)}',
          style: TextStyle(
            fontSize:
                MediaQuery.of(context).orientation == Orientation.landscape
                    ? 12
                    : 14,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final person = event['person'] as Person;
        final match = event['match'] as Map<String, dynamic>;
        final year = event['year'] as int;
        final matchDate = match['date'] as DateTime;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              child: Text('${matchDate.day}'),
            ),
            title: Text(
              '${person.name} ($year)',
              style: TextStyle(
                fontSize:
                    MediaQuery.of(context).orientation == Orientation.landscape
                        ? 12
                        : 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match['match_type']}',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).orientation ==
                            Orientation.landscape
                        ? 10
                        : 11,
                  ),
                ),
                Text(
                  'Tithi: ${match['tithi_name']}${match['tithi_name_te'] != null ? ' (${match['tithi_name_te']})' : ''} (${match['tithi_start_time'] != null ? DateFormat('h:mm a').format(match['tithi_start_time']) : 'N/A'})',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).orientation ==
                            Orientation.landscape
                        ? 9
                        : 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Nakshatra: ${match['nakshatra_name']}${match['nakshatra_name_te'] != null ? ' (${match['nakshatra_name_te']})' : ''} (${match['nakshatra_start_time'] != null ? DateFormat('h:mm a').format(match['nakshatra_start_time']) : 'N/A'})',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).orientation ==
                            Orientation.landscape
                        ? 9
                        : 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info),
              onPressed: () => _showTimingDialog(context, event),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshAfterProfileChange() async {
    _eventsByYearCache.clear();
    await _loadCalendarEventsForYear(_currentYear, forceReload: true);
  }

  Future<void> _openPersonEditor([Person? person]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PersonDetailsForm(existingPerson: person),
      ),
    );
    if (!mounted || saved != true) return;
    await _refreshAfterProfileChange();
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
    await _refreshAfterProfileChange();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile deleted.')),
    );
  }

  Future<void> _showSavedPeople() async {
    final people = await ref.read(repositoryProvider).getPeople();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Saved Persons',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: people.isEmpty
                      ? const Center(child: Text('No persons saved yet.'))
                      : ListView.builder(
                          controller: controller,
                          itemCount: people.length,
                          itemBuilder: (context, index) {
                            final person = people[index];
                            return ListTile(
                              leading: const Icon(Icons.person),
                              title: Text(person.name),
                              subtitle: Text(
                                '${DateFormat('MMM dd, yyyy').format(person.birthDateTimeLocal)} - ${person.placeName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                setState(() {
                                  _focusedDay = DateTime(
                                    person.birthDateTimeLocal.year,
                                    person.birthDateTimeLocal.month,
                                    person.birthDateTimeLocal.day,
                                  );
                                  _selectedDay = _focusedDay;
                                  _currentYear = _focusedDay.year;
                                });
                                _loadCalendarEventsForYear(_currentYear);
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit profile',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                      _openPersonEditor(person);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete profile',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                      _deletePerson(person);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openBirthdaySearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const YearSelectionScreen()),
    );
    if (!mounted) return;
    await _refreshAfterProfileChange();
  }

  void _handleMenuAction(_CalendarMenuAction action) {
    switch (action) {
      case _CalendarMenuAction.refresh:
        _loadCalendarEventsForYear(_currentYear, forceReload: true);
        return;
      case _CalendarMenuAction.logout:
        ref.read(authServiceProvider).signOut();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 500;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: compactHeader ? 8 : NavigationToolbar.kMiddleSpacing,
        title: GestureDetector(
          onTap: _showMonthYearPicker,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compactHeader ? 8 : 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat(compactHeader ? 'MMM yyyy' : 'MMMM yyyy')
                      .format(_focusedDay),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: compactHeader ? 4 : 8),
                Icon(
                  Icons.calendar_today,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: _showSavedPeople,
            tooltip: 'Saved Persons',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openBirthdaySearch,
            tooltip: 'Find Specific Date',
          ),
          if (!compactHeader) ...[
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authServiceProvider).signOut(),
              tooltip: 'Sign out',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  _loadCalendarEventsForYear(_currentYear, forceReload: true),
              tooltip: 'Refresh',
            ),
          ] else
            PopupMenuButton<_CalendarMenuAction>(
              tooltip: 'More actions',
              onSelected: _handleMenuAction,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _CalendarMenuAction.refresh,
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Refresh'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _CalendarMenuAction.logout,
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Sign out'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Custom Month/Year Navigation Header (only show when active)
                if (_showMonths || _showYears)
                  Container(
                    margin: const EdgeInsets.all(4.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        // Month Navigation
                        if (_showMonths)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            height: MediaQuery.of(context).size.height * 0.3,
                            child: Column(
                              children: [
                                // Year Navigation
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon:
                                          const Icon(Icons.keyboard_arrow_left),
                                      onPressed: () {
                                        setState(() {
                                          _currentYear--;
                                        });
                                        _loadCalendarEventsForYear(
                                            _currentYear);
                                      },
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _showMonths = false;
                                          _showYears = true;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _currentYear.toString(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.keyboard_arrow_right),
                                      onPressed: () {
                                        setState(() {
                                          _currentYear++;
                                        });
                                        _loadCalendarEventsForYear(
                                            _currentYear);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Month Grid
                                Expanded(
                                  child: GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      childAspectRatio: 2.5,
                                    ),
                                    itemCount: 12,
                                    itemBuilder: (context, index) {
                                      final month = index + 1;
                                      final isSelected =
                                          month == _focusedDay.month;

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showMonths = false;
                                            _focusedDay = DateTime(
                                                _currentYear, month, 1);
                                          });
                                          _loadCalendarEventsForYear(
                                              _currentYear);
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Colors.grey
                                                      .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              DateFormat('MMM').format(DateTime(
                                                  _currentYear, month, 1)),
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Year Navigation
                        if (_showYears)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            height: MediaQuery.of(context).size.height * 0.3,
                            child: Column(
                              children: [
                                // Year Grid
                                Expanded(
                                  child: GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      childAspectRatio: 1.2,
                                    ),
                                    itemCount: 20,
                                    itemBuilder: (context, index) {
                                      final year = _currentYear - 10 + index;
                                      final isSelected = year == _currentYear;

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showYears = false;
                                            _showMonths = true;
                                            _currentYear = year;
                                          });
                                          _loadCalendarEventsForYear(
                                              _currentYear);
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Colors.grey
                                                      .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              year.toString(),
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                // Calendar and Events Container
                Expanded(
                  child: Column(
                    children: [
                      // Calendar (takes more space in landscape)
                      Expanded(
                        flex: MediaQuery.of(context).orientation ==
                                Orientation.landscape
                            ? 6
                            : 7,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2)),
                          ),
                          child: TableCalendar<Map<String, dynamic>>(
                            firstDay: DateTime.utc(1900, 1, 1),
                            lastDay: DateTime.utc(2100, 12, 31),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),
                            eventLoader: _getEventsForDay,
                            calendarStyle: CalendarStyle(
                              markersMaxCount: 3,
                              markerDecoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: BoxDecoration(
                                color: widget.highlightDate != null
                                    ? Colors.red
                                    : Colors.blue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              todayDecoration: BoxDecoration(
                                color: Colors.green.shade300,
                                shape: BoxShape.circle,
                              ),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: const TextStyle(
                                fontSize: 0, // Completely hide the title
                                fontWeight: FontWeight.bold,
                                color: Colors.transparent,
                              ),
                              leftChevronVisible: false,
                              rightChevronVisible: false,
                              headerPadding: EdgeInsets.zero, // Remove padding
                              decoration: const BoxDecoration(
                                color: Colors
                                    .transparent, // Make header transparent
                              ),
                              formatButtonDecoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                                _currentYear = focusedDay.year;
                              });
                            },
                            onPageChanged: (focusedDay) {
                              final newYear = focusedDay.year;
                              setState(() {
                                _focusedDay = focusedDay;
                                _currentYear = newYear;
                              });
                              _loadCalendarEventsForYear(newYear);
                            },
                          ),
                        ),
                      ),

                      // Event List (takes less space in landscape)
                      Expanded(
                        flex: MediaQuery.of(context).orientation ==
                                Orientation.landscape
                            ? 2
                            : 3,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2)),
                          ),
                          child: _buildEventList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPersonEditor,
        icon: const Icon(Icons.add),
        label: const Text('Add Person'),
      ),
    );
  }
}
