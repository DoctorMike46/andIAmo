import '../../recommendations/data/recommendation_models.dart';

enum ConciergeRole { user, assistant }

class ConciergeMessage {
  const ConciergeMessage({
    required this.role,
    required this.content,
    this.intent,
    this.recommendations = const [],
  });

  final ConciergeRole role;
  final String content;

  /// Set only on assistant messages, mirrors the backend `intent` field.
  final String? intent;

  /// Inline recommendation cards attached to an assistant message (intent=search).
  final List<Recommendation> recommendations;

  Map<String, dynamic> toApiJson() => {
        'role': role == ConciergeRole.user ? 'user' : 'assistant',
        'content': content,
      };
}

class ConciergeReply {
  const ConciergeReply({
    required this.reply,
    required this.intent,
    this.recommendations = const [],
  });

  final String reply;
  final String intent;
  final List<Recommendation> recommendations;

  factory ConciergeReply.fromJson(Map<String, dynamic> json) {
    final recs = (json['recommendations'] ?? <dynamic>[]) as List<dynamic>;
    return ConciergeReply(
      reply: json['reply'] as String? ?? '',
      intent: json['intent'] as String? ?? 'chitchat',
      recommendations: recs
          .map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
