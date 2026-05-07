import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/location/location_service.dart';
import '../recommendations/data/recommendation_models.dart';
import 'data/messages_api.dart';
import 'data/outings_api.dart';
import 'data/votes_api.dart';

class OutingDetailScreen extends ConsumerWidget {
  const OutingDetailScreen({super.key, required this.outingId});
  final String outingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOuting = ref.watch(outingDetailProvider(outingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Uscita')),
      body: asyncOuting.when(
        data: (outing) => Column(
          children: [
            Expanded(child: _Body(outing: outing, outingId: outingId)),
            _ChatInput(outingId: outingId),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.outing, required this.outingId});
  final OutingOut outing;
  final String outingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('EEE d MMMM · HH:mm', 'it_IT');
    final asyncRecs = ref.watch(outingRecommendationsProvider(outingId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: [
        Text(outing.title, style: Theme.of(context).textTheme.headlineSmall),
        if (outing.whenDt != null) ...[
          const SizedBox(height: 4),
          Text(dateFmt.format(outing.whenDt!.toLocal()),
              style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 16),
        Text('PARTECIPANTI',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in outing.participants)
              Chip(
                avatar: CircleAvatar(child: Text(p.initial)),
                label: Text(p.displayName),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('LOCALE PER IL GRUPPO',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 1.2,
                      )),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Chiedi all\'AI'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: () => _askAI(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 8),
        asyncRecs.when(
          data: (recs) {
            if (recs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nessun locale soddisfa le preferenze del gruppo. '
                  'Provate ad allargare il raggio o il budget.',
                ),
              );
            }
            final asyncVotes = ref.watch(outingVotesProvider(outingId));
            final votes = asyncVotes.maybeWhen(data: (m) => m, orElse: () => const <String, VoteSummary>{});
            return Column(
              children: [
                for (final r in recs.take(5))
                  _RecCard(
                    rec: r,
                    chosen: outing.chosenLocaleId == r.id,
                    vote: votes[r.id],
                    onChoose: () => _choose(context, ref, r.id),
                    onVote: (v) => _vote(context, ref, r.id, v),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Errore: $e'),
        ),
        const SizedBox(height: 28),
        Text('CHAT',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                )),
        const SizedBox(height: 8),
        _ChatSection(outingId: outingId),
      ],
    );
  }

  Future<void> _askAI(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pos = await ref.read(currentLocationProvider.future);
      await ref.read(messagesApiProvider).mediate(
            outingId,
            lat: pos.lat,
            lng: pos.lng,
          );
      ref.invalidate(outingMessagesProvider(outingId));
      messenger.showSnackBar(
        const SnackBar(content: Text('L\'AI ha risposto nella chat.')),
      );
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _vote(BuildContext context, WidgetRef ref, String localeId, String vote) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Toggle: if user already voted the same way, remove the vote.
      final current = ref.read(outingVotesProvider(outingId)).maybeWhen(
            data: (m) => m[localeId]?.myVote,
            orElse: () => null,
          );
      if (current == vote) {
        await ref.read(votesApiProvider).remove(outingId, localeId: localeId);
      } else {
        await ref.read(votesApiProvider).cast(outingId, localeId: localeId, vote: vote);
      }
      ref.invalidate(outingVotesProvider(outingId));
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _choose(BuildContext context, WidgetRef ref, String localeId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(outingsApiProvider).patch(
            outingId,
            chosenLocaleId: localeId,
            status: 'decided',
          );
      ref.invalidate(outingDetailProvider(outingId));
      ref.invalidate(outingsListProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Locale scelto!')));
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }
}

class _RecCard extends StatelessWidget {
  const _RecCard({
    required this.rec,
    required this.chosen,
    required this.vote,
    required this.onChoose,
    required this.onVote,
  });
  final Recommendation rec;
  final bool chosen;
  final VoteSummary? vote;
  final VoidCallback onChoose;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: chosen ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/locales/${rec.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: rec.primaryMediaUrl != null
                      ? CachedNetworkImage(
                          imageUrl: rec.primaryMediaUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined),
                        )
                      : Container(
                          color: scheme.surfaceContainerHighest,
                          child: const Icon(Icons.storefront, size: 28),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rec.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('${rec.type} · ${rec.city}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      rec.reasons.isEmpty ? '—' : rec.reasons.join(' · '),
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          color: scheme.primary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _VoteIconButton(
                        icon: Icons.thumb_up_alt_outlined,
                        activeIcon: Icons.thumb_up_alt,
                        active: vote?.myVote == 'like',
                        count: vote?.likes ?? 0,
                        color: Colors.green.shade600,
                        onPressed: () => onVote('like'),
                      ),
                      const SizedBox(width: 4),
                      _VoteIconButton(
                        icon: Icons.thumb_down_alt_outlined,
                        activeIcon: Icons.thumb_down_alt,
                        active: vote?.myVote == 'dislike',
                        count: vote?.dislikes ?? 0,
                        color: scheme.error,
                        onPressed: () => onVote('dislike'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: chosen ? null : onChoose,
                    child: Text(chosen ? 'Scelto' : 'Scegli',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoteIconButton extends StatelessWidget {
  const _VoteIconButton({
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.count,
    required this.color,
    required this.onPressed,
  });
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final int count;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon, size: 18, color: color),
            if (count > 0) ...[
              const SizedBox(width: 2),
              Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatSection extends ConsumerWidget {
  const _ChatSection({required this.outingId});
  final String outingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMsgs = ref.watch(outingMessagesProvider(outingId));
    final scheme = Theme.of(context).colorScheme;
    return asyncMsgs.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Errore chat: $e'),
      data: (msgs) {
        if (msgs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Ancora nessun messaggio. Inizia tu, oppure tocca "Chiedi all\'AI" '
              'per un suggerimento del mediatore.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        }
        return Column(
          children: [for (final m in msgs) _MessageBubble(message: m)],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final OutingMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeFmt = DateFormat('HH:mm');

    if (message.kind == 'ai' || message.kind == 'system') {
      final isAI = message.kind == 'ai';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: isAI
                ? LinearGradient(
                    colors: [
                      scheme.primaryContainer.withValues(alpha: 0.6),
                      scheme.tertiaryContainer.withValues(alpha: 0.6),
                    ],
                  )
                : null,
            color: isAI ? null : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isAI ? Icons.auto_awesome : Icons.info_outline,
                size: 16,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.body,
                  style: TextStyle(color: scheme.onSurface, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            child: Text(
              (message.userName?.isNotEmpty ?? false)
                  ? message.userName!.substring(0, 1).toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.userName ?? '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeFmt.format(message.createdAt.toLocal()),
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
                Text(message.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInput extends ConsumerStatefulWidget {
  const _ChatInput({required this.outingId});
  final String outingId;

  @override
  ConsumerState<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<_ChatInput> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagesApiProvider).post(widget.outingId, body);
      _ctrl.clear();
      ref.invalidate(outingMessagesProvider(widget.outingId));
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Scrivi un messaggio…',
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
