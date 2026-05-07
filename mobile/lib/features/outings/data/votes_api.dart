import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class VoteSummary {
  const VoteSummary({
    required this.localeId,
    required this.likes,
    required this.dislikes,
    required this.score,
    required this.myVote,
  });

  final String localeId;
  final int likes;
  final int dislikes;
  final int score;
  final String? myVote; // "like" | "dislike" | null

  factory VoteSummary.fromJson(Map<String, dynamic> json) => VoteSummary(
        localeId: json['locale_id'] as String,
        likes: json['likes'] as int,
        dislikes: json['dislikes'] as int,
        score: json['score'] as int,
        myVote: json['my_vote'] as String?,
      );
}

class VotesApi {
  VotesApi(this._dio);
  final Dio _dio;

  Future<List<VoteSummary>> list(String outingId) async {
    final response = await _dio.get<List<dynamic>>('/outings/$outingId/votes');
    return response.data!
        .map((e) => VoteSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> cast(String outingId,
      {required String localeId, required String vote}) async {
    await _dio.post<Map<String, dynamic>>(
      '/outings/$outingId/votes',
      data: {'locale_id': localeId, 'vote': vote},
    );
  }

  Future<void> remove(String outingId, {required String localeId}) async {
    await _dio.delete<void>('/outings/$outingId/votes/$localeId');
  }
}

final votesApiProvider = Provider<VotesApi>((ref) {
  return VotesApi(ref.watch(dioProvider));
});

final outingVotesProvider = FutureProvider.autoDispose
    .family<Map<String, VoteSummary>, String>((ref, outingId) async {
  final list = await ref.watch(votesApiProvider).list(outingId);
  return {for (final v in list) v.localeId: v};
});
