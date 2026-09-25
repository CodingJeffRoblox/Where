import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Shown while Where starts: the logo pops in and breathes, a light sweeps
/// around it, and a progress bar and step text follow the startup steps.
/// When [leaving] turns true it fades out, ready for the app to appear.
class BootScreen extends StatefulWidget {
  const BootScreen({
    super.key,
    required this.step,
    required this.progress,
    this.leaving = false,
    this.onLeft,
  });

  final String step;
  final double progress;
  final bool leaving;
  final VoidCallback? onLeft;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  late final AnimationController _exit =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void didUpdateWidget(BootScreen old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) {
      _exit.forward().whenComplete(() => widget.onLeft?.call());
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final logoIn = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.7, curve: Curves.elasticOut));
    final textIn = CurvedAnimation(parent: _intro, curve: const Interval(0.35, 1, curve: WhereTheme.curve));
    final out = CurvedAnimation(parent: _exit, curve: Curves.easeInCubic);

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _loop, _exit]),
        builder: (context, _) {
          final breathe = 1 + 0.03 * math.sin(_loop.value * 2 * math.pi);
          return Opacity(
            opacity: 1 - out.value,
            child: Transform.scale(
              scale: 1 + 0.06 * out.value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [scheme.primary.withAlpha(22), Theme.of(context).scaffoldBackgroundColor],
                  ),
                ),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Logo with a light sweeping around it.
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: Stack(alignment: Alignment.center, children: [
                        Opacity(
                          opacity: textIn.value,
                          child: CustomPaint(
                            size: const Size(132, 132),
                            painter: _OrbitPainter(turn: _loop.value, color: scheme.primary),
                          ),
                        ),
                        Transform.scale(
                          scale: logoIn.value * breathe,
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF5864E2), Color(0xFF404AC4)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F5BD5).withAlpha(90),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Transform.rotate(
                              angle: 0.25 * math.sin(_loop.value * 2 * math.pi),
                              child: const Icon(Icons.search_rounded, size: 46, color: Colors.white),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: textIn.value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - textIn.value)),
                        child: Column(children: [
                          Text('Where',
                              style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                          const SizedBox(height: 4),
                          Text('Find what you’re looking for',
                              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: 220,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: widget.progress.clamp(0.0, 1.0).toDouble()),
                                duration: const Duration(milliseconds: 450),
                                curve: WhereTheme.curve,
                                builder: (_, v, __) => LinearProgressIndicator(
                                  value: v,
                                  minHeight: 4,
                                  backgroundColor: scheme.surfaceContainerHighest,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 20,
                            child: AnimatedSwitcher(
                              duration: WhereTheme.medium,
                              transitionBuilder: (child, a) => FadeTransition(
                                opacity: a,
                                child: SlideTransition(
                                  position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                                  child: child,
                                ),
                              ),
                              child: Text(
                                widget.step,
                                key: ValueKey(widget.step),
                                style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A soft arc of light circling the logo.
class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.turn, required this.color});

  final double turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2 - 4;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withAlpha(28);
    canvas.drawCircle(center, radius, track);

    final start = turn * 2 * math.pi - math.pi / 2;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 0.9,
        colors: [color.withAlpha(0), color],
        transform: GradientRotation(start),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, math.pi * 0.9, false, arc);

    // Leading dot
    final head = start + math.pi * 0.9;
    canvas.drawCircle(
      center + Offset(math.cos(head), math.sin(head)) * radius,
      3.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.turn != turn || old.color != color;
}
