import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../locales/data/locale_models.dart';

class LocaleWritePayload {
  const LocaleWritePayload({
    required this.name,
    required this.type,
    required this.description,
    required this.address,
    required this.city,
    required this.priceLevel,
    required this.rating,
    required this.phone,
    required this.website,
    required this.latitude,
    required this.longitude,
    required this.isPublished,
    required this.media,
    required this.openingHours,
  });

  final String name;
  final String type;
  final String? description;
  final String address;
  final String city;
  final int priceLevel;
  final double? rating;
  final String? phone;
  final String? website;
  final double latitude;
  final double longitude;
  final bool isPublished;
  final List<MediaPayload> media;
  final List<OpeningHoursPayload> openingHours;

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        if (description != null) 'description': description,
        'address': address,
        'city': city,
        'price_level': priceLevel,
        if (rating != null) 'rating': rating,
        if (phone != null) 'phone': phone,
        if (website != null) 'website': website,
        'latitude': latitude,
        'longitude': longitude,
        'is_published': isPublished,
        'media': media.map((m) => m.toJson()).toList(),
        'opening_hours': openingHours.map((h) => h.toJson()).toList(),
      };
}

class MediaPayload {
  const MediaPayload({required this.url, required this.isPrimary, required this.sortOrder});
  final String url;
  final bool isPrimary;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
        'url': url,
        'is_primary': isPrimary,
        'sort_order': sortOrder,
      };
}

class OpeningHoursPayload {
  const OpeningHoursPayload({
    required this.weekday,
    required this.openTime,
    required this.closeTime,
    required this.closedAllDay,
  });
  final int weekday;
  final String openTime; // "HH:mm:ss"
  final String closeTime;
  final bool closedAllDay;

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'open_time': openTime,
        'close_time': closeTime,
        'closed_all_day': closedAllDay,
      };
}

class AdminApi {
  AdminApi(this._dio);
  final Dio _dio;

  Future<String> uploadImage({required List<int> bytes, required String filename}) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/uploads',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data!['url'] as String;
  }

  Future<LocaleDetail> create(LocaleWritePayload payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/locales',
      data: payload.toJson(),
    );
    return LocaleDetail.fromJson(response.data!);
  }

  Future<LocaleDetail> update(String id, LocaleWritePayload payload) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/admin/locales/$id',
      data: payload.toJson(),
    );
    return LocaleDetail.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await _dio.delete<void>('/admin/locales/$id');
  }
}

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(ref.watch(dioProvider));
});
