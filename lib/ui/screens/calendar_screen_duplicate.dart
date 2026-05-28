import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_providers.dart';
import '../../providers/providers.dart';
import '../../models/panchangam_models.dart';
import '../../models/person.dart';
import '../../models/birth_details.dart';
import '../../services/vedic_birthday_service.dart';
import 'person_details_form.dart';
import 'year_selection_screen.dart';

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
  bool _isLoading = false;
  int _currentYear = DateTime.now().year;
  bool _showMonths = false;
  bool _showYears = false;
  
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
    _loadCalendarEvents();
  }

  Future<void> _loadCalendarEvents() async {
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(repositoryProvider);
      final people = await repo.getPeople();
      final events = <DateTime, List<Map<String, dynamic>>>{};
      
      // Show birthdays for multiple years (current year to +10 years)
      final currentYear = DateTime.now().year;
      final years = List.generate(11, (index) => currentYear + index);
      
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
        
        // Calculate matches for multiple years
        for (final year in years) {
          final tithiNakshatraMatches = VedicBirthdayService.findTithiNakshatraMatches(birthDetails, birthInput.tzOffsetHours, year);
          final tithiMonthMatches = VedicBirthdayService.findTithiMonthMatches(birthDetails, birthInput.tzOffsetHours, year);
          final nakshatraMonthMatches = VedicBirthdayService.findNakshatraMonthMatches(birthDetails, birthInput.tzOffsetHours, year);
          
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
          
          uniqueMatches.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
          
          for (final match in uniqueMatches) {
            final matchDate = match['date'] as DateTime;
            final dateKey = DateTime(matchDate.year, matchDate.month, matchDate.day);
            
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
      }
      
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading calendar events: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  void _showTimingDialog(Map<String, dynamic> event) {
    final person = event['person'] as Person;
    final match = event['match'] as Map<String, dynamic>;
    final year = event['year'] as int;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${person.name} - $year'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match Type: ${match['match_type']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              // Tithi Details
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tithi: ${match['tithi_name']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (match['tithi_start_time'] != null)
                      Text('Start: ${_formatDateTime(match['tithi_start_time'])}'),
                    if (match['tithi_end_time'] != null)
                      Text('End: ${_formatDateTime(match['tithi_end_time'])}'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Nakshatra Details
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nakshatra: ${match['nakshatra_name']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (match['nakshatra_start_time'] != null)
                      Text('Start: ${_formatDateTime(match['nakshatra_start_time'])}'),
                    if (match['nakshatra_end_time'] != null)
                      Text('End: ${_formatDateTime(match['nakshatra_end_time'])}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // General Date Info
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${DateFormat('MMMM dd, yyyy').format(match['date'] as DateTime)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('Time: ${DateFormat('h:mm a').format(match['time'] as DateTime)}'),
                  ],
                ),
              ),
            ],
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
  
  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'Not available';
    if (dateTime is DateTime) {
      return DateFormat('MMM dd, yyyy - h:mm a').format(dateTime);
    }
    return dateTime.toString();
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_focusedDay);
    
    if (events.isEmpty) {
      return const Center(
        child: Text('No events on this day'),
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
            title: Text('${person.name} ($year)'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${match['match_type']}'),
                Text(
                  'Tithi: ${match['tithi_name']} (${match['tithi_start_time'] != null ? DateFormat('h:mm a').format(match['tithi_start_time']) : 'N/A'})',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  'Nakshatra: ${match['nakshatra_name']} (${match['nakshatra_start_time'] != null ? DateFormat('h:mm a').format(match['nakshatra_start_time']) : 'N/A'})',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info),
              onPressed: () => _showTimingDialog(event),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showMonthYearPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_focusedDay),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.calendar_today, color: Colors.blue, size: 18),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const YearSelectionScreen()),
              );
            },
            tooltip: 'Find Specific Date',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCalendarEvents,
          ),
        ],
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.keyboard_arrow_left),
                                        onPressed: () {
                                          setState(() {
                                            _currentYear--;
                                          });
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
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _currentYear.toString(),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.keyboard_arrow_right),
                                        onPressed: () {
                                          setState(() {
                                            _currentYear++;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Month Grid
                                  Expanded(
                                    child: GridView.builder(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        childAspectRatio: 2.5,
                                      ),
                                      itemCount: 12,
                                      itemBuilder: (context, index) {
                                        final month = index + 1;
                                        final isSelected = month == _focusedDay.month;
                                        
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _showMonths = false;
                                              _focusedDay = DateTime(_currentYear, month, 1);
                                            });
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.blue : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                DateFormat('MMM').format(DateTime(_currentYear, month, 1)),
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : Colors.black,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.blue : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                year.toString(),
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : Colors.black,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                    Expanded(
                      flex: MediaQuery.of(context).orientation == Orientation.landscape ? 8 : 7,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: TableCalendar<Map<String, dynamic>>(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          eventLoader: _getEventsForDay,
                          calendarStyle: CalendarStyle(
                            markersMaxCount: 3,
                            markerDecoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: widget.highlightDate != null ? Colors.red : Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            leftChevronVisible: false,
                            rightChevronVisible: false,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            headerPadding: const EdgeInsets.symmetric(vertical: 8),
                            formatButtonDecoration: BoxDecoration(
                              color: Colors.blue,
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
                            setState(() {
                              _focusedDay = focusedDay;
                              _currentYear = focusedDay.year;
                            });
                          },
                        ),
                      ),
                    ),
                    
                    // Event List (takes less space in landscape)
                    Expanded(
                      flex: MediaQuery.of(context).orientation == Orientation.landscape ? 2 : 3,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
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
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PersonDetailsForm()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Person'),
      ),
    );
  }
}
