import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/weather_api.dart';
import '../data/weather_models.dart';

/// Small chip that surfaces current weather conditions at the user's location.
///
/// Loads silently — on failure or while loading it renders nothing, so we
/// never push down the rest of the layout for something secondary.
class WeatherChip extends ConsumerWidget {
  const WeatherChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentWeatherProvider);
    return async.when(
      data: (s) => s == null ? const SizedBox.shrink() : _Chip(snapshot: s),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.snapshot});
  final WeatherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, gradient) = _styleFor(snapshot.condition, scheme);
    final label = _label(snapshot);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space3, vertical: 8),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: AppTheme.space2),
            Text(
              '${snapshot.temperatureC.toStringAsFixed(0)}°',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: AppTheme.space2),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Gradient) _styleFor(String condition, ColorScheme scheme) {
    switch (condition) {
      case 'clear':
        return (
          Icons.wb_sunny_rounded,
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB454), Color(0xFFFF6B5A)],
          ),
        );
      case 'partly_cloudy':
        return (
          Icons.wb_cloudy_outlined,
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7AB6FF), Color(0xFF4F8DD9)],
          ),
        );
      case 'cloudy':
        return (
          Icons.cloud_rounded,
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8D9FB5), Color(0xFF5B6B80)],
          ),
        );
      case 'fog':
        return (
          Icons.foggy,
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA9B4C2), Color(0xFF6E7B8E)],
          ),
        );
      case 'rain':
        return (
          Icons.umbrella_rounded,
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4F8DD9), Color(0xFF2C4F8C)],
          ),
        );
      case 'snow':
        return (
          Icons.ac_unit_rounded,
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB7D4F0), Color(0xFF7AB6FF)],
          ),
        );
      case 'thunder':
        return (
          Icons.bolt_rounded,
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6C5CE7), Color(0xFF2C2A52)],
          ),
        );
      default:
        return (
          Icons.cloud_queue,
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.tertiary],
          ),
        );
    }
  }

  String _label(WeatherSnapshot s) {
    if (s.isPrecipitation) return 'Meglio al chiuso 🌧';
    if (s.isOutdoorFriendly) return 'Tempo da terrazza ☀';
    switch (s.condition) {
      case 'cloudy':
        return 'Cielo coperto';
      case 'fog':
        return 'Foschia';
      case 'snow':
        return 'Nevica';
      case 'thunder':
        return 'Temporali';
      case 'partly_cloudy':
        return 'Nuvolosità variabile';
      case 'clear':
        return 'Sereno';
      default:
        return 'Condizioni attuali';
    }
  }
}
