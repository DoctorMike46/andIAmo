import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/shimmer.dart';
import '../favorites/widgets/favorite_button.dart';
import '../routing/data/routing_api.dart';
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
        loading: () => const DetailSkeleton(),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('Errore: $e')),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.locale});
  final LocaleDetail locale;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  Color? _accent;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  Future<void> _loadPalette() async {
    final url = widget.locale.primaryMediaUrl;
    if (url == null) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(url),
        size: const Size(120, 120),
        maximumColorCount: 6,
      );
      final color = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.lightVibrantColor?.color;
      if (!mounted || color == null) return;
      setState(() => _accent = color);
    } catch (_) {
      // ignore: silent fallback to default theme color
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final theme = Theme.of(context);
    final accent = _accent ?? theme.colorScheme.primary;
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
            background: Hero(
              tag: 'locale-image-${locale.id}',
              child: locale.primaryMediaUrl != null
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
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      locale.type,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
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
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: _onColor(accent),
                          ),
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
              Row(
                children: [
                  Text('Posizione', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  _RouteLabel(locale: locale, accent: accent),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _RouteMap(locale: locale, accent: accent),
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

  List<Widget> _buildHoursRows(
      BuildContext context, List<OpeningHoursEntry> hours) {
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

/// Returns black or white depending on which contrasts best against `bg`.
Color _onColor(Color bg) {
  return ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

/// Map embedded in the detail screen. Always shows the locale marker; if a
/// walking route from the user's current position is available, draws it as
/// a coloured polyline and fits the camera to include both endpoints.
class _RouteMap extends ConsumerWidget {
  const _RouteMap({required this.locale, required this.accent});
  final LocaleDetail locale;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localePoint = LatLng(locale.latitude, locale.longitude);
    final asyncRoute = ref.watch(walkingRouteProvider(
      WalkTo(lat: locale.latitude, lng: locale.longitude),
    ));
    final route = asyncRoute.maybeWhen(data: (r) => r, orElse: () => null);

    final cameraFit = route != null && route.points.length > 1
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([
              ...route.points,
              localePoint,
            ]),
            padding: const EdgeInsets.all(36),
          )
        : null;

    return FlutterMap(
      options: MapOptions(
        initialCenter: localePoint,
        initialZoom: 15,
        initialCameraFit: cameraFit,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'it.considera.andiamo',
        ),
        if (route != null && route.points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route.points,
                strokeWidth: 5,
                color: accent,
                borderStrokeWidth: 1,
                borderColor: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (route != null && route.points.isNotEmpty)
              Marker(
                point: route.points.first,
                width: 18,
                height: 18,
                child: _StartDot(color: accent),
              ),
            Marker(
              point: localePoint,
              width: 40,
              height: 40,
              child: Icon(Icons.location_on, size: 36, color: accent),
            ),
          ],
        ),
      ],
    );
  }
}

class _StartDot extends StatelessWidget {
  const _StartDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _RouteLabel extends ConsumerWidget {
  const _RouteLabel({required this.locale, required this.accent});
  final LocaleDetail locale;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoute = ref.watch(walkingRouteProvider(
      WalkTo(lat: locale.latitude, lng: locale.longitude),
    ));
    return asyncRoute.when(
      data: (route) {
        if (route == null) return const SizedBox.shrink();
        final mins = (route.durationS / 60).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_walk, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(
                '$mins min a piedi',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
