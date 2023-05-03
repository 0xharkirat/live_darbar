import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:live_darbar/components/card_content.dart';
import 'package:live_darbar/components/reusable_card.dart';
import 'package:live_darbar/logics/page_manager.dart';
import 'package:live_darbar/notifiers/progress_notifier.dart';
import 'package:live_darbar/utils/ad_state.dart';
import 'package:provider/provider.dart';
import '../components/round_icon_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

late final PageManager _pageManager;

class _HomePageState extends State<HomePage> {
  BannerAd? banner;

  Channel? selectedChannel;

  bool visible = false;
  bool bottomAnimation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final adState = Provider.of<AdState>(context);
    adState.initialization.then((status) {
      setState(() {
        banner = BannerAd(
            size: AdSize.banner,
            adUnitId: adState.bannerAdUnitId,
            listener: adState.bannerAdListener,
            request: const AdRequest())
          ..load();
      });
    });
  }

  Widget miniPlayer() {
    Size deviceSize = MediaQuery.of(context).size;
    return AnimatedOpacity(
      opacity: bottomAnimation ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFD6DCE6),
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10.0), topRight: Radius.circular(10.0)),
        ),
        padding: const EdgeInsets.all(15.0),
        width: deviceSize.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Visibility(
              visible: visible,
              child: const AudioProgressBar(),
            ),
            const SizedBox(
              height: 5.0,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                ValueListenableBuilder<String>(
                  valueListenable: _pageManager.currentSongTitleNotifier,
                  builder: (_, title, __) {
                    return Text(
                      title,
                      style: const TextStyle(
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
                        return const SizedBox(
                          width: 52.0,
                          height: 52.0,
                          child: CircularProgressIndicator(
                            color: Color(0xFF040508),
                          ),
                        );
                      case ButtonState.paused:
                        return RoundIconButton(
                            icon: FontAwesomeIcons.play,
                            onPressed: () => _pageManager.resume());
                      case ButtonState.playing:
                        return RoundIconButton(
                            icon: FontAwesomeIcons.pause,
                            onPressed: _pageManager.pause);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _pageManager = PageManager();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
          bottomNavigationBar: miniPlayer(),
          backgroundColor: const Color(0xFF040508),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ReusableCard(
                        onPress: () {
                          _pageManager.play(0);
                          setState(() {
                            selectedChannel = Channel.liveKirtan;
                            visible = false;
                            bottomAnimation = true;
                          });
                        },
                        colour: selectedChannel == Channel.liveKirtan
                            ? const Color(0xFF040508)
                            : const Color(0xFF0E121A),
                        cardChild: const CardContent(
                          label: 'Live Kirtan',
                          labelColor: Color(0xFFD6DCE6),
                        ),
                      ),
                      const SizedBox(
                        height: 5.0,
                      ),
                      ReusableCard(
                        onPress: () {
                          _pageManager.play(1);
                          setState(() {
                            selectedChannel = Channel.mukhwak;
                            visible = true;
                            bottomAnimation = true;
                          });
                        },
                        colour: selectedChannel == Channel.mukhwak
                            ? const Color(0xFF040508)
                            : const Color(0xFF0E121A),
                        cardChild: const CardContent(
                          label: 'Today\'s Mukhwak',
                          labelColor: Color(0xFFD6DCE6),
                        ),
                      ),
                      const SizedBox(
                        height: 5.0,
                      ),
                      ReusableCard(
                        onPress: () {
                          _pageManager.play(2);
                          setState(() {
                            selectedChannel = Channel.mukhwakKatha;
                            visible = true;
                            bottomAnimation = true;
                          });
                        },
                        colour: selectedChannel == Channel.mukhwakKatha
                            ? const Color(0xFF040508)
                            : const Color(0xFF0E121A),
                        cardChild: const CardContent(
                          label: 'Mukhwak Katha',
                          labelColor: Color(0xFFD6DCE6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (banner == null)
            const SizedBox(
              height: 50,
            )
          else
            SizedBox(
              height: 50,
              child: AdWidget(ad: banner!),
            )
              
            ],
          )),
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
          baseBarColor: const Color(0xFF040508),
          progressBarColor: const Color(0xFF51545C),
          bufferedBarColor: const Color(0xFF7A808E),
          thumbColor: const Color(0xFF51545C),
          thumbGlowColor: const Color(0x5A51545C),
          timeLabelLocation: TimeLabelLocation.sides,
          progress: value.current,
          buffered: value.buffered,
          total: value.total,
          onSeek: _pageManager.seek,
        );
      },
    );
  }
}

enum Channel { liveKirtan, mukhwak, mukhwakKatha }
