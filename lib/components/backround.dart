import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class CryptoBackground extends StatefulWidget {
  const CryptoBackground({super.key});

  @override
  State<CryptoBackground> createState() => _CryptoBackgroundState();
}

class _CryptoBackgroundState extends State<CryptoBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Random _random = Random();

  late final List<BinaryItem> _binaryItems;
  late final List<HexItem> _hexItems;
  late final List<LineItem> _lineItems;
  late final List<ParticleItem> _particles;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _binaryItems = List.generate(150, (_) => BinaryItem.random(_random));
    _hexItems = List.generate(18, (i) => HexItem.random(_random, i));
    _lineItems = List.generate(8, (i) => LineItem.random(_random, i));
    _particles = List.generate(60, (_) => ParticleItem.random(_random));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _lineColor(int i, bool isDark) {
    if (isDark) {
      if (i % 3 == 0) return const Color(0xFF3B82F6);
      if (i % 3 == 1) return const Color(0xFF06B6D4);
      return const Color(0xFF6366F1);
    } else {
      if (i % 3 == 0) return const Color(0xFF3B82F6);
      if (i % 3 == 1) return const Color(0xFF06B6D4);
      return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;

            return LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Fond principal - Plus coloré en mode clair
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF020617),
                                  const Color(0xFF172554),
                                  const Color(0xFF0F172A),
                                ]
                              : [
                                  const Color(0xFFE0E7FF), // indigo-100
                                  const Color(0xFFDBEAFE), // blue-100
                                  const Color(0xFFF1F5F9), // slate-100
                                ],
                        ),
                      ),
                    ),

                    // Couche 2 - Plus de présence
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: isDark
                              ? [
                                  const Color(0x801E1B4B),
                                  Colors.transparent,
                                  const Color(0x80083344),
                                ]
                              : [
                                  const Color(0x6693C5FD), // blue-300 / 40%
                                  Colors.transparent,
                                  const Color(0x66A5F3FC), // cyan-200 / 40%
                                ],
                        ),
                      ),
                    ),

                    // Couche 3 - Teintes violettes plus marquées
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: isDark
                              ? [
                                  Colors.transparent,
                                  const Color(0x4D3B0764),
                                  Colors.transparent,
                                ]
                              : [
                                  Colors.transparent,
                                  const Color(0x4DC084FC), // purple-400 / 30%
                                  Colors.transparent,
                                ],
                        ),
                      ),
                    ),

                    // Grille 3D
                    Opacity(
                      opacity: isDark ? 0.15 : 0.12,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(1.05)
                          ..translate(0.0, t * 80),
                        child: CustomPaint(
                          painter: GridPainter(isDark: isDark),
                          size: size,
                        ),
                      ),
                    ),

                    // Gros orbes lumineux - Augmentation de l'opacité en mode clair
                    _buildOrb(
                      left: size.width * 0.05,
                      top: size.height * 0.02,
                      diameter: 700,
                      color: isDark ? const Color(0x333B82F6) : const Color(0x4060A5FA), // blue-400 / 25%
                      phase: 0.0,
                      t: t,
                    ),
                    _buildOrb(
                      right: size.width * 0.02,
                      bottom: size.height * 0.05,
                      diameter: 750,
                      color: isDark ? const Color(0x3306B6D4) : const Color(0x4022D3EE), // cyan-400 / 25%
                      phase: 0.2,
                      t: t,
                    ),
                    _buildOrb(
                      right: size.width * 0.18,
                      top: size.height * 0.22,
                      diameter: 600,
                      color: isDark ? const Color(0x336366F1) : const Color(0x40818CF8), // indigo-400 / 25%
                      phase: 0.4,
                      t: t,
                    ),
                    _buildOrb(
                      left: size.width * 0.32,
                      bottom: size.height * 0.08,
                      diameter: 650,
                      color: isDark ? const Color(0x26A855F7) : const Color(0x33C084FC), // purple-400 / 20%
                      phase: 0.6,
                      t: t,
                    ),

                    // Bits binaires
                    ..._binaryItems.map((item) {
                      final pulse = 0.2 +
                          0.4 *
                              (0.5 +
                                  0.5 *
                                      sin(
                                        2 * pi * (t * (1 / item.speed) + item.delay),
                                      ));

                      return Positioned(
                        left: item.x * size.width,
                        top: item.y * size.height,
                        child: Opacity(
                          opacity: isDark ? pulse : pulse * 0.4,
                          child: Transform.scale(
                            scale: 1 + 0.2 * sin(2 * pi * (t + item.delay)),
                            child: Text(
                              item.value,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: item.fontSize,
                                color: isDark
                                    ? const Color(0x663B82F6)
                                    : const Color(0x4D2563EB),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Hexagones
                    Opacity(
                      opacity: isDark ? 0.20 : 0.12,
                      child: CustomPaint(
                        painter: HexPainter(
                          items: _hexItems,
                          progress: t,
                          isDark: isDark,
                        ),
                        size: size,
                      ),
                    ),

                    // Réseau
                    Opacity(
                      opacity: isDark ? 0.10 : 0.06,
                      child: CustomPaint(
                        painter: NetworkPainter(
                          items: _lineItems,
                          progress: t,
                          isDark: isDark,
                        ),
                        size: size,
                      ),
                    ),

                    // Particules
                    ..._particles.asMap().entries.map((entry) {
                      final i = entry.key;
                      final p = entry.value;
                      final color = _lineColor(i, isDark);

                      final dx = sin(2 * pi * (t + p.delay)) * p.moveX;
                      final dy = cos(2 * pi * (t + p.delay)) * p.moveY;
                      final opacity =
                          0.3 + 0.7 * (0.5 + 0.5 * sin(2 * pi * (t + p.delay)));

                      return Positioned(
                        left: p.x * size.width + dx,
                        top: p.y * size.height + dy,
                        child: Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Container(
                            width: p.size,
                            height: p.size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  color.withOpacity(isDark ? 0.9 : 0.4),
                                  color.withOpacity(0.0),
                                ],
                              ),
                              boxShadow: isDark
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrb({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double diameter,
    required Color color,
    required double phase,
    required double t,
  }) {
    final scale = 0.95 + 0.15 * (0.5 + 0.5 * sin(2 * pi * (t + phase)));

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.6),
                blurRadius: 150,
                spreadRadius: 60,
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class BinaryItem {
  final double x;
  final double y;
  final double fontSize;
  final double speed;
  final double delay;
  final String value;

  BinaryItem({
    required this.x,
    required this.y,
    required this.fontSize,
    required this.speed,
    required this.delay,
    required this.value,
  });

  factory BinaryItem.random(Random r) {
    return BinaryItem(
      x: r.nextDouble(),
      y: r.nextDouble(),
      fontSize: 12 + r.nextDouble() * 8,
      speed: 5 + r.nextDouble() * 10,
      delay: r.nextDouble() * 5,
      value: r.nextBool() ? '1' : '0',
    );
  }
}

class HexItem {
  final double x;
  final double y;
  final double size;
  final double delay;
  final double duration;

  HexItem({
    required this.x,
    required this.y,
    required this.size,
    required this.delay,
    required this.duration,
  });

  factory HexItem.random(Random r, int i) {
    return HexItem(
      x: 0.05 + r.nextDouble() * 0.90,
      y: 0.05 + r.nextDouble() * 0.90,
      size: 25 + (i % 4) * 12.0,
      delay: i * 0.2,
      duration: 8 + i * 0.5,
    );
  }
}

class LineItem {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double delay;
  final double duration;
  final int index;

  LineItem({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.delay,
    required this.duration,
    required this.index,
  });

  factory LineItem.random(Random r, int i) {
    return LineItem(
      x1: r.nextDouble(),
      y1: r.nextDouble(),
      x2: r.nextDouble(),
      y2: r.nextDouble(),
      delay: r.nextDouble() * 2,
      duration: 3 + r.nextDouble() * 4,
      index: i,
    );
  }
}

class ParticleItem {
  final double x;
  final double y;
  final double size;
  final double moveX;
  final double moveY;
  final double delay;

  ParticleItem({
    required this.x,
    required this.y,
    required this.size,
    required this.moveX,
    required this.moveY,
    required this.delay,
  });

  factory ParticleItem.random(Random r) {
    return ParticleItem(
      x: r.nextDouble(),
      y: r.nextDouble(),
      size: 2 + r.nextDouble() * 4,
      moveX: r.nextDouble() * 100 - 50,
      moveY: r.nextDouble() * 100 - 50,
      delay: r.nextDouble() * 5,
    );
  }
}

class GridPainter extends CustomPainter {
  final bool isDark;
  GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const step = 80.0;

    final paint = Paint()
      ..color = isDark ? const Color(0x333B82F6) : const Color(0x263B82F6)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HexPainter extends CustomPainter {
  final List<HexItem> items;
  final double progress;
  final bool isDark;

  HexPainter({
    required this.items,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in items) {
      final anim =
          0.5 + 0.5 * sin(2 * pi * (progress * (20 / item.duration) + item.delay));
      final dy = -25 * anim;
      final rotation = pi * anim;
      final opacity = 0.4 + 0.5 * anim;

      final center = Offset(item.x * size.width, item.y * size.height + dy);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);

      final path = _hexagonPath(item.size);

      final rect = Rect.fromCircle(center: Offset.zero, radius: item.size * 1.2);
      final gradient = LinearGradient(
        colors: isDark
            ? [
                const Color(0xCC3B82F6).withOpacity(opacity),
                const Color(0x4D06B6D4).withOpacity(opacity * 0.8),
              ]
            : [
                const Color(0x992563EB).withOpacity(opacity * 0.7),
                const Color(0x660891B2).withOpacity(opacity * 0.5),
              ],
      );

      final glowPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final strokePaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      if (isDark) canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, strokePaint);

      canvas.restore();
    }
  }

  Path _hexagonPath(double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = pi / 3 * i - pi / 2;
      final x = radius * cos(angle);
      final y = radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant HexPainter oldDelegate) => true;
}

class NetworkPainter extends CustomPainter {
  final List<LineItem> items;
  final double progress;
  final bool isDark;

  NetworkPainter({
    required this.items,
    required this.progress,
    required this.isDark,
  });

  Color _lineColor(int i) {
    if (isDark) {
      if (i % 3 == 0) return const Color(0xFF3B82F6);
      if (i % 3 == 1) return const Color(0xFF06B6D4);
      return const Color(0xFF6366F1);
    } else {
      if (i % 3 == 0) return const Color(0xFF2563EB);
      if (i % 3 == 1) return const Color(0xFF0891B2);
      return const Color(0xFF4F46E5);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in items) {
      final color = _lineColor(item.index);
      final opacity =
          0.3 + 0.3 * (0.5 + 0.5 * sin(2 * pi * (progress + item.delay)));

      final p1 = Offset(item.x1 * size.width, item.y1 * size.height);
      final p2 = Offset(item.x2 * size.width, item.y2 * size.height);

      final glowPaint = Paint()
        ..color = color.withOpacity(opacity * 0.7)
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final linePaint = Paint()
        ..color = color.withOpacity(isDark ? opacity : opacity * 0.8)
        ..strokeWidth = 1.5;

      if (isDark) canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, linePaint);

      final nodePulse1 =
          0.5 + 0.5 * sin(2 * pi * (progress * 2 + item.delay));
      final nodePulse2 =
          0.5 + 0.5 * sin(2 * pi * (progress * 2 + item.delay + 0.3));

      _drawNode(canvas, p1, color, nodePulse1);
      _drawNode(canvas, p2, color, nodePulse2);
    }
  }

  void _drawNode(Canvas canvas, Offset center, Color color, double pulse) {
    final r = 3 + pulse * 2;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(isDark ? 0.9 : 0.4),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 3));

    canvas.drawCircle(center, r * 3, glowPaint);

    final corePaint = Paint()..color = color.withOpacity(isDark ? 0.9 : 0.7);
    canvas.drawCircle(center, r, corePaint);
  }

  @override
  bool shouldRepaint(covariant NetworkPainter oldDelegate) => true;
}
