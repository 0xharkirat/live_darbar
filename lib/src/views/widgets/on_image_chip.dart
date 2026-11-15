import 'package:flutter/material.dart';

/// A dark backing for a small label on artwork, so the label reads on any
/// part of the painting. The LIVE badge and the time in Amritsar share it.
class OnImageChip extends StatelessWidget {
  const OnImageChip({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: ShapeDecoration(
          color: const Color(0xB30C0A09),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Padding(padding: padding, child: child),
      );
}
