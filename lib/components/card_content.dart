
import 'package:flutter/material.dart';


class CardContent extends StatelessWidget {

  const CardContent({super.key, required this.label, required this.labelColor});


  final String label;
  final Color labelColor;



  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Rubik',
        fontSize: 30.0,
        color: labelColor,
        fontWeight: FontWeight.bold,

      ),

    );
  }
}