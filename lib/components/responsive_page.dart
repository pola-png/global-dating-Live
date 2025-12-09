import 'package:flutter/material.dart';

/// Constrains page content to a comfortable max width and centers it.
/// Keeps layouts readable on desktop/web while staying fluid on mobile.
class ResponsivePage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
