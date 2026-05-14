import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/location/location_service.dart';
import '../recommendations/data/recommendation_models.dart';
import 'data/concierge_api.dart';
import 'data/concierge_models.dart';

const _kStorageKey = 'concierge.conversation.v1';
const _kMaxPersistedMessages = 40;

class ConciergeState {
  const ConciergeState({
    this.messages = const [],
    this.busy = false,
    this.error,
  });

  final List<ConciergeMessage> messages;
  final bool busy;
  final String? error;

  ConciergeState copyWith({
    List<ConciergeMessage>? messages,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return ConciergeState(
      messages: messages ?? this.messages,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ConciergeController extends StateNotifier<ConciergeState> {
  ConciergeController(this._ref) : super(const ConciergeState()) {
    _restore();
  }

  final Ref _ref;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStorageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final restored = decoded
          .map((e) => _messageFromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      state = state.copyWith(messages: restored);
    } catch (_) {
      // Corrupted payload — drop it silently so we don't keep failing.
      await prefs.remove(_kStorageKey);
    }
  }

  Future<void> _persist(List<ConciergeMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = messages.length > _kMaxPersistedMessages
        ? messages.sublist(messages.length - _kMaxPersistedMessages)
        : messages;
    final encoded = jsonEncode(trimmed.map(_messageToJson).toList());
    await prefs.setString(_kStorageKey, encoded);
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;

    final userMsg =
        ConciergeMessage(role: ConciergeRole.user, content: trimmed);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      busy: true,
      clearError: true,
    );

    try {
      final api = _ref.read(conciergeApiProvider);
      final pos = await _ref.read(currentLocationProvider.future);

      // History sent to backend excludes the just-added user message
      // (it's passed separately as `message`) and any inline recommendations.
      final history = state.messages
          .take(state.messages.length - 1)
          .map((m) => ConciergeMessage(role: m.role, content: m.content))
          .toList();

      final reply = await api.chat(
        message: trimmed,
        history: history,
        lat: pos.lat,
        lng: pos.lng,
      );

      final assistantMsg = ConciergeMessage(
        role: ConciergeRole.assistant,
        content: reply.reply,
        intent: reply.intent,
        recommendations: reply.recommendations,
      );
      final updated = [...state.messages, assistantMsg];
      state = state.copyWith(messages: updated, busy: false);
      unawaited(_persist(updated));
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  Future<void> reset() async {
    state = const ConciergeState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStorageKey);
  }
}

final conciergeControllerProvider =
    StateNotifierProvider<ConciergeController, ConciergeState>((ref) {
  return ConciergeController(ref);
});

// ── (de)serialization helpers ─────────────────────────────────────────────

Map<String, dynamic> _messageToJson(ConciergeMessage m) => {
      'role': m.role == ConciergeRole.user ? 'user' : 'assistant',
      'content': m.content,
      if (m.intent != null) 'intent': m.intent,
      if (m.recommendations.isNotEmpty)
        'recommendations':
            m.recommendations.map(_recommendationToJson).toList(),
    };

ConciergeMessage _messageFromJson(Map<String, dynamic> json) {
  final role = json['role'] == 'user' ? ConciergeRole.user : ConciergeRole.assistant;
  final recs = (json['recommendations'] as List<dynamic>?) ?? const [];
  return ConciergeMessage(
    role: role,
    content: json['content'] as String? ?? '',
    intent: json['intent'] as String?,
    recommendations: recs
        .map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Round-trip a Recommendation through the same JSON it would have arrived
/// in over the network, so `Recommendation.fromJson` keeps owning the schema.
Map<String, dynamic> _recommendationToJson(Recommendation r) => {
      'id': r.id,
      'name': r.name,
      'type': r.type,
      'city': r.city,
      'address': r.address,
      'price_level': r.priceLevel,
      'rating': r.rating,
      'latitude': r.latitude,
      'longitude': r.longitude,
      'distance_m': r.distanceM,
      'primary_media_url': r.primaryMediaUrl,
      'score': r.score,
      'reasons': r.reasons,
    };

