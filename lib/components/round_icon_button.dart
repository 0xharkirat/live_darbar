import 'package:flutter/material.dart';


class RoundIconButton extends StatelessWidget {

  const RoundIconButton({super.key, required this.icon, this.onPressed});

  final IconData? icon;
  final void Function()? onPressed;

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
    fillColor: const Color(0xFF040508),
    child: Icon(icon, color: const Color(0xFFD6DCE6),),
    );
  }
}



