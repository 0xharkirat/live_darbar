import 'dart:async';
import 'dart:io';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:live_darbar/components/card_content.dart';
import 'package:live_darbar/components/ragi_list_dialog.dart';
import 'package:live_darbar/components/reusable_card.dart';
import 'package:live_darbar/components/sleep_timer.dart';
import 'package:live_darbar/components/webview_dialog.dart';
import 'package:live_darbar/data/timer_data.dart';
import 'package:live_darbar/logics/page_manager.dart';
import 'package:live_darbar/models/duty.dart';
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

const streamUrl = 'https://live.sgpc.net:8443/;nocache=889869';

late final PageManager _pageManager;

class _HomePageState extends State<HomePage> {
  late http.StreamedResponse _response;
  late bool _downloading;
  Color _color = Colors.red;
  BorderRadiusGeometry _borderRadius = BorderRadius.circular(100);

  var client;
  bool loading = false;

  Duration _elapsedTime = Duration.zero;

  List<Duty> _todayDuties = [];
  Duty? _currentDuty;
  late DateTime ist;

  late String _timeString;
  late Timer timer;
  late Timer t;

  bool sleepTimerSet = false;
  BannerAd? banner;
  InterstitialAd? interstitialAd;

  Channel? selectedChannel;

  bool visible = false;
  bool bottomAnimation = false;

  late bool liveStarted;

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

