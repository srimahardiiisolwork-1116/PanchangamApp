import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../models/person.dart';
import '../../providers/providers.dart';
import '../../services/geocoding_service.dart';
import 'map_location_picker.dart';

class PersonDetailsForm extends ConsumerStatefulWidget {
  final Position? initialLocation;
  final Person? existingPerson;

  const PersonDetailsForm(
      {super.key, this.initialLocation, this.existingPerson});

  @override
  ConsumerState<PersonDetailsForm> createState() => _PersonDetailsFormState();
}

class _PersonDetailsFormState extends ConsumerState<PersonDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 42);
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isResolvingLocation = false;
  String? _locationError;
  Timer? _searchDebounce;
  int _searchRequest = 0;

  List<GeocodingResult> _searchResults = [];
  GeocodingResult? _selectedLocation;
  double? _selectedTimezoneOffset;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingPerson;
    if (existing != null) {
      _nameController.text = existing.name;
      _selectedDate = existing.birthDateTimeLocal;
      _selectedTime = TimeOfDay.fromDateTime(existing.birthDateTimeLocal);
      _selectedLocation = GeocodingResult(
        displayName: existing.placeName,
        lat: existing.latitude,
        lon: existing.longitude,
      );
      _selectedTimezoneOffset = existing.tzOffsetHours;
      _searchController.text = existing.placeName;
      return;
    }

    final initial = widget.initialLocation;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectCoordinates(
          LatLng(initial.latitude, initial.longitude),
          fallbackName: 'Current location',
        );
      });
    }
  }

  DateTime get _birthDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  bool _isSelected(GeocodingResult location) =>
      _selectedLocation?.displayName == location.displayName &&
      _selectedLocation?.lat == location.lat &&
      _selectedLocation?.lon == location.lon;

  void _onLocationSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    final request = ++_searchRequest;

    setState(() {
      if (_selectedLocation != null &&
          query != _selectedLocation!.displayName) {
        _selectedLocation = null;
        _selectedTimezoneOffset = null;
      }
      _locationError = null;
      _searchResults = [];
      _isSearching = query.length >= 2;
    });

    if (query.length < 2) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchLocations(query, request),
    );
  }

  Future<void> _searchLocations(String query, int request) async {
    try {
      final results =
          await ref.read(geocodingProvider).search(query, countryCodes: 'in');
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _isSearching = false;
        _searchResults = results;
        _locationError = results.isEmpty ? 'No matching places found.' : null;
      });
    } catch (_) {
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _locationError = 'Location search is unavailable right now.';
      });
    }
  }

  Future<void> _selectLocation(GeocodingResult location) async {
    _searchDebounce?.cancel();
    _searchRequest++;
    setState(() {
      _selectedLocation = location;
      _selectedTimezoneOffset = null;
      _searchResults = [];
      _isSearching = false;
      _isResolvingLocation = true;
      _locationError = null;
      _searchController.value = TextEditingValue(
        text: location.displayName,
        selection: TextSelection.collapsed(
          offset: location.displayName.length,
        ),
      );
    });
    await _refreshTimezone(location);
  }

  Future<void> _refreshTimezone(GeocodingResult location) async {
    if (mounted && _isSelected(location)) {
      setState(() => _isResolvingLocation = true);
    }
    try {
      final offset = await ref
          .read(timezoneServiceProvider)
          .offsetHours(location.lat, location.lon, _birthDateTime);
      if (!mounted || !_isSelected(location)) return;
      setState(() {
        _selectedTimezoneOffset = offset;
        _isResolvingLocation = false;
        _locationError = null;
      });
    } catch (_) {
      if (!mounted || !_isSelected(location)) return;
      setState(() {
        _selectedTimezoneOffset = null;
        _isResolvingLocation = false;
        _locationError = 'Could not determine the timezone for this place.';
      });
    }
  }

  Future<void> _selectCoordinates(
    LatLng coordinates, {
    required String fallbackName,
  }) async {
    setState(() {
      _isResolvingLocation = true;
      _locationError = null;
    });

    var location = GeocodingResult(
      displayName: fallbackName,
      lat: coordinates.latitude,
      lon: coordinates.longitude,
    );
    try {
      location = await ref
              .read(geocodingProvider)
              .reverse(coordinates.latitude, coordinates.longitude) ??
          location;
    } catch (_) {
      // Coordinates still provide a usable location if address lookup fails.
    }
    if (!mounted) return;
    await _selectLocation(location);
  }

  Future<void> _useCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on location services to use your position.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _selectCoordinates(
        LatLng(position.latitude, position.longitude),
        fallbackName: 'Current location',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openMapPicker() async {
    final current = _selectedLocation == null
        ? null
        : LatLng(_selectedLocation!.lat, _selectedLocation!.lon);
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapLocationPicker(initialLocation: current),
      ),
    );
    if (result != null) {
      await _selectCoordinates(
        result,
        fallbackName:
            '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}',
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingPerson == null
            ? 'Add Person Details'
            : 'Edit Profile'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Person Name *',
                  hintText: 'Enter person\'s name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter person\'s name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Birth Date'),
                subtitle:
                    Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDate,
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Birth Time'),
                subtitle: Text(_selectedTime.format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: _selectTime,
              ),
              const SizedBox(height: 16),
              const Text(
                'Location Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Location *',
                  hintText: 'Search for a city, locality, or address',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _onLocationSearchChanged,
                validator: (_) => _selectedLocation == null
                    ? 'Search for and select a location'
                    : null,
              ),
              if (_searchResults.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final location = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            location.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectLocation(location),
                        );
                      },
                    ),
                  ),
                ),
              if (_locationError != null && _selectedLocation == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _locationError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use Current'),
                      onPressed:
                          _isResolvingLocation ? null : _useCurrentLocation,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Pick on Map'),
                      onPressed: _isResolvingLocation ? null : _openMapPicker,
                    ),
                  ),
                ],
              ),
              if (_selectedLocation != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedLocation!.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Latitude: ${_selectedLocation!.lat.toStringAsFixed(4)}  '
                        'Longitude: ${_selectedLocation!.lon.toStringAsFixed(4)}',
                      ),
                      const SizedBox(height: 4),
                      if (_isResolvingLocation)
                        const Text('Finding timezone...')
                      else if (_selectedTimezoneOffset != null)
                        Text(
                            'Timezone: UTC${_formatOffset(_selectedTimezoneOffset!)}')
                      else
                        Text(
                          _locationError ?? 'Timezone unavailable',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed:
                    _isLoading || _isResolvingLocation ? null : _savePerson,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.existingPerson == null
                        ? 'Save Person'
                        : 'Update Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatOffset(double offset) {
    final sign = offset < 0 ? '-' : '+';
    final absoluteMinutes = (offset.abs() * 60).round();
    final hours = absoluteMinutes ~/ 60;
    final minutes = absoluteMinutes % 60;
    return '$sign${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || picked == _selectedDate) return;
    setState(() => _selectedDate = picked);
    final location = _selectedLocation;
    if (location != null) await _refreshTimezone(location);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null || picked == _selectedTime) return;
    setState(() => _selectedTime = picked);
    final location = _selectedLocation;
    if (location != null) await _refreshTimezone(location);
  }

  Future<void> _savePerson() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) return;
    setState(() => _isLoading = true);

    try {
      final location = _selectedLocation!;
      final timezone = _selectedTimezoneOffset ??
          await ref
              .read(timezoneServiceProvider)
              .offsetHours(location.lat, location.lon, _birthDateTime);
      final person = Person(
        id: widget.existingPerson?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        birthDateTimeLocal: _birthDateTime,
        latitude: location.lat,
        longitude: location.lon,
        tzOffsetHours: timezone,
        placeName: location.displayName,
      );
      await ref.read(repositoryProvider).savePerson(person);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingPerson == null
              ? 'Person saved successfully!'
              : 'Profile updated successfully!'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save person: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
