import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../favorites/widgets/favorite_button.dart';
import 'data/locale_models.dart';
import 'locales_controller.dart';

class LocaleDetailScreen extends ConsumerWidget {
  const LocaleDetailScreen({super.key, required this.localeId});

  final String localeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(localeDetailProvider(localeId));

    return Scaffold(
      body: asyncDetail.when(
        data: (l) => _DetailBody(locale: l),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('Errore: $e')),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.locale});
  final LocaleDetail locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          actions: [FavoriteButton(localeId: locale.id)],
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              locale.name,
              style: const TextStyle(shadows: [Shadow(blurRadius: 4)]),
            ),
            background: locale.primaryMediaUrl != null
                ? CachedNetworkImage(
                    imageUrl: locale.primaryMediaUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.black12),
                    errorWidget: (_, __, ___) =>
                        Container(color: theme.colorScheme.surfaceContainerHighest),
                  )
                : Container(color: theme.colorScheme.surfaceContainerHighest),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Chip(label: Text(locale.type)),
                  const SizedBox(width: 8),
                  if (locale.rating != null) ...[
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(locale.rating!.toStringAsFixed(1)),
                    const SizedBox(width: 12),
                  ],
                  Text('€' * locale.priceLevel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              Text('${locale.address}, ${locale.city}',
                  style: theme.textTheme.bodyLarge),
              if (locale.description != null) ...[
                const SizedBox(height: 16),
                Text(locale.description!),
              ],
              if (locale.phone != null || locale.website != null) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (locale.phone != null) ...[
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.phone),
                          label: const Text('Prenota'),
                          onPressed: () async {
                            final uri = Uri(scheme: 'tel', path: locale.phone);
                            await launchUrl(uri);
                          },
                        ),
                      ),
                      if (locale.website != null) const SizedBox(width: 12),
                    ],
                    if (locale.website != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.language),
                          label: const Text('Sito web'),
                          onPressed: () async {
                            final url = locale.website!;
                            final uri = Uri.parse(
                              url.startsWith('http') ? url : 'https://$url',
                            );
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          },
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Text('Orari', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._buildHoursRows(context, locale.openingHours),
              const SizedBox(height: 24),
              Text('Posizione', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(locale.latitude, locale.longitude),
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'it.considera.andiamo',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(locale.latitude, locale.longitude),
                            width: 40,
                            height: 40,
                            child: Icon(Icons.location_on,
                                size: 36, color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  static const _weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  List<Widget> _buildHoursRows(BuildContext context, List<OpeningHoursEntry> hours) {
    final byDay = {for (final h in hours) h.weekday: h};
    return [
      for (var i = 0; i < 7; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(width: 48, child: Text(_weekdays[i])),
              Text(_hoursLabel(byDay[i])),
            ],
          ),
        ),
    ];
  }

  String _hoursLabel(OpeningHoursEntry? entry) {
    if (entry == null || entry.closedAllDay) return 'chiuso';
    return '${entry.openTime.substring(0, 5)} – ${entry.closeTime.substring(0, 5)}';
  }
}
