import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:live_darbar/components/card_content.dart';
import 'package:live_darbar/components/mukhwak_dialog.dart';
import 'package:live_darbar/components/reusable_card.dart';
import 'package:live_darbar/components/sleep_timer.dart';
import 'package:live_darbar/data/timer_data.dart';
import 'package:live_darbar/logics/page_manager.dart';
import 'package:live_darbar/models/timer.dart';
import 'package:live_darbar/notifiers/progress_notifier.dart';
import 'package:live_darbar/utils/ad_state.dart';
import 'package:provider/provider.dart';
import '../components/round_icon_button.dart';
import 'package:intl/intl.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

late final PageManager _pageManager;

class _HomePageState extends State<HomePage> {
  String startingTime = '';
  String endTime = '';
  late DateTime ist;

  late String _timeString;
  late Timer timer;
  // BannerAd? banner;
  // InterstitialAd? interstitialAd;

  Channel? selectedChannel;

  bool visible = false;
  bool bottomAnimation = false;
  bool timerSet = false;

  // late bool liveStarted;

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   final adState = Provider.of<AdState>(context);
  //   adState.initialization.then((status) {
  //     setState(() {
  //       banner = BannerAd(
  //           size: AdSize.banner,
  //           adUnitId: adState.bannerAdUnitId,
  //           listener: adState.bannerAdListener,
  //           request: const AdRequest())
  //         ..load();
  //     });
  //   });
  // }

  // void _loadInterstitialAd() {
  //   InterstitialAd.load(
  //       adUnitId: AdState.interstitialAdUnitId,
  //       request: const AdRequest(),
  //       adLoadCallback: InterstitialAdLoadCallback(
  //         onAdLoaded: (ad) {
  //           ad.fullScreenContentCallback = FullScreenContentCallback(
  //             onAdDismissedFullScreenContent: (ad) {
  //               interstitialAd?.dispose();
  //             },
  //           );
  //           setState(() {
  //             interstitialAd = ad;
  //           });
  //         },
  //         onAdFailedToLoad: (error) {
  //           print('Failed to load an interstitial ad: ${error.message}');
  //         },
  //       ));
  // }

  void _getData() async {
    final timingUrl = Uri.https(
        'live-darbar-default-rtdb.firebaseio.com', 'Current_timings.json');

    final response = await http.get(timingUrl);
    final listData = json.decode(response.body);
    final List<String> currentTimings = [];
    for (final timing in listData.entries) {
      currentTimings.add(timing.value);
    }
    print(currentTimings);
    setState(() {
      startingTime = currentTimings[0];
      endTime = currentTimings[1];
    });

    // print(listData);
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
              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                const Spacer(),
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
                if (selectedChannel == Channel.liveKirtan)
                  IconButton(
                    onPressed: _openSleepTimerOverlay,
                    icon: const Icon(FontAwesomeIcons.ellipsisVertical),
                    color: const Color(0xFF040508),
                  )
              ],
            ),
          ],
        ),
      ),
    );
  }

  void selectTimer(TimerModel time) {
    if (!timerSet) {
      final snackBar = SnackBar(
        content: Text('Timer set for ${time.title}.'),
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      Future.delayed(Duration(minutes: time.time), () {
        _pageManager.pause();
      });
      print('timer done');
    } else {}
  }

  void _openSleepTimerOverlay() {
    showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Sleep Timer',
                  style: TextStyle(
                      color: Color(0xFFD6DCE6),
                      fontFamily: 'Rubik',
                      fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: ListView.builder(
                      itemCount: sleepTimer.length,
                      itemBuilder: (context, index) {
                        return SleepTimer(
                          timerModel: sleepTimer[index],
                          onSelectTimer: () {
                            selectTimer(sleepTimer[index]);
                          },
                        );
                      }),
                )
              ],
            ),
          );
        },
        backgroundColor: const Color(0xFF040508));
  }

  @override
  void initState() {
    super.initState();
    _getData();
    _pageManager = PageManager();
    ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    _timeString = _formatDateTime(ist);

    // isliveStarted(ist);

    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
    // _loadInterstitialAd();
  }

  @override
  void dispose() {
    super.dispose();
    timer.cancel();
    // banner?.dispose();
    // interstitialAd?.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MM/dd/yyyy hh:mm:ss').format(dateTime);
  }

  // void isliveStarted(DateTime now) {
  //   final DateTime startTime = DateTime(now.year, now.month, now.day, 11, 35);
  //   final DateTime endTime = DateTime(now.year, now.month, now.day, 22, 30);
  //   // print('start time bool: ${now.isAfter(startTime)}');
  //   // print('end time bool: ${endTime.isAfter(now)}');
  //   if (now.isAfter(startTime) && endTime.isAfter(now)) {
  //     print('live started');
  //     // return true;
  //   } else {
  //     print('live not Started');
  //     // return false;
  //   }
  // }

  void _getTime() {
    ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

    final String formattedDateTime =
        DateFormat('MM/dd/yyyy hh:mm:ss').format(ist);

    setState(() {
      _timeString = formattedDateTime;
      // isliveStarted(ist);
    });
  }

  @override
  Widget build(BuildContext context) {
    // _loadInterstitialAd();
    return SafeArea(
      child: Scaffold(
          appBar: AppBar(
            title: Text(
              'Time in Amritsar, IND: $_timeString',
              style: const TextStyle(
                  color: Color(0xFFD6DCE6), fontFamily: 'Rubik', fontSize: 16),
            ),
            backgroundColor: const Color.fromARGB(255, 9, 11, 18),
          ),
          bottomNavigationBar: miniPlayer(),
          backgroundColor: const Color(0xFF040508),
          body: Column(
            children: [
               const Padding(
                padding: EdgeInsets.all(8.0),
                child: TextScroll(
                  "The Live Kirtan may not be started yet. Refer to starting and ending times in the app.",
                  velocity: Velocity(pixelsPerSecond: Offset(30, 0)),
                  // delayBefore: Duration(seconds: 1),
                  intervalSpaces: 60,
                  style: TextStyle(
                    color: Color(0xFFD6DCE6),
                    fontFamily: 'Rubik',
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ReusableCard(
                        onPress: () {
                          _pageManager.play(0);
                          // interstitialAd?.show();
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
                          // interstitialAd?.show();
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
                          // interstitialAd?.show();
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
                      const SizedBox(
                        height: 5.0,
                      ),
                      ReusableCard(
                        onPress: () async {
                          await showDialog(
                              context: context,
                              builder: (_) => const MukhwakDialog());
                        },
                        colour: const Color(0xFF0E121A),
                        cardChild: const CardContent(
                          label: "Read Mukhwak",
                          labelColor: Color(0xFFD6DCE6),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              // if (banner == null)
              //   const SizedBox(
              //     height: 50,
              //   )
              // else
              //   SizedBox(
              //     height: 50,
              //     child: AdWidget(ad: banner!),
              //   )
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
