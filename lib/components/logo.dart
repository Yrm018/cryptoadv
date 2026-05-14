import 'dart:math';
import 'package:flutter/material.dart';

enum LogoSize { sm, md, lg }

class AnimatedLogo extends StatefulWidget {
  final LogoSize size;

  const AnimatedLogo({
    super.key,
    this.size = LogoSize.md,
  });

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final List<String> binaryTrain = ['1', '0', '1', '0'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _LogoConfig get config {
    switch (widget.size) {
      case LogoSize.sm:
        return const _LogoConfig(
          canvasSize: 60,
          orbitRx: 24,
          orbitRy: 10,
          digitFontSize: 10,
          strokeHex: 2.6,
          strokeRing: 2.2,
          hexRadius: 12,
          titleSize: 16,
          subtitleSize: 10,
          spacing: 10,
        );
      case LogoSize.md:
        return const _LogoConfig(
          canvasSize: 82,
          orbitRx: 30,
          orbitRy: 12,
          digitFontSize: 11,
          strokeHex: 3.0,
          strokeRing: 2.5,
          hexRadius: 14,
          titleSize: 20,
          subtitleSize: 11,
          spacing: 12,
        );
      case LogoSize.lg:
        return const _LogoConfig(
          canvasSize: 112,
          orbitRx: 40,
          orbitRy: 16,
          digitFontSize: 13,
          strokeHex: 3.4,
          strokeRing: 2.8,
          hexRadius: 18,
          titleSize: 28,
          subtitleSize: 13,
          spacing: 14,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = config;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: cfg.canvasSize,
          height: cfg.canvasSize,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _LogoPainter(
                  progress: _controller.value,
                  config: cfg,
                  binaryTrain: binaryTrain,
                ),
              );
            },
          ),
        ),
        SizedBox(width: cfg.spacing),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "YRM",
              style: TextStyle(
                color: Colors.white,
                fontSize: cfg.titleSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.6,
              ),
            ),
            Text(
              "Your Risk Manager",
              style: TextStyle(
                color: Color(0xFFD1A7FF),
                fontSize: cfg.subtitleSize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LogoConfig {
  final double canvasSize;
  final double orbitRx;
  final double orbitRy;
  final double digitFontSize;
  final double strokeHex;
  final double strokeRing;
  final double hexRadius;
  final double titleSize;
  final double subtitleSize;
  final double spacing;

  const _LogoConfig({
    required this.canvasSize,
    required this.orbitRx,
    required this.orbitRy,
    required this.digitFontSize,
    required this.strokeHex,
    required this.strokeRing,
    required this.hexRadius,
    required this.titleSize,
    required this.subtitleSize,
    required this.spacing,
  });
}

class _LogoPainter extends CustomPainter {
  final double progress;
  final _LogoConfig config;
  final List<String> binaryTrain;

  _LogoPainter({
    required this.progress,
    required this.config,
    required this.binaryTrain,
  });

  static const Color c1 = Color(0xFFA855F7);
  static const Color c2 = Color(0xFF8B5CF6);
  static const Color c3 = Color(0xFF7C3AED);
  static const Color c4 = Color(0xFFC084FC);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbitRotation = -25 * pi / 180;

    final hexShader = const LinearGradient(
      colors: [c1, c2, c3],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.3));

    final ringShader = const LinearGradient(
      colors: [c2, c1, c4],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.45));

    final hexGlowPaint = Paint()
      ..shader = hexShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.strokeHex + 2
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final hexPaint = Paint()
      ..shader = hexShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.strokeHex
      ..strokeJoin = StrokeJoin.round;

    final ringGlowPaint = Paint()
      ..shader = ringShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.strokeRing + 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final ringPaint = Paint()
      ..shader = ringShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.strokeRing;

    final diagGlowPaint = Paint()
      ..shader = hexShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.strokeHex + 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final diagPaint = Paint()
      ..shader = hexShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.strokeHex
      ..strokeCap = StrokeCap.round;

    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 2;
      final p = Offset(
        center.dx + config.hexRadius * cos(angle),
        center.dy + config.hexRadius * sin(angle),
      );
      if (i == 0) {
        hexPath.moveTo(p.dx, p.dy);
      } else {
        hexPath.lineTo(p.dx, p.dy);
      }
    }
    hexPath.close();

    canvas.drawPath(hexPath, hexGlowPaint);
    canvas.drawPath(hexPath, hexPaint);

    final diagStart = Offset(center.dx - config.hexRadius * 0.55, center.dy - config.hexRadius * 0.33);
    final diagEnd = Offset(center.dx + config.hexRadius * 0.55, center.dy + config.hexRadius * 0.33);

    canvas.drawLine(diagStart, diagEnd, diagGlowPaint);
    canvas.drawLine(diagStart, diagEnd, diagPaint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(orbitRotation);
    canvas.translate(-center.dx, -center.dy);

    final ellipseRect = Rect.fromCenter(
      center: center,
      width: config.orbitRx * 2,
      height: config.orbitRy * 2,
    );

    canvas.drawOval(ellipseRect, ringGlowPaint);
    canvas.drawOval(ellipseRect, ringPaint);
    canvas.restore();

    for (int i = 0; i < binaryTrain.length; i++) {
      final digit = binaryTrain[i];
      final isOne = digit == '1';

      const spacing = 0.22;
      final angle = 2 * pi * ((progress - i * spacing) % 1.0);

      final localX = config.orbitRx * cos(angle);
      final localY = config.orbitRy * sin(angle);

      final rotatedX =
          localX * cos(orbitRotation) - localY * sin(orbitRotation);
      final rotatedY =
          localX * sin(orbitRotation) + localY * cos(orbitRotation);

      final pos = Offset(center.dx + rotatedX, center.dy + rotatedY);

      final pulse = 0.82 + 0.18 * sin(2 * pi * (progress - i * 0.08));
      final color =
      (isOne ? const Color(0xFFF3E8FF) : const Color(0xFFD8B4FE))
          .withOpacity(pulse.clamp(0.0, 1.0));

      final glowPainter = TextPainter(
        text: TextSpan(
          text: digit,
          style: TextStyle(
            fontSize: config.digitFontSize + 1,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            foreground: Paint()
              ..color = color.withOpacity(0.28)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textPainter = TextPainter(
        text: TextSpan(
          text: digit,
          style: TextStyle(
            fontSize: config.digitFontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      glowPainter.paint(
        canvas,
        Offset(
          pos.dx - glowPainter.width / 2,
          pos.dy - glowPainter.height / 2,
        ),
      );

      textPainter.paint(
        canvas,
        Offset(
          pos.dx - textPainter.width / 2,
          pos.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.config != config ||
        oldDelegate.binaryTrain != binaryTrain;
  }
}