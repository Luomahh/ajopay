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
        child: Padding(
          padding: EdgeInsets.all(9),
          child: Icon(
            Icons.all_inclusive_rounded,
            color: AjoColors.mint,
            size: 25,
          ),
        ),
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
