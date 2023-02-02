
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:live_darbar/components/card_content.dart';
import 'package:live_darbar/components/reusable_card.dart';
import 'package:live_darbar/logics/page_manager.dart';

import '../components/round_icon_button.dart';

enum Channel {
  liveKirtan,
  mukhwak,
  mukhwakKatha

}

class HomePage extends StatefulWidget {


  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  late final PageManager _pageManager;

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

  Channel? selectedChannel;
  bool isPlaying = false;

  // final audio = AudioPlayer();

  // void toggleChannel(Channel clicked){
  //
  //
  //   setState(() {
  //     //  logic for pressing the different button
  //     if (clicked != selectedChannel){
  //       isPlaying = true;
  //     }
  //     // logic for pressing same button
  //     else{
  //       isPlaying = !isPlaying;
  //     }
  //     selectedChannel = clicked;
  //
  //   });
  //
  //   // playAudio();
  //
  // }

  // void playAudio() async {
  //
  //
  //
  //   audio.stop();
  //   String url = '';
  //
  //   if (selectedChannel == Channel.liveKirtan){
  //     url = "https://live.sgpc.net:8443/;nocache=889869audio_file.mp3";
  //   }
  //   else if (selectedChannel == Channel.mukhwak){
  //     url = 'https://old.sgpc.net/hukumnama/jpeg%20hukamnama/hukamnama.mp3';
  //   }
  //   else if (selectedChannel == Channel.mukhwakKatha){
  //     url = "https://old.sgpc.net/hukumnama/jpeg hukamnama/katha.mp3";
  //   }
  //
  //   await audio.play(UrlSource(url));
  //
  //
  //
  // }

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
                isVisible: selectedChannel == Channel.liveKirtan && isPlaying,
                roundIconButton:  ValueListenableBuilder<ButtonState>(
                  valueListenable: _pageManager.buttonNotifier,
                  builder: (_, value, __) {
                    switch (value) {
                      case ButtonState.loading:
                        return Container(
                          margin: const EdgeInsets.all(8.0),
                          width: 32.0,
                          height: 32.0,
                          child: const CircularProgressIndicator(),
                        );
                      case ButtonState.paused:
                        return RoundIconButton(icon: FontAwesomeIcons.play, onPressed: () => _pageManager.play(0));
                      case ButtonState.playing:
                        return RoundIconButton(icon: FontAwesomeIcons.pause, onPressed: _pageManager.pause);
                    }
                  },
                ),
                label: 'Live Kirtan',
                labelColor: Colors.white,

              ),
            ),
            ),
            Expanded(child: ReusableCard(
              colour: Color(0xFF76C9ED),
              cardChild: CardContent(
                isVisible: selectedChannel == Channel.mukhwak && isPlaying,
                roundIconButton: ValueListenableBuilder<ButtonState>(
                  valueListenable: _pageManager.buttonNotifier,
                  builder: (_, value, __) {
                    switch (value) {
                      case ButtonState.loading:
                        return Container(
                          margin: const EdgeInsets.all(8.0),
                          width: 32.0,
                          height: 32.0,
                          child: const CircularProgressIndicator(),
                        );
                      case ButtonState.paused:
                        return RoundIconButton(icon: FontAwesomeIcons.play, onPressed: () => _pageManager.play(1));
                      case ButtonState.playing:
                        return RoundIconButton(icon: FontAwesomeIcons.pause, onPressed: _pageManager.pause);
                    }
                  },
                ),
                label: 'Today\'s Mukhwak',
                labelColor: Colors.black,
              ),
            ),
            ),
            Expanded(child: ReusableCard(
              colour: Color(0xFF5132D7),
              cardChild: CardContent(
                isVisible: selectedChannel == Channel.mukhwakKatha && isPlaying ,
                roundIconButton:  ValueListenableBuilder<ButtonState>(
                  valueListenable: _pageManager.buttonNotifier,
                  builder: (_, value, __) {
                    switch (value) {
                      case ButtonState.loading:
                        return Container(
                          margin: const EdgeInsets.all(8.0),
                          width: 32.0,
                          height: 32.0,
                          child: const CircularProgressIndicator(),
                        );
                      case ButtonState.paused:
                        return RoundIconButton(icon: FontAwesomeIcons.play, onPressed: () => _pageManager.play(2));
                      case ButtonState.playing:
                        return RoundIconButton(icon: FontAwesomeIcons.pause, onPressed: _pageManager.pause);
                    }
                  },
                ),
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

