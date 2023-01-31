import 'package:flutter/material.dart';

const margin = EdgeInsets.symmetric(vertical: 5.0, horizontal: 5.0);

class ReusableCard extends StatelessWidget {


  ReusableCard({required this.colour, this.cardChild});


  final Color colour;
  final Widget? cardChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: cardChild,
      margin: margin,
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(10.0),
      ),
    );
  }
}