import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

/// Gentle, water-like bounce used when a field is progressively revealed.
///
/// The motion is vertical and small ([from] = 26), so a field springs into
/// place without ever sliding out past the screen edges.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return BounceInUp(
      from: 26,
      duration: const Duration(milliseconds: 550),
      delay: Duration(milliseconds: delayMs),
      child: child,
    );
  }
}
