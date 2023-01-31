import 'package:flutter/material.dart';
import 'package:live_darbar/components/reusable_card.dart';

class HomePage extends StatefulWidget {


  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text( "Live Darbar",
        ),
        backgroundColor: Color(0xFFACCCED),
        titleTextStyle: TextStyle(
          color: Color(0xFF3E3B5D),
          fontSize: 20.0,

        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget> [
            Expanded(child: ReusableCard(
              colour: Color(0xFF5132D7),
              cardChild: Center(
                child: Text(
                  "Live Kirtan"
                ),
              ),
            ),
            ),
            Expanded(child: ReusableCard(
              colour: Color(0xFF76C9ED),
              cardChild: Center(
                child: Text(
                    "Live Kirtan"
                ),
              ),
            ),
            ),
            Expanded(child: ReusableCard(
              colour: Color(0xFF5132D7),
              cardChild: Center(
                child: Text(
                    "Live Kirtan"
                ),
              ),
            ),
            )
          ],
        ),
      )
    );
  }
}