  void _loadInterstitialAd() {
    InterstitialAd.load(
        adUnitId: AdState.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdFailedToShowFullScreenContent: (ad, err) {
                // Dispose the ad here to free resources.
                ad.dispose();
              },
              // Called when the ad dismissed full screen content.
              onAdDismissedFullScreenContent: (ad) {
                // Dispose the ad here to free resources.
                ad.dispose();
                // setState(() {
                //   interstitialAd = null;
                // });
              },
            );
            setState(() {
              interstitialAd = ad;
            });
          },
          onAdFailedToLoad: (error) {
            print('Failed to load an interstitial ad: ${error.message}');
          },
        ));
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
            visible
                ? const AudioProgressBar()
                : liveStarted
                    ? _currentDuty?.ragi != null
                        ? Text(
                            'Current Ragi: ${_currentDuty?.ragi}',
                            style: const TextStyle(
                              fontFamily: 'Rubik',
                              color: Color(0xFF040508),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const TextScroll(
                            'Path or Ardas is going to start, or is currently going on, or change of Ragi duty according to the Timetable.',
                            velocity: Velocity(pixelsPerSecond: Offset(30, 0)),
                            // delayBefore: Duration(seconds: 1),
                            intervalSpaces: 60,
                            style: TextStyle(
                              fontFamily: 'Rubik',
                              color: Color(0xFF040508),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                    : Container(),
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
    final snackBar = SnackBar(
      content: Text('Timer set for ${time.title}.'),
      action: SnackBarAction(
        label: "Undo",
        onPressed: () {
          t.cancel();
          sleepTimerSet = false;
        },
      ),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    if (!sleepTimerSet) {
      sleepTimerSet = true;
      t = Timer(Duration(minutes: time.time), () {
        _pageManager.pause();
        sleepTimerSet = false;
      });
    } else {
      t.cancel();
      sleepTimerSet = true;
      t = Timer(Duration(seconds: time.time), () {
        _pageManager.pause();
        sleepTimerSet = false;
      });
    }
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
                    fontWeight: FontWeight.bold,
                  ),
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
    _pageManager = PageManager();
    ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    _timeString = _formatDateTime(ist);
    _downloading = false;

    isliveStarted(ist);
    _getData();

    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
    _loadInterstitialAd();
  }

  @override
  void dispose() {
    super.dispose();
    timer.cancel();
    banner?.dispose();
    interstitialAd?.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMMM dd, yyyy - hh:mm:ss').format(dateTime);
  }

  void isliveStarted(DateTime now) {
    final DateTime startTime =
        DateTime.utc(now.year, now.month, now.day, 2, 15);
    final DateTime endTime = DateTime.utc(now.year, now.month, now.day, 22, 30);
    // print('start time bool: ${now.isAfter(startTime)}');
    // print('end time bool: ${endTime.isAfter(now)}');
    if (now.isBefore(startTime) || now.isAfter(endTime)) {
      // print('live not started');
      setState(() {
        liveStarted = false;
      });
    } else {
      // print('live started');
      setState(() {
        liveStarted = true;
      });
    }
  }

  void _getTime() {
    ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

    final String formattedDateTime =
        DateFormat('MMMM dd, yyyy - hh:mm:ss').format(ist);

    isliveStarted(ist);
    if (_todayDuties.isNotEmpty) {
      for (final duty in _todayDuties) {
        final DateTime dutyStart = DateTime.utc(
            ist.year,
            ist.month,
            ist.day,
            int.parse(duty.startTime.substring(0, 2)),
            int.parse(duty.startTime.substring(3)));
        final DateTime dutyEnd = DateTime.utc(
            ist.year,
            ist.month,
            ist.day,
            int.parse(duty.endTime.substring(0, 2)),
            int.parse(duty.endTime.substring(3)));
        if (ist.isAfter(dutyStart) && ist.isBefore(dutyEnd)) {
          setState(() {
            _currentDuty = duty;
            // print(_currentDuty?.ragi);
          });
          break;
        }
      }
    }

    setState(() {
      _timeString = formattedDateTime;
      // isliveStarted(ist);
    });
  }

  void _getData() async {
    final duties = Uri.https(
        'live-darbar-default-rtdb.firebaseio.com', 'kirtan_duties.json');

    final response = await http.get(duties);

    final List<dynamic> listData = json.decode(response.body);
    final List<Duty> loadedDuties = [];
    for (final duty in listData) {
      loadedDuties.add(Duty(
          ragi: duty['ragi'],
          startTime: duty['duty_start'],
          endTime: duty['duty_end']));
    }

    setState(() {
      _todayDuties = loadedDuties;
    });

    // print(listData);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) {
      if (n >= 10) return "$n";
      return "0$n";
    }

    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String twoDigitHours = twoDigits(duration.inHours);

    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _stopDownload() async {
    const snackBar = SnackBar(
        content: Text('Recording Saved at: /storage/emulated/0/Music/'));
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    await client.close();
    setState(() {
      _elapsedTime = Duration.zero;
      _downloading = false;
    });
  }

  void _startDownload() async {
    setState(() {
      _color = Colors.red;
      _borderRadius = BorderRadius.circular(100);
      _downloading = true;
      _elapsedTime = Duration.zero;
      loading = true;
    });

    client = http.Client();
    final request = http.Request('GET', Uri.parse(streamUrl));
    _response = await client.send(request);

    setState(() {
      loading = false;
      _color = Colors.white;
      _borderRadius = BorderRadius.circular(50);
    });

    // final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final file = File('/storage/emulated/0/Music/live_darbar_$timestamp.mp3');

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_downloading) {
        timer.cancel();
      } else {
        setState(() {
          _elapsedTime = Duration(seconds: _elapsedTime.inSeconds + 1);
        });
      }
    });

    await file.create();
    await _response.stream.forEach((data) {
      file.writeAsBytesSync(data, mode: FileMode.append);
    });

    setState(() {
      _downloading = false;
    });

    // cancel the stream
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
          appBar: AppBar(
            title: Text(
              'Time in Amritsar: $_timeString',
              style: const TextStyle(
                  color: Color(0xFFD6DCE6), fontFamily: 'Rubik', fontSize: 16),
            ),
            backgroundColor: const Color.fromARGB(255, 9, 11, 18),
            iconTheme: const IconThemeData(color: Color(0xFFD6DCE6)),
          ),
          bottomNavigationBar: miniPlayer(),
          drawer: Drawer(
            backgroundColor: const Color(0xFF040508),
            child: ListView(
              
              padding: EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  decoration:
                      BoxDecoration(color: Color.fromARGB(255, 9, 11, 18)),
                  child: Text(
                    'Advanced Features',
                    style: TextStyle(color: Color(0xFFD6DCE6)),
                  ),
                ),
                ListTile(
                  onTap: () async {
                    await showDialog(
                        context: context,
                        builder: (_) => const WebViewApp(
                              url:
                                  'https://old.sgpc.net/hukumnama/jpeg%20hukamnama/hukamnama.gif',
                            ));
                    interstitialAd?.show();
                    _loadInterstitialAd();
                  },
                  leading: const Icon(FontAwesomeIcons.bookOpenReader, color: Color(0xFFD6DCE6),),
                  title: const Text(
                    'Read Mukhwak',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD6DCE6),
                    ),
                  ),
                ),
                ListTile(
                  onTap: () async {
                    await showDialog(
                        context: context,
                        builder: (_) => const WebViewApp(
                              url:
                                  'https://sgpc.net/wp-content/uploads/2014/04/maryada_11.jpg',
                            ));
                    interstitialAd?.show();
                    _loadInterstitialAd();
                  },
                  leading: const Icon(FontAwesomeIcons.calendarDays, color: Color(0xFFD6DCE6),),
                  title: const Text(
                    'Daily Routine',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD6DCE6),
                    ),
                  ),
                ),
                ListTile(
                  onTap: () async {
                    await showDialog(
                        context: context,
                        builder: (_) => RagiListDialog(
                            ragiList: _todayDuties, current: _currentDuty));
                    interstitialAd?.show();
                    _loadInterstitialAd();
                  },
                  leading: const Icon(FontAwesomeIcons.userClock, color: Color(0xFFD6DCE6),),
                  title: const Text(
                    'Ragi Duties',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD6DCE6),
                    ),
                  ),
                ),
                if (!_downloading)
                  ListTile(
                    leading: const Icon(FontAwesomeIcons.recordVinyl, color: Color(0xFFD6DCE6),),
                    title: const Text(
                      'Start Recording',
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD6DCE6),
                      ),
                    ),
                    onTap: () {
                      _startDownload();
                      Navigator.pop(context);
                    },
                  ),
                if (_downloading)
                  ListTile(
                    leading: const Icon(FontAwesomeIcons.circleStop, color: Color(0xFFD6DCE6),),
                    title: const Text(
                      'Stop/Save Recording',
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD6DCE6),
                      ),
                    ),
                    onTap: () {
                      _stopDownload();
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
          backgroundColor: const Color(0xFF040508),
          body: Column(
            children: [
              if (!liveStarted)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: TextScroll(
                    "The Live Kirtan may not be started yet. Refer to daily routine time.",
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

                        interstitialAd?.show();
                        _loadInterstitialAd();
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
                        interstitialAd?.show();
                        _loadInterstitialAd();
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

                        interstitialAd?.show();
                        _loadInterstitialAd();
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
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedOpacity(
                          opacity: _downloading ? 1 : 0,
                          duration: const Duration(seconds: 1),
                          child: AnimatedContainer(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _color,
                              borderRadius: _borderRadius,
                            ),
                            // Define how long the animation should take.
                            duration: const Duration(seconds: 1),
                            // Provide an optional curve to make the animation feel smoother.
                            curve: Curves.fastOutSlowIn,
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: InkWell(
                                      onTap: _stopDownload,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Icon(
                                            Icons.stop_circle_rounded,
                                            color: Colors.red,
                                          ),
                                          Text(
                                            _formatDuration(_elapsedTime),
                                            style: const TextStyle(
                                                color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
