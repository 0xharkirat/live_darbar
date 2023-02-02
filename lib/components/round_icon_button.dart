import 'package:flutter/material.dart';


class RoundIconButton extends StatelessWidget {

  RoundIconButton({required this.icon, this.onPressed});

  final IconData? icon;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
  return RawMaterialButton(
    child: Icon(icon),
    onPressed: onPressed,
    elevation: 6.0,
    // constraints: BoxConstraints.tightFor(
    //   width: 32.0,
    //   height: 32.0,
    // ),
    shape: CircleBorder(),
    fillColor: Colors.white,
    );
  }
}



