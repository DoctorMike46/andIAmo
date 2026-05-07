import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'data/onboarding_api.dart';

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

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;

  // Step 1 — consents
  bool _tos = false;
  bool _privacy = false;
  bool _aiProfiling = true;

  // Step 2 — cuisines
  final Set<String> _selectedCuisines = {};

  // Step 3 — moods
  final Set<String> _selectedMoods = {};

  // Step 4 — budget + dietary
  int _budgetMax = 3;
  final Set<String> _selectedDietary = {};

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _canAdvance {
    switch (_step) {
      case 1:
        return _tos && _privacy;
      default:
        return true;
    }
  }

  void _next() {
    if (_step < 4) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(onboardingApiProvider);
      await api.recordConsent(purpose: 'terms_of_service', granted: _tos);
      await api.recordConsent(purpose: 'privacy_policy', granted: _privacy);
      await api.recordConsent(purpose: 'ai_profiling', granted: _aiProfiling);
      await api.savePreferences(PreferencesPayload(
        cuisines: _selectedCuisines.toList(),
        moods: _selectedMoods.toList(),
        dietary: _selectedDietary.toList(),
        avoidTypes: const [],
        budgetMax: _budgetMax,
        maxDistanceKm: 5.0,
      ));
      await ref.read(authControllerProvider.notifier).refreshUser();
    } on DioException catch (e) {
      setState(() {
        _error = 'Errore (${e.response?.statusCode ?? 'rete'}). Riprova.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Progress(step: _step, total: 5),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _IntroStep(),
                  _ConsentsStep(
                    tos: _tos,
                    privacy: _privacy,
                    aiProfiling: _aiProfiling,
                    onTos: (v) => setState(() => _tos = v),
                    onPrivacy: (v) => setState(() => _privacy = v),
                    onAi: (v) => setState(() => _aiProfiling = v),
                  ),
                  _MultiSelectStep(
                    title: 'Cosa ti piace mangiare?',
                    subtitle: 'Scegli quante categorie vuoi (anche zero).',
                    options: _cuisines,
                    selected: _selectedCuisines,
                    onToggle: (o) => setState(() {
                      if (!_selectedCuisines.add(o)) _selectedCuisines.remove(o);
                    }),
                  ),
                  _MultiSelectStep(
                    title: 'Che vibe cerchi?',
                    subtitle: 'Più ne scegli, più variegato sarà il feed.',
                    options: _moods,
                    selected: _selectedMoods,
                    onToggle: (o) => setState(() {
                      if (!_selectedMoods.add(o)) _selectedMoods.remove(o);
                    }),
                  ),
                  _BudgetDietStep(
                    budgetMax: _budgetMax,
                    onBudget: (v) => setState(() => _budgetMax = v),
                    selectedDietary: _selectedDietary,
                    onToggleDietary: (o) => setState(() {
                      if (!_selectedDietary.add(o)) _selectedDietary.remove(o);
                    }),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _submitting ? null : _back,
                      child: const Text('Indietro'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: (_canAdvance && !_submitting) ? _next : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_step == 4 ? 'Inizia' : 'Avanti'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: LinearProgressIndicator(value: (step + 1) / total),
    );
  }
}

class _IntroStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration_outlined, size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Benvenutə!', style: theme.textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(
            'Bastano 4 passaggi per personalizzare i tuoi consigli.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ConsentsStep extends StatelessWidget {
  const _ConsentsStep({
    required this.tos,
    required this.privacy,
    required this.aiProfiling,
    required this.onTos,
    required this.onPrivacy,
    required this.onAi,
  });

  final bool tos;
  final bool privacy;
  final bool aiProfiling;
  final ValueChanged<bool> onTos;
  final ValueChanged<bool> onPrivacy;
  final ValueChanged<bool> onAi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text('Termini e privacy', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Accetto i Termini di Servizio'),
            subtitle: const Text('Necessario per usare l\'app'),
            value: tos,
            onChanged: onTos,
          ),
          SwitchListTile(
            title: const Text('Accetto la Privacy Policy'),
            subtitle: const Text('Necessario per usare l\'app'),
            value: privacy,
            onChanged: onPrivacy,
          ),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Profilazione AI per i suggerimenti'),
            subtitle: const Text(
              'Permetti l\'analisi dei tuoi gusti per consigli personalizzati. '
              'Puoi cambiare idea in qualsiasi momento.',
            ),
            value: aiProfiling,
            onChanged: onAi,
          ),
        ],
      ),
    );
  }
}

class _MultiSelectStep extends StatelessWidget {
  const _MultiSelectStep({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetDietStep extends StatelessWidget {
  const _BudgetDietStep({
    required this.budgetMax,
    required this.onBudget,
    required this.selectedDietary,
    required this.onToggleDietary,
  });

  final int budgetMax;
  final ValueChanged<int> onBudget;
  final Set<String> selectedDietary;
  final ValueChanged<String> onToggleDietary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Budget e restrizioni', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text('Budget massimo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 1; i <= 4; i++)
                ChoiceChip(
                  label: Text('€' * i),
                  selected: budgetMax == i,
                  onSelected: (_) => onBudget(i),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Restrizioni dietetiche', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _dietary)
                FilterChip(
                  label: Text(d),
                  selected: selectedDietary.contains(d),
                  onSelected: (_) => onToggleDietary(d),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
