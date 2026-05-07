import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import '../../friends/data/friends_api.dart';
import '../../recommendations/data/recommendation_models.dart';

class OutingOut {
  const OutingOut({
    required this.id,
    required this.title,
    required this.whenDt,
    required this.status,
    required this.chosenLocaleId,
    required this.owner,
    required this.participants,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime? whenDt;
  final String status;
  final String? chosenLocaleId;
  final FriendCard owner;
  final List<FriendCard> participants;
  final DateTime createdAt;

  factory OutingOut.fromJson(Map<String, dynamic> json) => OutingOut(
        id: json['id'] as String,
        title: json['title'] as String,
        whenDt: json['when_dt'] == null
            ? null
            : DateTime.parse(json['when_dt'] as String),
        status: json['status'] as String,
        chosenLocaleId: json['chosen_locale_id'] as String?,
        owner: FriendCard.fromJson(json['owner'] as Map<String, dynamic>),
        participants: ((json['participants'] ?? <dynamic>[]) as List<dynamic>)
            .map((e) => FriendCard.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isOwner => false; // filled by widget knowing the current user
}

class OutingsApi {
  OutingsApi(this._dio);
  final Dio _dio;

  Future<List<OutingOut>> list() async {
    final response = await _dio.get<List<dynamic>>('/outings');
    return response.data!.map((e) => OutingOut.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<OutingOut> get(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/outings/$id');
    return OutingOut.fromJson(response.data!);
  }

  Future<OutingOut> create({
    required String title,
    DateTime? whenDt,
    List<String> participantIds = const [],
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/outings',
      data: {
        'title': title,
        if (whenDt != null) 'when_dt': whenDt.toIso8601String(),
        'participant_ids': participantIds,
      },
    );
    return OutingOut.fromJson(response.data!);
  }

  Future<OutingOut> patch(
    String id, {
    String? title,
    DateTime? whenDt,
    String? status,
    String? chosenLocaleId,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/outings/$id',
      data: {
        if (title != null) 'title': title,
        if (whenDt != null) 'when_dt': whenDt.toIso8601String(),
        if (status != null) 'status': status,
        if (chosenLocaleId != null) 'chosen_locale_id': chosenLocaleId,
      },
    );
    return OutingOut.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await _dio.delete<void>('/outings/$id');
  }

  Future<List<Recommendation>> recommendations(String id, {double? lat, double? lng}) async {
    final response = await _dio.get<List<dynamic>>(
      '/outings/$id/recommendations',
      queryParameters: {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    return response.data!
        .map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final outingsApiProvider = Provider<OutingsApi>((ref) {
  return OutingsApi(ref.watch(dioProvider));
});

final outingsListProvider = FutureProvider.autoDispose<List<OutingOut>>((ref) async {
  return ref.watch(outingsApiProvider).list();
});

final outingDetailProvider =
    FutureProvider.autoDispose.family<OutingOut, String>((ref, id) async {
  return ref.watch(outingsApiProvider).get(id);
});

final outingRecommendationsProvider = FutureProvider.autoDispose
    .family<List<Recommendation>, String>((ref, outingId) async {
  final pos = await ref.watch(currentLocationProvider.future);
  return ref.watch(outingsApiProvider).recommendations(
        outingId,
        lat: pos.lat,
        lng: pos.lng,
      );
});
