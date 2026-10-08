import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Заглушка під час завантаження з відблиском кольору дасту:
/// даст проявляє невидиме, а тут — контент, що вантажиться.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.width, required this.height, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = colors.surface2;
    final glow = Color.alphaBlend(colors.dust.withValues(alpha: 0.2), base);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 1.6 - 0.3;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                colors: [base, glow, base],
                stops: [(t - 0.25).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.25).clamp(0.0, 1.0)],
              ),
            ),
          );
        },
      ),
    );
  }
}
