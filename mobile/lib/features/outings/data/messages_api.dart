import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class OutingMessage {
  const OutingMessage({
    required this.id,
    required this.kind,
    required this.body,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  final String id;
  final String kind; // "text" | "system" | "ai"
  final String body;
  final String? userId;
  final String? userName;
  final DateTime createdAt;

  factory OutingMessage.fromJson(Map<String, dynamic> json) => OutingMessage(
        id: json['id'] as String,
        kind: json['kind'] as String,
        body: json['body'] as String,
        userId: json['user_id'] as String?,
        userName: json['user_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class MessagesApi {
  MessagesApi(this._dio);
  final Dio _dio;

  Future<List<OutingMessage>> list(String outingId) async {
    final response =
        await _dio.get<List<dynamic>>('/outings/$outingId/messages');
    return response.data!
        .map((e) => OutingMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OutingMessage> post(String outingId, String body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/outings/$outingId/messages',
      data: {'body': body},
    );
    return OutingMessage.fromJson(response.data!);
  }

  Future<void> mediate(String outingId, {double? lat, double? lng}) async {
    await _dio.post<Map<String, dynamic>>(
      '/outings/$outingId/mediate',
      queryParameters: {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
  }
}

final messagesApiProvider = Provider<MessagesApi>((ref) {
  return MessagesApi(ref.watch(dioProvider));
});

final outingMessagesProvider = FutureProvider.autoDispose
    .family<List<OutingMessage>, String>((ref, outingId) async {
  return ref.watch(messagesApiProvider).list(outingId);
});
