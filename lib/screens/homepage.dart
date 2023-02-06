
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:live_darbar/components/card_content.dart';
import 'package:live_darbar/components/reusable_card.dart';
import 'package:live_darbar/logics/page_manager.dart';

import '../components/round_icon_button.dart';


class HomePage extends StatefulWidget {


  @override
  State<HomePage> createState() => _HomePageState();
}


late final PageManager _pageManager;
class _HomePageState extends State<HomePage> {

  String? selectedChannel;
  int selectedChannelIndex = 0;

  Widget miniPlayer(){
    Size deviceSize = MediaQuery.of(context).size;
    return AnimatedContainer(duration: Duration(milliseconds: 500),
      padding: EdgeInsets.all(10.0),
      color: Color(0xFFD6DCE6),
      width: deviceSize.width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children:<Widget> [
      ValueListenableBuilder<String>(
      valueListenable: _pageManager.currentSongTitleNotifier,
        builder: (_, title, __) {

        selectedChannel = title;

          return Text(title,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: 30.0,
              color: Color(0xFF040508),
              fontWeight: FontWeight.bold,

            ),
            );
          },
        ),
          ValueListenableBuilder<ButtonState>(
            valueListenable: _pageManager.buttonNotifier,
            builder: (_, value, __) {
              switch (value) {
                case ButtonState.loading:
                  return Container(
                    width: 52.0,
                    height: 52.0,
                    child: const CircularProgressIndicator(
                      color: Color(0xFF040508),
                    ),
                  );
                case ButtonState.paused:
                  return RoundIconButton(icon: FontAwesomeIcons.play, onPressed: () => _pageManager.play(getIndex()));
                case ButtonState.playing:
                  return RoundIconButton(icon: FontAwesomeIcons.pause, onPressed: _pageManager.pause);
              }
            },
          ),

        ],
      ),
    );
  }

  int getIndex(){
    if (selectedChannel != ''){
      if (selectedChannel == 'Live Kirtan'){
        selectedChannelIndex = 0;
      }
      else if (selectedChannel == 'Mukhwak'){
        selectedChannelIndex = 1;
      }
      else if (selectedChannel == 'Mukhwak Katha'){
        selectedChannelIndex = 2;
      }

    }
    return selectedChannelIndex;
  }


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _pageManager = PageManager();

  }

  @override
  void dispose() {
    // TODO: implement dispose

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Color(0xFF040508),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget> [
                  ReusableCard(
                    onPress: () => _pageManager.play(0),
                    colour: Color(0xFF1F2633),
                    cardChild: CardContent(
                      label: 'Live Kirtan',
                      labelColor: Color(0xFFD6DCE6),

                    ),
                  ),
                  SizedBox(
                    height: 5.0,
                  ),
                  ReusableCard(
                    onPress: () => _pageManager.play(1),
                    colour: Color(0xFF1F2633),
                    cardChild: CardContent(
                      label: 'Today\'s Mukhwak',
                      labelColor: Color(0xFFD6DCE6),
                    ),
                  ),
                  SizedBox(
                    height: 5.0,
                  ),
                  ReusableCard(
                    onPress: () => _pageManager.play(2),
                    colour: Color(0xFF1F2633),
                    cardChild: CardContent(
                      label: 'Mukhwak Katha',
                      labelColor: Color(0xFFD6DCE6),
                    ),
                  ),
                  // Expanded(
                  //
                  //     child: ReusableCard(
                  //   colour: Colors.grey,
                  //   cardChild: ValueListenableBuilder<ButtonState>(
                  //     valueListenable: _pageManager.buttonNotifier,
                  //     builder: (_, value, __) {
                  //       switch (value) {
                  //         case ButtonState.loading:
                  //           return Container(
                  //             margin: const EdgeInsets.all(8.0),
                  //             width: 32.0,
                  //             height: 32.0,
                  //             child: const CircularProgressIndicator(
                  //               color: Colors.black54,
                  //             ),
                  //           );
                  //         case ButtonState.paused:
                  //           return RoundIconButton(icon: FontAwesomeIcons.play, onPressed: () => _pageManager.play(1));
                  //         case ButtonState.playing:
                  //           return RoundIconButton(icon: FontAwesomeIcons.pause, onPressed: _pageManager.pause);
                  //       }
                  //     },
                  //   ),
                  //
                  //
                  // ))
                ],
              ),
            ),
            miniPlayer(),
          ],
        )
      ),
    );
  }
}
