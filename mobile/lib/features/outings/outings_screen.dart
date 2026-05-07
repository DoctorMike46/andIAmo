import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/empty_state.dart';
import '../friends/data/friends_api.dart';
import 'data/outings_api.dart';

class OutingsScreen extends ConsumerWidget {
  const OutingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOutings = ref.watch(outingsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uscite'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuova uscita',
            onPressed: () => _openCreateSheet(context, ref),
          ),
        ],
      ),
      body: asyncOutings.when(
        data: (outings) {
          if (outings.isEmpty) {
            return EmptyState(
              icon: Icons.celebration_outlined,
              title: 'Organizza la prima serata',
              message:
                  'Scegli gli amici, lascia che andIAmo trovi il locale perfetto per il gruppo.',
              actionLabel: 'Crea uscita',
              onAction: () => _openCreateSheet(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(outingsListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: outings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _OutingCard(outing: outings[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateOutingSheet(),
    );
    ref.invalidate(outingsListProvider);
  }
}

class _OutingCard extends StatelessWidget {
  const _OutingCard({required this.outing});
  final OutingOut outing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('EEE d MMM · HH:mm', 'it_IT');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/uscite/${outing.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      outing.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _StatusChip(status: outing.status),
                ],
              ),
              const SizedBox(height: 4),
              if (outing.whenDt != null)
                Text(dateFmt.format(outing.whenDt!.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 16, color: scheme.outline),
                  const SizedBox(width: 4),
                  Text('${outing.participants.length} persone',
                      style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  if (outing.chosenLocaleId != null) ...[
                    Icon(Icons.place, size: 16, color: scheme.primary),
                    const SizedBox(width: 4),
                    Text('Locale scelto',
                        style: TextStyle(color: scheme.primary, fontSize: 12)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  static const _labels = {
    'planning': 'In corso',
    'decided': 'Deciso',
    'done': 'Concluso',
    'cancelled': 'Annullato',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      'decided' => scheme.tertiary,
      'done' => scheme.outline,
      'cancelled' => scheme.error,
      _ => scheme.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _labels[status] ?? status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CreateOutingSheet extends ConsumerStatefulWidget {
  const _CreateOutingSheet();

  @override
  ConsumerState<_CreateOutingSheet> createState() => _CreateOutingSheetState();
}

class _CreateOutingSheetState extends ConsumerState<_CreateOutingSheet> {
  final _title = TextEditingController();
  DateTime? _whenDt;
  final Set<String> _selectedFriends = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 21, minute: 0),
    );
    if (time == null) return;
    setState(() {
      _whenDt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Inserisci un titolo.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(outingsApiProvider).create(
            title: _title.text.trim(),
            whenDt: _whenDt,
            participantIds: _selectedFriends.toList(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?.toString() ?? 'Errore');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncFriends = ref.watch(friendsListProvider);
    final dateFmt = DateFormat('EEE d MMM · HH:mm', 'it_IT');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nuova uscita', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titolo *'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(_whenDt == null ? 'Quando? (opzionale)' : dateFmt.format(_whenDt!)),
                onPressed: _pickDateTime,
              ),
              const SizedBox(height: 16),
              Text('Invita amici', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: asyncFriends.when(
                  data: (friends) {
                    if (friends.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Non hai ancora amici. Vai nella tab Amici per cercarne.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final f in friends)
                          CheckboxListTile(
                            value: _selectedFriends.contains(f.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedFriends.add(f.id);
                              } else {
                                _selectedFriends.remove(f.id);
                              }
                            }),
                            title: Text(f.displayName),
                            subtitle: Text(f.email),
                          ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crea'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
