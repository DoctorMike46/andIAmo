import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../locales/data/locale_models.dart';

class FavoritesApi {
  FavoritesApi(this._dio);
  final Dio _dio;

  Future<List<LocaleSummary>> list() async {
    final response = await _dio.get<List<dynamic>>('/me/favorites');
    return response.data!
        .map((e) => LocaleSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(String localeId) async {
    await _dio.post<Map<String, dynamic>>('/me/favorites/$localeId');
  }

  Future<void> remove(String localeId) async {
    await _dio.delete<void>('/me/favorites/$localeId');
  }
}

final favoritesApiProvider = Provider<FavoritesApi>((ref) {
  return FavoritesApi(ref.watch(dioProvider));
});

final favoritesListProvider =
    FutureProvider.autoDispose<List<LocaleSummary>>((ref) async {
  return ref.watch(favoritesApiProvider).list();
});

/// Set of locale IDs the user has favorited; computed from favoritesListProvider.
final favoriteIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final list = await ref.watch(favoritesListProvider.future);
  return list.map((l) => l.id).toSet();
});
