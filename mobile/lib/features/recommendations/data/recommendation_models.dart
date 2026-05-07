import '../../locales/data/locale_models.dart';

class Recommendation extends LocaleSummary {
  const Recommendation({
    required super.id,
    required super.name,
    required super.type,
    required super.city,
    required super.address,
    required super.priceLevel,
    required super.rating,
    required super.latitude,
    required super.longitude,
    required super.distanceM,
    required super.primaryMediaUrl,
    required this.score,
    required this.reasons,
  });

  final double score;
  final List<String> reasons;

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    final base = LocaleSummary.fromJson(json);
    return Recommendation(
      id: base.id,
      name: base.name,
      type: base.type,
      city: base.city,
      address: base.address,
      priceLevel: base.priceLevel,
      rating: base.rating,
      latitude: base.latitude,
      longitude: base.longitude,
      distanceM: base.distanceM,
      primaryMediaUrl: base.primaryMediaUrl,
      score: (json['score'] as num).toDouble(),
      reasons: ((json['reasons'] ?? <dynamic>[]) as List<dynamic>).cast<String>(),
    );
  }
}
