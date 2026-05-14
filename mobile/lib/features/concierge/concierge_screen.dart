import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../recommendations/data/recommendation_models.dart';
import 'concierge_controller.dart';
import 'data/concierge_models.dart';

class ConciergeScreen extends ConsumerStatefulWidget {
  const ConciergeScreen({super.key});

  @override
  ConsumerState<ConciergeScreen> createState() => _ConciergeScreenState();
}

class _ConciergeScreenState extends ConsumerState<ConciergeScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _submit() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    ref.read(conciergeControllerProvider.notifier).send(text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(conciergeControllerProvider, (_, __) => _scrollToBottom());
    final state = ref.watch(conciergeControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 20),
            SizedBox(width: 8),
            Text('La tua guida'),
          ],
        ),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: 'Nuova conversazione',
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(conciergeControllerProvider.notifier).reset(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? _Welcome(onPickPrompt: (p) {
                    _textController.text = p;
                    _submit();
                  })
                : ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: state.messages.length + (state.busy ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == state.messages.length) {
                        return const _TypingBubble();
                      }
                      final msg = state.messages[i];
                      return _MessageBubble(message: msg);
                    },
                  ),
          ),
          if (state.error != null)
            Container(
              width: double.infinity,
              color: scheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                state.error!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          _InputBar(
            controller: _textController,
            focusNode: _focusNode,
            busy: state.busy,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPickPrompt});
  final ValueChanged<String> onPickPrompt;

  static const _suggestions = <(IconData, String)>[
    (Icons.local_pizza_outlined, 'Voglia di pizza vicino a noi, budget basso'),
    (Icons.wine_bar_outlined, 'Aperitivo informale per il dopo lavoro'),
    (Icons.restaurant_outlined,
        'Cena romantica, qualcosa di elegante ma non troppo caro'),
    (Icons.celebration_outlined,
        'Siamo in 5, qualcosa di vivace dove ridere e bere'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.space5),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  scheme.tertiary,
                ],
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 44),
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            'Ciao! Dove andiamo stasera?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            'Raccontami cosa hai voglia di fare e ti trovo i posti giusti.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.space6),
          Text(
            'Prova a chiedermi…',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.space3),
          for (final (icon, text) in _suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space2),
              child: _SuggestionChip(
                icon: icon,
                text: text,
                onTap: () => onPickPrompt(text),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space4, vertical: AppTheme.space4),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 22),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(Icons.north_east,
                  size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ConciergeMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ConciergeRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                _AvatarDot(color: scheme.primary),
                const SizedBox(width: AppTheme.space2),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space4, vertical: AppTheme.space3),
                  decoration: BoxDecoration(
                    color: isUser
                        ? scheme.primary
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? scheme.onPrimary : scheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (message.recommendations.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space3),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 32, right: 8),
                itemCount: message.recommendations.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppTheme.space3),
                itemBuilder: (_, i) => _RecCard(
                  rec: message.recommendations[i],
                  width: MediaQuery.of(context).size.width * 0.65,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarDot extends StatelessWidget {
  const _AvatarDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Theme.of(context).colorScheme.tertiary],
        ),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
    );
  }
}

class _RecCard extends StatelessWidget {
  const _RecCard({required this.rec, required this.width});

  final Recommendation rec;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Material(
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: InkWell(
          onTap: () => context.push('/locales/${rec.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'locale-image-${rec.id}',
                      child: rec.primaryMediaUrl != null
                          ? CachedNetworkImage(
                              imageUrl: rec.primaryMediaUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: scheme.surfaceContainerHigh),
                              errorWidget: (_, __, ___) =>
                                  const _NoImage(),
                            )
                          : const _NoImage(),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _ScoreBadge(score: rec.score),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rec.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rec.type} · ${rec.city}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: const Icon(Icons.storefront, size: 44),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final double score;
  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$pct% match',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
      child: Row(
        children: [
          _AvatarDot(color: scheme.primary),
          const SizedBox(width: AppTheme.space2),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space4, vertical: AppTheme.space3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final v = (_ctrl.value + i * 0.2) % 1.0;
                    final scale = 0.6 + (1 - (v - 0.5).abs() * 2).clamp(0, 1) * 0.6;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: scheme.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !busy,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  hintText: 'Scrivi cosa ti va…',
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: busy ? 0.9 : 1.0,
              child: SizedBox(
                width: 48,
                height: 48,
                child: FilledButton(
                  onPressed: busy ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_upward),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
