import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animated shimmer that paints a sweeping light gradient over its children.
/// Use as a wrapper around `ShimmerBox`/`ShimmerLine` placeholders, or any
/// neutral-colored skeleton shape.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.enabled) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(Shimmer old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.enabled && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHigh;
    final highlight = scheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final dx = (_ctrl.value * 2 - 1) * rect.width * 1.2;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlidingGradientTransform(dx: dx),
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.dx});
  final double dx;
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// Solid filled rectangle in a neutral skeleton color. Wrap in [Shimmer] to
/// animate. Designed so that several side-by-side boxes read as a "loading
/// content" shape (image + text rows etc.).
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });
  final double? width;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton for an Esplora "tonight" tile (image left, name + meta right).
class LocaleTileSkeleton extends StatelessWidget {
  const LocaleTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        height: 110,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Row(
          children: [
            const ShimmerBox(width: 100, height: 110, radius: 0),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    ShimmerBox(width: 180, height: 14),
                    ShimmerBox(width: 110, height: 11),
                    ShimmerBox(width: 80, height: 11),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space3),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the recommendation deck (full card with image + meta).
class DeckCardSkeleton extends StatelessWidget {
  const DeckCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth - 32;
        final h = c.maxHeight - 100;
        return Center(
          child: Shimmer(
            child: SizedBox(
              width: w,
              height: h,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                child: const ShimmerBox(radius: 0),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton list — N tiles vertically with separators, matching `_RecommendationsList`.
class TonightListSkeleton extends StatelessWidget {
  const TonightListSkeleton({super.key, this.itemCount = 6});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const LocaleTileSkeleton(),
    );
  }
}

/// Skeleton for the locale detail screen.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          ShimmerBox(height: 240, radius: 0),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 220, height: 22),
                SizedBox(height: 12),
                ShimmerBox(width: 140, height: 14),
                SizedBox(height: 24),
                ShimmerBox(height: 14),
                SizedBox(height: 8),
                ShimmerBox(width: 280, height: 14),
                SizedBox(height: 8),
                ShimmerBox(width: 200, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
