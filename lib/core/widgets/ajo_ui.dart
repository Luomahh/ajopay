import 'package:flutter/material.dart';
import '../../app/theme.dart';

class AjoBrand extends StatelessWidget {
  const AjoBrand({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: AjoColors.forest,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Padding(padding: EdgeInsets.all(9), child: AjoMark(size: 25)),
      ),
      SizedBox(width: 10),
      Text(
        'ajopay',
        style: TextStyle(
          fontSize: 25,
          letterSpacing: -1,
          fontWeight: FontWeight.w800,
          color: AjoColors.forest,
        ),
      ),
    ],
  );
}

class AjoPanel extends StatelessWidget {
  const AjoPanel({super.key, required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AjoColors.line),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: Alignment.centerLeft, child: AjoBrand()),
                const SizedBox(height: 30),
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 10),
                Text(subtitle),
                const SizedBox(height: 26),
                child,
                const SizedBox(height: 20),
                const Text(
                  'Small contributions. Shared possibilities.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AjoColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// An A-shaped meeting point: three people building a shared savings circle.
class AjoMark extends StatelessWidget {
  const AjoMark({super.key, this.size = 32});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'AjoPay logo',
    child: CustomPaint(
      size: Size.square(size),
      painter: const _AjoMarkPainter(),
    ),
  );
}

class _AjoMarkPainter extends CustomPainter {
  const _AjoMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final paint = Paint()
      ..color = AjoColors.mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(5, 27)
        ..lineTo(16, 8)
        ..lineTo(27, 27),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(10, 22)
        ..quadraticBezierTo(16, 17, 22, 22),
      paint,
    );
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(16, 3), 2.7, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
