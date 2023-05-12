import 'package:flutter/material.dart';

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, this.onPressed, required this.isPlaying});

  final IconData? icon;
  final void Function()? onPressed;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      onPressed: onPressed,
      elevation: 6.0,
      constraints: const BoxConstraints.tightFor(
        width: 52.0,
        height: 52.0,
      ),
      shape: const CircleBorder(),
      fillColor: isPlaying?Theme.of(context).colorScheme.onInverseSurface :Theme.of(context).colorScheme.inverseSurface,
      child: Icon(
        icon,
        color: isPlaying?Theme.of(context).colorScheme.secondary:Theme.of(context).colorScheme.onInverseSurface,
      ),
    );
  }
}
