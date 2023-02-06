
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:live_darbar/components/card_content.dart';
import 'package:live_darbar/components/reusable_card.dart';
import 'package:live_darbar/logics/page_manager.dart';
import 'package:live_darbar/notifiers/progress_notifier.dart';

import '../components/round_icon_button.dart';


class HomePage extends StatefulWidget {


  @override
  State<HomePage> createState() => _HomePageState();
}


late final PageManager _pageManager;
class _HomePageState extends State<HomePage> {




  Widget miniPlayer(){
    Size deviceSize = MediaQuery.of(context).size;
    return AnimatedContainer(duration: Duration(milliseconds: 500),
      padding: EdgeInsets.all(15.0),
      color: Color(0xFFD6DCE6),
      width: deviceSize.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget> [
          AudioProgressBar(),
          SizedBox(
            height: 5.0,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:<Widget> [
          ValueListenableBuilder<String>(
          valueListenable: _pageManager.currentSongTitleNotifier,
            builder: (_, title, __) {



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
                      return RoundIconButton(icon: FontAwesomeIcons.play, onPressed: () => _pageManager.play(_pageManager.getIndex()));
                    case ButtonState.playing:
                      return RoundIconButton(icon: FontAwesomeIcons.pause, onPressed: _pageManager.pause);
                  }
                },
              ),

            ],
          ),
        ],
      ),
    );
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
        bottomNavigationBar: miniPlayer(),
        backgroundColor: Color(0xFF040508),
        body: SingleChildScrollView(
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

            ],
          ),
        )
      ),
    );
  }
}


class AudioProgressBar extends StatelessWidget {
  const AudioProgressBar({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProgressBarState>(
      valueListenable: _pageManager.progressNotifier,
      builder: (_, value, __) {
        return ProgressBar(
          progress: value.current,
          buffered: value.buffered,
          total: value.total,
          onSeek: _pageManager.seek,
        );
      },
    );
  }
}
