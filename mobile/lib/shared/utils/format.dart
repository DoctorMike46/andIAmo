// Shared formatting helpers for locale UI.

/// Formats a raw distance in meters into a short, human-friendly walking time.
///
/// We use a brisk-walk pace of 80 m/min (~4.8 km/h) which is a reasonable
/// middle ground between a casual stroll and a determined gait. The output is
/// designed to fit a chip / one-liner alongside the locale name.
String formatWalkingTime(double meters) {
  if (meters.isNaN || meters <= 0) return '';
  final minutes = (meters / 80.0).round();
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return '$minutes min a piedi';
  final hours = (minutes / 60).floor();
  final rem = minutes % 60;
  if (rem == 0) return '${hours}h a piedi';
  return '${hours}h ${rem}m a piedi';
}

/// Compact distance label kept for cases where walking time is not relevant
/// (e.g. map markers, debug UIs).
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Combined "Xm · Y min a piedi" label for cards that want both signals.
String formatDistanceAndTime(double meters) {
  return '${formatDistance(meters)} · ${formatWalkingTime(meters)}';
}
