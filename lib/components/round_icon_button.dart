import 'package:flutter/material.dart';


class RoundIconButton extends StatelessWidget {

  RoundIconButton({required this.icon, required this.onPressed});

  final IconData? icon;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
  return RawMaterialButton(
    child: Icon(icon),
    onPressed: onPressed,
    elevation: 6.0,
    constraints: BoxConstraints.tightFor(
      width: 56.0,
      height: 56.0,
    ),
    shape: CircleBorder(),
    fillColor: Colors.white,
    );
  }
}



