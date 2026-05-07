import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/location/location_service.dart';
import '../../core/widgets/empty_state.dart';
import '../favorites/widgets/favorite_button.dart';
import '../recommendations/data/recommendation_models.dart';
import '../recommendations/data/recommendations_api.dart';
import 'data/locale_models.dart';
import 'locales_controller.dart';

class EsploraScreen extends ConsumerStatefulWidget {
  const EsploraScreen({super.key});

  @override
  ConsumerState<EsploraScreen> createState() => _EsploraScreenState();
}

enum _ViewMode { list, map }

enum _Source { tonight, all }

class _EsploraScreenState extends ConsumerState<EsploraScreen> {
  _ViewMode _mode = _ViewMode.list;
  _Source _source = _Source.tonight;

  @override
  Widget build(BuildContext context) {
    final asyncTonight = ref.watch(tonightRecommendationsProvider);
    final asyncAll = ref.watch(localesListProvider);
    final query = ref.watch(localesQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Esplora'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna posizione',
            icon: const Icon(Icons.my_location),
            onPressed: () {
              ref.invalidate(currentLocationProvider);
              ref.invalidate(tonightRecommendationsProvider);
              ref.invalidate(localesListProvider);
            },
          ),
          IconButton(
            tooltip: _mode == _ViewMode.list ? 'Mappa' : 'Lista',
            icon: Icon(_mode == _ViewMode.list ? Icons.map_outlined : Icons.list),
            onPressed: () => setState(() {
              _mode = _mode == _ViewMode.list ? _ViewMode.map : _ViewMode.list;
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          _SourceToggle(
            source: _source,
            onChanged: (s) => setState(() => _source = s),
          ),
          const _LocationChip(),
          if (_source == _Source.all)
            _FilterBar(
              query: query,
              onChange: (q) => ref.read(localesQueryProvider.notifier).state = q,
            ),
          Expanded(
            child: _source == _Source.tonight
                ? asyncTonight.when(
                    data: (recs) => _mode == _ViewMode.list
                        ? _RecommendationsList(items: recs)
                        : _LocalesMap(locales: recs),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _ErrorBox(error: e),
                  )
                : asyncAll.when(
                    data: (locales) => _mode == _ViewMode.list
                        ? _LocalesList(locales: locales)
                        : _LocalesMap(locales: locales),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _ErrorBox(error: e),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LocationChip extends ConsumerWidget {
  const _LocationChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPos = ref.watch(currentLocationProvider);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: asyncPos.when(
              data: (p) => Text(
                'Posizione: ${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              loading: () => Text('Posizione: ...',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              error: (_, __) => Text('Posizione non disponibile',
                  style: TextStyle(fontSize: 11, color: scheme.error)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceToggle extends StatelessWidget {
  const _SourceToggle({required this.source, required this.onChanged});
  final _Source source;
  final ValueChanged<_Source> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SegmentedButton<_Source>(
        segments: const [
          ButtonSegment(
            value: _Source.tonight,
            label: Text('Stasera per te'),
            icon: Icon(Icons.auto_awesome),
          ),
          ButtonSegment(
            value: _Source.all,
            label: Text('Tutti'),
            icon: Icon(Icons.public),
          ),
        ],
        selected: {source},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Errore di caricamento.\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.query, required this.onChange});

  final LocalesQuery query;
  final ValueChanged<LocalesQuery> onChange;

  static const _types = <String>[
    'bar',
    'ristorante',
    'pizzeria',
    'caffe',
    'pub',
    'club',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          FilterChip(
            label: const Text('Aperto adesso'),
            selected: query.openNow,
            onSelected: (v) => onChange(LocalesQuery(type: query.type, openNow: v)),
          ),
          const SizedBox(width: 8),
          ..._types.map((t) {
            final selected = query.type == t;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(t),
                selected: selected,
                onSelected: (v) => onChange(
                  LocalesQuery(type: v ? t : null, openNow: query.openNow),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LocaleTile extends StatelessWidget {
  const _LocaleTile({required this.locale, this.score, this.reasons});
  final LocaleSummary locale;
  final double? score;
  final List<String>? reasons;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/locales/${locale.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(20)),
              child: SizedBox(
                width: 100,
                height: 110,
                child: locale.primaryMediaUrl != null
                    ? CachedNetworkImage(
                        imageUrl: locale.primaryMediaUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.black12),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.storefront, size: 36),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            locale.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (score != null) _MatchBadge(score: score!),
                        FavoriteButton(localeId: locale.id, size: 20),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${locale.type} · ${locale.city}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (locale.rating != null) ...[
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(locale.rating!.toStringAsFixed(1)),
                          const SizedBox(width: 8),
                        ],
                        Text('€' * locale.priceLevel,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (locale.distanceM != null)
                          Text(_formatDistance(locale.distanceM!)),
                      ],
                    ),
                    if (reasons != null && reasons!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        reasons!.join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LocalesList extends StatelessWidget {
  const _LocalesList({required this.locales});
  final List<LocaleSummary> locales;

  @override
  Widget build(BuildContext context) {
    if (locales.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Nessun locale trovato',
        message: 'Prova a cambiare i filtri o a cercare in un\'altra città.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: locales.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _LocaleTile(locale: locales[i]),
    );
  }
}

class _RecommendationsList extends StatelessWidget {
  const _RecommendationsList({required this.items});
  final List<Recommendation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'Nessun consiglio per stasera',
        message:
            'Prova ad allargare il raggio, alzare il budget o aggiornare le preferenze nel profilo.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _LocaleTile(
        locale: items[i],
        score: items[i].score,
        reasons: items[i].reasons,
      ),
    );
  }
}

class _LocalesMap extends StatelessWidget {
  const _LocalesMap({required this.locales});
  final List<LocaleSummary> locales;

  @override
  Widget build(BuildContext context) {
    if (locales.isEmpty) {
      return const Center(child: Text('Nessun locale da mostrare.'));
    }
    final center = LatLng(locales.first.latitude, locales.first.longitude);
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 11),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'it.considera.andiamo',
        ),
        MarkerLayer(
          markers: [
            for (final l in locales)
              Marker(
                point: LatLng(l.latitude, l.longitude),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => context.push('/locales/${l.id}'),
                  child: Icon(Icons.location_on,
                      size: 36, color: Theme.of(context).colorScheme.primary),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
