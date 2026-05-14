import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'concierge_models.dart';

class ConciergeApi {
  ConciergeApi(this._dio);
  final Dio _dio;

  Future<ConciergeReply> chat({
    required String message,
    required List<ConciergeMessage> history,
    double? lat,
    double? lng,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/concierge/chat',
      data: {
        'message': message,
        'history': history.map((m) => m.toApiJson()).toList(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    return ConciergeReply.fromJson(response.data!);
  }
}

final conciergeApiProvider = Provider<ConciergeApi>((ref) {
  return ConciergeApi(ref.watch(dioProvider));
});
