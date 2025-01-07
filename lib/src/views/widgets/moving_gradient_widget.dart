

import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';

class MovingGradientWidget extends StatelessWidget {
  const MovingGradientWidget(
      {super.key, required this.child, required this.colors});
  final Widget child;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedMeshGradient(
    
      colors: colors,
      options: AnimatedMeshGradientOptions(
        grain: 0.2,
        speed: 3,
        
        frequency: 10
      ),
      child: child,
    );
  }
}
