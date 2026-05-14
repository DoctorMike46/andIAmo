import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/format.dart';
import '../data/recommendation_models.dart';

/// Tinder-style swipeable deck for tonight's recommendations.
///
/// - Swipe right (or tap heart) → mark as liked, advance to next card.
/// - Swipe left (or tap cross) → skip, advance to next card.
/// - Tap card → hero-transition into the locale detail screen.
/// - Tap bookmark icon → push the locale detail (favourite toggling happens there).
///
/// Internal state is purely UI; "liked" cards are pushed onto a local set so
/// we could later sync them with the favourites endpoint, but the MVP just
/// uses the swipe as a discover/skip mechanism.
class RecommendationDeck extends StatefulWidget {
  const RecommendationDeck({
    super.key,
    required this.items,
    required this.onEmptyAction,
    this.onLiked,
    this.onSkipped,
  });

  final List<Recommendation> items;
  final VoidCallback onEmptyAction;
  final ValueChanged<Recommendation>? onLiked;
  final ValueChanged<Recommendation>? onSkipped;

  @override
  State<RecommendationDeck> createState() => _RecommendationDeckState();
}

class _RecommendationDeckState extends State<RecommendationDeck>
    with TickerProviderStateMixin {
  int _topIndex = 0;
  Offset _drag = Offset.zero;
  late AnimationController _flingCtrl;
  Animation<Offset>? _flingAnim;
  bool _flyingOff = false;

  @override
  void initState() {
    super.initState();
    _flingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _flingCtrl.dispose();
    super.dispose();
  }

  void _animateFly({required bool right}) {
    if (_flyingOff) return;
    HapticFeedback.lightImpact();
    final width = MediaQuery.of(context).size.width;
    final endX = right ? width * 1.4 : -width * 1.4;
    setState(() => _flyingOff = true);
    _flingAnim = Tween<Offset>(
      begin: _drag,
      end: Offset(endX, _drag.dy + 60),
    ).chain(CurveTween(curve: Curves.easeIn)).animate(_flingCtrl);
    _flingCtrl.forward(from: 0).whenComplete(() {
      final advanced = widget.items[_topIndex];
      if (right) {
        widget.onLiked?.call(advanced);
      } else {
        widget.onSkipped?.call(advanced);
      }
      setState(() {
        _topIndex++;
        _drag = Offset.zero;
        _flingAnim = null;
        _flyingOff = false;
      });
    });
  }

  void _snapBack() {
    setState(() => _flyingOff = true);
    _flingAnim = Tween<Offset>(begin: _drag, end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_flingCtrl);
    _flingCtrl.forward(from: 0).whenComplete(() {
      setState(() {
        _drag = Offset.zero;
        _flingAnim = null;
        _flyingOff = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_topIndex >= widget.items.length) {
      return _DeckEmpty(onAction: widget.onEmptyAction);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final cardSize = Size(
          size.width - 32,
          size.height - 100, // leave room for action buttons
        );
        final dragX = (_flingAnim?.value ?? _drag).dx;
        final dragY = (_flingAnim?.value ?? _drag).dy;
        final rotation = (dragX / size.width) * 0.18; // up to ~10°
        final likeOpacity =
            (dragX / 140).clamp(0.0, 1.0).toDouble();
        final nopeOpacity =
            (-dragX / 140).clamp(0.0, 1.0).toDouble();

        return Stack(
          alignment: Alignment.center,
          children: [
            // Background "next" card slightly smaller.
            if (_topIndex + 1 < widget.items.length)
              Positioned(
                top: 16,
                child: Transform.scale(
                  scale: 0.94 + (dragX.abs() / size.width) * 0.06,
                  child: _DeckCard(
                    rec: widget.items[_topIndex + 1],
                    size: cardSize,
                    interactive: false,
                  ),
                ),
              ),
            // Top draggable card.
            Positioned(
              top: 16,
              child: GestureDetector(
                onPanUpdate: _flyingOff
                    ? null
                    : (d) => setState(() => _drag += d.delta),
                onPanEnd: _flyingOff
                    ? null
                    : (_) {
                        if (_drag.dx.abs() > 110) {
                          _animateFly(right: _drag.dx > 0);
                        } else {
                          _snapBack();
                        }
                      },
                child: Transform.translate(
                  offset: Offset(dragX, dragY),
                  child: Transform.rotate(
                    angle: rotation,
                    child: _DeckCard(
                      rec: widget.items[_topIndex],
                      size: cardSize,
                      interactive: true,
                      likeOpacity: likeOpacity,
                      nopeOpacity: nopeOpacity,
                    ),
                  ),
                ),
              ),
            ),
            // Action buttons.
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Icons.close,
                    color: Theme.of(context).colorScheme.error,
                    onTap: _flyingOff
                        ? null
                        : () => _animateFly(right: false),
                  ),
                  _ActionButton(
                    icon: Icons.info_outline,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 52,
                    onTap: _flyingOff
                        ? null
                        : () => context
                            .push('/locales/${widget.items[_topIndex].id}'),
                  ),
                  _ActionButton(
                    icon: Icons.favorite,
                    color: Theme.of(context).colorScheme.primary,
                    onTap: _flyingOff
                        ? null
                        : () => _animateFly(right: true),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.rec,
    required this.size,
    required this.interactive,
    this.likeOpacity = 0,
    this.nopeOpacity = 0,
  });

  final Recommendation rec;
  final Size size;
  final bool interactive;
  final double likeOpacity;
  final double nopeOpacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Material(
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        elevation: interactive ? 8 : 2,
        shadowColor: Colors.black54,
        child: InkWell(
          onTap: interactive
              ? () => context.push('/locales/${rec.id}')
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image with hero (only for the top card, otherwise key conflicts).
              if (interactive)
                Hero(
                  tag: 'locale-image-${rec.id}',
                  child: _CoverImage(rec: rec),
                )
              else
                _CoverImage(rec: rec),
              // Bottom gradient for legibility.
              const Positioned.fill(child: _BottomScrim()),
              // Match score top-right.
              Positioned(
                top: 16,
                right: 16,
                child: _MatchPill(score: rec.score),
              ),
              // Like / Nope stamps (only visible while dragging).
              if (interactive) ...[
                Positioned(
                  top: 32,
                  left: 24,
                  child: Opacity(
                    opacity: likeOpacity,
                    child: _Stamp(
                      label: 'LIKE',
                      color: scheme.primary,
                      angle: -0.25,
                    ),
                  ),
                ),
                Positioned(
                  top: 32,
                  right: 24,
                  child: Opacity(
                    opacity: nopeOpacity,
                    child: _Stamp(
                      label: 'PASS',
                      color: scheme.error,
                      angle: 0.25,
                    ),
                  ),
                ),
              ],
              // Caption.
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rec.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _IconText(
                          icon: Icons.place_outlined,
                          text: rec.city,
                        ),
                        const SizedBox(width: 12),
                        _IconText(
                          icon: Icons.restaurant_outlined,
                          text: rec.type,
                        ),
                        if (rec.distanceM != null) ...[
                          const SizedBox(width: 12),
                          _IconText(
                            icon: Icons.directions_walk,
                            text: formatWalkingTime(rec.distanceM!),
                          ),
                        ],
                      ],
                    ),
                    if (rec.reasons.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: rec.reasons
                            .take(3)
                            .map((r) => _ReasonChip(label: r))
                            .toList(),
                      ),
                    ],
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

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.rec});
  final Recommendation rec;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (rec.primaryMediaUrl == null) {
      return Container(
        color: scheme.primaryContainer,
        alignment: Alignment.center,
        child: Icon(Icons.storefront,
            size: 80, color: scheme.onPrimaryContainer.withValues(alpha: 0.5)),
      );
    }
    return CachedNetworkImage(
      imageUrl: rec.primaryMediaUrl!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: scheme.surfaceContainerHigh),
      errorWidget: (_, __, ___) =>
          Container(color: scheme.surfaceContainerHigh),
    );
  }
}

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.15),
            Colors.black.withValues(alpha: 0.75),
          ],
          stops: const [0.5, 0.75, 1.0],
        ),
      ),
    );
  }
}

class _MatchPill extends StatelessWidget {
  const _MatchPill({required this.score});
  final double score;
  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$pct% match',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.label, required this.color, required this.angle});
  final String label;
  final Color color;
  final double angle;
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 56,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: color, size: size * 0.45),
        ),
      ),
    );
  }
}

class _DeckEmpty extends StatelessWidget {
  const _DeckEmpty({required this.onAction});
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration_outlined,
                size: 64, color: scheme.primary),
            const SizedBox(height: AppTheme.space4),
            Text(
              'Hai visto tutte le proposte!',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space2),
            Text(
              'Ricarica per scoprire altri locali, o prova a chiedere alla tua guida.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppTheme.space5),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: const Text('Ricarica'),
            ),
          ],
        ),
      ),
    );
  }
}

