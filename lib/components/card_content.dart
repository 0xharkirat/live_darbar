import 'package:audio_wave/audio_wave.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:live_darbar/components/round_icon_button.dart';

class CardContent extends StatelessWidget {

  CardContent({required this.label, required this.labelColor});


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