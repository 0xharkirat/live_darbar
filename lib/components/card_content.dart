import 'package:audio_wave/audio_wave.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:live_darbar/components/round_icon_button.dart';

class CardContent extends StatelessWidget {

  CardContent({required this.label, required this.labelColor, required this.isVisible});


  final String label;
  final Color labelColor;
  final bool isVisible;


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget> [

        Text(
          label,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: 30.0,
            color: labelColor,
            fontWeight: FontWeight.bold,

          ),

        ),
        SizedBox(
          height: 10.0,
        ),
        Visibility(
          visible: isVisible,
          child: AudioWave(
            height: 27.0,
            width: 88.0,
            spacing: 2.5,
            bars: [
              AudioWaveBar(heightFactor: 0.1, color: Colors.black),
              AudioWaveBar(heightFactor: 0.3, color: Colors.white),
              AudioWaveBar(heightFactor: 0.7, color: Colors.black),
              AudioWaveBar(heightFactor: 0.4, color: Colors.white),
              AudioWaveBar(heightFactor: 0.2, color: Colors.black),
              AudioWaveBar(heightFactor: 0.1, color: Colors.black),
              AudioWaveBar(heightFactor: 0.3, color: Colors.white),
              AudioWaveBar(heightFactor: 0.7, color: Colors.black),
              AudioWaveBar(heightFactor: 0.4, color: Colors.white),
              AudioWaveBar(heightFactor: 0.2, color: Colors.black),
              AudioWaveBar(heightFactor: 0.1, color: Colors.black),
              AudioWaveBar(heightFactor: 0.3, color: Colors.white),
              AudioWaveBar(heightFactor: 0.7, color: Colors.black),
              AudioWaveBar(heightFactor: 0.4, color: Colors.white),
              AudioWaveBar(heightFactor: 0.2, color: Colors.black),


            ],
          ),
        ),

      ],
    );
  }
}