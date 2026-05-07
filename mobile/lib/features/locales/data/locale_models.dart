class LocaleSummary {
  const LocaleSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.address,
    required this.priceLevel,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.distanceM,
    required this.primaryMediaUrl,
  });

  final String id;
  final String name;
  final String type;
  final String city;
  final String address;
  final int priceLevel;
  final double? rating;
  final double latitude;
  final double longitude;
  final double? distanceM;
  final String? primaryMediaUrl;

  factory LocaleSummary.fromJson(Map<String, dynamic> json) {
    return LocaleSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      city: json['city'] as String,
      address: json['address'] as String,
      priceLevel: json['price_level'] as int,
      rating: _toDouble(json['rating']),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceM: _toDouble(json['distance_m']),
      primaryMediaUrl: json['primary_media_url'] as String?,
    );
  }
}

class OpeningHoursEntry {
  const OpeningHoursEntry({
    required this.weekday,
    required this.openTime,
    required this.closeTime,
    required this.closedAllDay,
  });

  final int weekday;
  final String openTime;
  final String closeTime;
  final bool closedAllDay;

  factory OpeningHoursEntry.fromJson(Map<String, dynamic> json) {
    return OpeningHoursEntry(
      weekday: json['weekday'] as int,
      openTime: json['open_time'] as String,
      closeTime: json['close_time'] as String,
      closedAllDay: json['closed_all_day'] as bool,
    );
  }
}

class LocaleMediaEntry {
  const LocaleMediaEntry({required this.url, required this.isPrimary, required this.sortOrder});

  final String url;
  final bool isPrimary;
  final int sortOrder;

  factory LocaleMediaEntry.fromJson(Map<String, dynamic> json) {
    return LocaleMediaEntry(
      url: json['url'] as String,
      isPrimary: json['is_primary'] as bool,
      sortOrder: json['sort_order'] as int,
    );
  }
}

class LocaleDetail extends LocaleSummary {
  const LocaleDetail({
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
    required this.description,
    required this.phone,
    required this.website,
    required this.media,
    required this.openingHours,
  });

  final String? description;
  final String? phone;
  final String? website;
  final List<LocaleMediaEntry> media;
  final List<OpeningHoursEntry> openingHours;

  factory LocaleDetail.fromJson(Map<String, dynamic> json) {
    return LocaleDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      city: json['city'] as String,
      address: json['address'] as String,
      priceLevel: json['price_level'] as int,
      rating: _toDouble(json['rating']),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceM: _toDouble(json['distance_m']),
      primaryMediaUrl: json['primary_media_url'] as String?,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      media: ((json['media'] ?? <dynamic>[]) as List<dynamic>)
          .map((e) => LocaleMediaEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      openingHours: ((json['opening_hours'] ?? <dynamic>[]) as List<dynamic>)
          .map((e) => OpeningHoursEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

double? _toDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
