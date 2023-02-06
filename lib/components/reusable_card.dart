import 'package:flutter/material.dart';

const margin = EdgeInsets.symmetric( horizontal: 5.0);

class ReusableCard extends StatelessWidget {


  ReusableCard({required this.colour, this.cardChild, this.onPress});


  final Color colour;
  final Widget? cardChild;
  final void Function()? onPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPress,
      child: Container(
        margin: margin,
        padding: EdgeInsets.all(30.0),
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: cardChild,
      ),
    );
  }
}