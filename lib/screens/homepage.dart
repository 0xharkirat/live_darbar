import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:live_darbar/components/card_content.dart';
import 'package:live_darbar/components/reusable_card.dart';

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

  Channel? selectedChannel;
  bool isPlaying = false;

  final audio = AudioPlayer();

  void toggleChannel(Channel clicked){


    setState(() {
      //  logic for pressing the different button
      if (clicked != selectedChannel){
        isPlaying = true;
      }
      // logic for pressing same button
      else{
        isPlaying = !isPlaying;
      }
      selectedChannel = clicked;

    });

    playAudio();

  }

  void playAudio() async {



    audio.stop();
    String url = '';

    if (selectedChannel == Channel.liveKirtan){
      url = "https://live.sgpc.net:8443/;nocache=889869audio_file.mp3";
    }
    else if (selectedChannel == Channel.mukhwak){
      url = 'https://old.sgpc.net/hukumnama/jpeg%20hukamnama/hukamnama.mp3';
    }
    else if (selectedChannel == Channel.mukhwakKatha){
      url = "https://old.sgpc.net/hukumnama/jpeg hukamnama/katha.mp3";
    }

    await audio.play(UrlSource(url));



  }

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
                roundIconButton:  RoundIconButton(

                    icon: selectedChannel == Channel.liveKirtan && isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                    onPressed: (){
                      toggleChannel(Channel.liveKirtan);
                    }),
                label: 'Live Kirtan',
                labelColor: Colors.white,

              )
            ),
            ),
            Expanded(child: ReusableCard(
              colour: Color(0xFF76C9ED),
              cardChild: CardContent(
                isVisible: selectedChannel == Channel.mukhwak && isPlaying,
                roundIconButton:  RoundIconButton(
                    icon:  selectedChannel == Channel.mukhwak && isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                    onPressed: (){
                      toggleChannel(Channel.mukhwak);
                      // setState(() {
                      //   isPlaying = !isPlaying;
                      // });
                    }),
                label: 'Today\'s Mukhwak',
                labelColor: Colors.black,
              ),
            ),
            ),
            Expanded(child: ReusableCard(
              colour: Color(0xFF5132D7),
              cardChild: CardContent(
                isVisible: selectedChannel == Channel.mukhwakKatha && isPlaying ,
                roundIconButton:  RoundIconButton(
                    icon: selectedChannel == Channel.mukhwakKatha && isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                    onPressed: (){
                     toggleChannel(Channel.mukhwakKatha);
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

