class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.condition,
    required this.isPrecipitation,
    required this.isOutdoorFriendly,
  });

  final double temperatureC;
  final String condition;
  final bool isPrecipitation;
  final bool isOutdoorFriendly;

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      temperatureC: (json['temperature_c'] as num).toDouble(),
      condition: json['condition'] as String,
      isPrecipitation: json['is_precipitation'] as bool,
      isOutdoorFriendly: json['is_outdoor_friendly'] as bool,
    );
  }
}
