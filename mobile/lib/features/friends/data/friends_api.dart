import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class FriendCard {
  const FriendCard({required this.id, required this.email, required this.fullName});
  final String id;
  final String email;
  final String? fullName;

  factory FriendCard.fromJson(Map<String, dynamic> json) => FriendCard(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
      );

  String get displayName => (fullName?.isNotEmpty ?? false) ? fullName! : email;
  String get initial => displayName.substring(0, 1).toUpperCase();
}

class FriendRequest {
  const FriendRequest({required this.id, required this.user, required this.requestedAt});
  final String id;
  final FriendCard user;
  final DateTime requestedAt;

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
        id: json['id'] as String,
        user: FriendCard.fromJson(json['user'] as Map<String, dynamic>),
        requestedAt: DateTime.parse(json['requested_at'] as String),
      );
}

class FriendsApi {
  FriendsApi(this._dio);
  final Dio _dio;

  Future<List<FriendCard>> search(String query) async {
    final response = await _dio.get<List<dynamic>>(
      '/users/search',
      queryParameters: {'q': query, 'limit': 10},
    );
    return response.data!.map((e) => FriendCard.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FriendCard>> listFriends() async {
    final response = await _dio.get<List<dynamic>>('/me/friends');
    return response.data!.map((e) => FriendCard.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FriendRequest>> listRequests({required bool incoming}) async {
    final response = await _dio.get<List<dynamic>>(
      '/me/friend-requests',
      queryParameters: {'direction': incoming ? 'incoming' : 'outgoing'},
    );
    return response.data!
        .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendRequest(String email) async {
    await _dio.post<Map<String, dynamic>>(
      '/me/friends/requests',
      data: {'email': email},
    );
  }

  Future<void> respond(String friendshipId, {required bool accept}) async {
    final action = accept ? 'accept' : 'reject';
    await _dio.post<Map<String, dynamic>>('/me/friends/requests/$friendshipId/$action');
  }

  Future<void> remove(String userId) async {
    await _dio.delete<void>('/me/friends/$userId');
  }
}

final friendsApiProvider = Provider<FriendsApi>((ref) {
  return FriendsApi(ref.watch(dioProvider));
});

final friendsListProvider = FutureProvider.autoDispose<List<FriendCard>>((ref) async {
  return ref.watch(friendsApiProvider).listFriends();
});

final incomingRequestsProvider =
    FutureProvider.autoDispose<List<FriendRequest>>((ref) async {
  return ref.watch(friendsApiProvider).listRequests(incoming: true);
});

final outgoingRequestsProvider =
    FutureProvider.autoDispose<List<FriendRequest>>((ref) async {
  return ref.watch(friendsApiProvider).listRequests(incoming: false);
});
