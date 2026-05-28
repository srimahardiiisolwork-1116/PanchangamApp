),
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: _buildEventList(),
              ),
            ],
          ),
        ),
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
