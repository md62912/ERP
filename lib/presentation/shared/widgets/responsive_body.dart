import 'package:flutter/material.dart';

/// Constrains content to a comfortable reading/form width on wide
/// screens (desktop browsers, tablets) while having zero effect on
/// narrow ones (phones), where the natural width is already under the
/// max. Wrap this around a Scaffold's `body` -- not the whole Scaffold,
/// so bottom nav bars / app bars still span full width as expected.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({super.key, required this.child, this.maxWidth = 640});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
