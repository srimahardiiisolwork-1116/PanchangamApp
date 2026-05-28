import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/providers.dart';
import '../../models/panchangam_models.dart';
import '../../models/person.dart';
import 'input_screen.dart';
import 'results_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<List<Person>>? _peopleFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final repo = ref.read(repositoryProvider);
    _peopleFuture = repo.getPeople();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Family Birthdays'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
          )
        ],
      ),
      body: FutureBuilder<List<Person>>(
        future: _peopleFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
                child: Text('Failed to load profiles: ${snap.error}'));
          }
          final people = snap.data ?? const <Person>[];
          if (people.isEmpty) {
            return const Center(
              child:
                  Text('No profiles yet. Add a person to calculate birthdays.'),
            );
          }

          return ListView.separated(
            itemCount: people.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = people[i];
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(p.name),
                subtitle:
                    Text('${p.placeName}\n${p.birthDateTimeLocal.toString()}'),
                isThreeLine: true,
                onTap: () {
                  final input = BirthInput(
                    dateTime: p.birthDateTimeLocal,
                    latitude: p.latitude,
                    longitude: p.longitude,
                    tzOffsetHours: p.tzOffsetHours,
                  );
                  ref.read(birthInputProvider.notifier).state = input;
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ResultsScreen()),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await repo.deletePerson(p.id);
                    if (!mounted) return;
                    setState(_refresh);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const InputScreen()));
          if (!mounted) return;
          setState(_refresh);
        },
        label: const Text('Add Person'),
        icon: const Icon(Icons.person_add_alt),
      ),
    );
  }
}
