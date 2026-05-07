import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../recommendations/data/recommendations_api.dart';
import 'data/preferences_api.dart';

const _cuisines = [
  'italiana',
  'pizza',
  'giapponese',
  'cinese',
  'messicana',
  'indiana',
  'mediorientale',
  'vegetariana',
  'pesce',
  'carne',
];
const _moods = ['chill', 'romantico', 'festoso', 'business', 'famiglia', 'aperitivo'];
const _dietary = ['vegetariana', 'vegana', 'senza glutine', 'halal', 'kosher'];
const _avoidableTypes = ['bar', 'ristorante', 'pizzeria', 'caffe', 'pub', 'club'];

class EditPreferencesScreen extends ConsumerStatefulWidget {
  const EditPreferencesScreen({super.key});

  @override
  ConsumerState<EditPreferencesScreen> createState() => _EditPreferencesScreenState();
}

class _EditPreferencesScreenState extends ConsumerState<EditPreferencesScreen> {
  Preferences? _draft;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_draft == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(preferencesApiProvider).update(_draft!);
      ref.invalidate(myPreferencesProvider);
      ref.invalidate(tonightRecommendationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferenze aggiornate.')),
      );
      context.pop();
    } on DioException catch (e) {
      setState(() => _error = 'Errore: ${e.response?.statusCode ?? 'rete'}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncPrefs = ref.watch(myPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Le mie preferenze'),
        actions: [
          TextButton(
            onPressed: (_draft != null && !_saving) ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salva'),
          ),
        ],
      ),
      body: asyncPrefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (prefs) {
          _draft ??= prefs;
          final d = _draft!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space4,
              AppTheme.space4,
              AppTheme.space4,
              120,
            ),
            children: [
              _SectionHeader('Cucine preferite'),
              _MultiChips(
                options: _cuisines,
                selected: d.cuisines.toSet(),
                onToggle: (v) => setState(() {
                  final set = d.cuisines.toSet();
                  set.contains(v) ? set.remove(v) : set.add(v);
                  _draft = d.copyWith(cuisines: set.toList());
                }),
              ),
              const SizedBox(height: AppTheme.space5),
              _SectionHeader('Vibe / mood'),
              _MultiChips(
                options: _moods,
                selected: d.moods.toSet(),
                onToggle: (v) => setState(() {
                  final set = d.moods.toSet();
                  set.contains(v) ? set.remove(v) : set.add(v);
                  _draft = d.copyWith(moods: set.toList());
                }),
              ),
              const SizedBox(height: AppTheme.space5),
              _SectionHeader('Restrizioni dietetiche'),
              _MultiChips(
                options: _dietary,
                selected: d.dietary.toSet(),
                onToggle: (v) => setState(() {
                  final set = d.dietary.toSet();
                  set.contains(v) ? set.remove(v) : set.add(v);
                  _draft = d.copyWith(dietary: set.toList());
                }),
              ),
              const SizedBox(height: AppTheme.space5),
              _SectionHeader('Tipi da evitare'),
              _MultiChips(
                options: _avoidableTypes,
                selected: d.avoidTypes.toSet(),
                onToggle: (v) => setState(() {
                  final set = d.avoidTypes.toSet();
                  set.contains(v) ? set.remove(v) : set.add(v);
                  _draft = d.copyWith(avoidTypes: set.toList());
                }),
              ),
              const SizedBox(height: AppTheme.space5),
              _SectionHeader('Budget massimo'),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 1; i <= 4; i++)
                    ChoiceChip(
                      label: Text('€' * i),
                      selected: d.budgetMax == i,
                      onSelected: (_) => setState(() {
                        _draft = d.copyWith(budgetMax: i);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.space5),
              _SectionHeader('Raggio massimo'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2),
                child: Row(
                  children: [
                    Text('${d.maxDistanceKm.toStringAsFixed(1)} km',
                        style: Theme.of(context).textTheme.titleMedium),
                    Expanded(
                      child: Slider(
                        min: 1,
                        max: 30,
                        divisions: 29,
                        value: d.maxDistanceKm.clamp(1, 30),
                        onChanged: (v) => setState(() {
                          _draft = d.copyWith(maxDistanceKm: v);
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppTheme.space4),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _MultiChips extends StatelessWidget {
  const _MultiChips({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          FilterChip(
            label: Text(o),
            selected: selected.contains(o),
            onSelected: (_) => onToggle(o),
          ),
      ],
    );
  }
}
