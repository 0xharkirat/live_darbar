import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:live_darbar/components/card_content.dart';
import 'package:live_darbar/components/reusable_card.dart';

import '../components/round_icon_button.dart';

class HomePage extends StatefulWidget {


  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text( "Live Darbar",
      //   ),
      //   backgroundColor: Color(0xFFACCCED),
      //   titleTextStyle: TextStyle(
      //     color: Color(0xFF3E3B5D),
      //     fontSize: 20.0,
      //
      //   ),
      // ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget> [
            Expanded(child: ReusableCard(
              colour: Color(0xFF5132D7),
              cardChild: CardContent(
                roundIconButton:  RoundIconButton(
                    icon: FontAwesomeIcons.play,
                    onPressed: (){
                    }),
                label: 'Live Kirtan',
                labelColor: Colors.white,

              )
            ),
            ),
            Expanded(child: ReusableCard(
              colour: Color(0xFF76C9ED),
              cardChild: CardContent(
                roundIconButton:  RoundIconButton(
                    icon: FontAwesomeIcons.play,
                    onPressed: (){
                    }),
                label: 'Today\'s Mukhwak',
                labelColor: Colors.black,
              ),
            ),
            ),
            Expanded(child: ReusableCard(
              colour: Color(0xFF5132D7),
              cardChild: CardContent(
                roundIconButton:  RoundIconButton(
                    icon: FontAwesomeIcons.play,
                    onPressed: (){
                    }),
                label: 'Mukhwak Katha',
                labelColor: Colors.white,
              ),
            ),
            )
          ],
        ),
      )
    );
  }
}

