import 'package:flutter/material.dart';


class RoundIconButton extends StatelessWidget {

  RoundIconButton({required this.icon, this.onPressed});

  final IconData? icon;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
  return RawMaterialButton(
    child: Icon(icon, color: Color(0xFFD6DCE6),),
    onPressed: onPressed,
    elevation: 6.0,
    constraints: BoxConstraints.tightFor(
      width: 52.0,
      height: 52.0,
    ),
    shape: CircleBorder(),
    fillColor: Color(0xFF040508),
    );
  }
}



