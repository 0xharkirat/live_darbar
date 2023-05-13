import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:live_darbar/components/ragi_list_dialog.dart';
import 'package:live_darbar/components/sleep_timer.dart';
import 'package:live_darbar/components/webview_dialog.dart';
import 'package:live_darbar/data/timer_data.dart';
import 'package:live_darbar/logics/page_manager.dart';
import 'package:live_darbar/models/duty.dart';
import 'package:live_darbar/models/timer.dart';
import 'package:live_darbar/notifiers/progress_notifier.dart';
import 'package:live_darbar/utils/ad_state.dart';
import 'package:live_darbar/utils/permission.dart';
import 'package:open_file/open_file.dart';
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
late final Random random;

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool isPlaying = false;
  late http.StreamedResponse _response;
  late bool _downloading;
  late String _localFilePath;

  String _headerImagePath = 'images/live_kirtan.jpg';

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

  double getAngle() {
    var value = _controller?.value ?? 0;
    return value * 2 * pi;
  }

  Widget playerHeader() {
    return Column(
      children: [
        Row(
          children: [
            AnimatedBuilder(
              animation: _controller!,
              builder: (_, child) {
                return Transform.rotate(
                  angle: getAngle(),
                  child: child,
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60.0),
                child: Image.asset(
                  _headerImagePath,
                  width: 120.0,
                  height: 120.0,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(
              width: 10.0,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: _pageManager.currentSongTitleNotifier,
                    builder: (_, title, __) {
                      return Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPlaying
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.inverseSurface),
                      );
                    },
                  ),
                  const SizedBox(
                    height: 5.0,
                  ),
                  visible
                      ? AudioProgressBar(
                          isPlaying: isPlaying,
                        )
                      : liveStarted
                          ? _currentDuty?.ragi != null
                              ? Text(
                                  'Current Ragi: ${_currentDuty?.ragi}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(
                                          color: isPlaying
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .inverseSurface),
                                )
                              : TextScroll(
                                  'Path or Ardas is going to start, or is currently going on, or change of Ragi duty according to the Timetable.',
                                  velocity: const Velocity(
                                      pixelsPerSecond: Offset(30, 0)),
                                  // delayBefore: Duration(seconds: 1),
                                  intervalSpaces: 60,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(
                                          color: isPlaying
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .inverseSurface),
                                )
                          : Container(),
                  const SizedBox(
                    height: 10.0,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      AnimatedOpacity(
                        opacity: bottomAnimation ? 1.0 : 0,
                        duration: const Duration(seconds: 1),
                        child: ValueListenableBuilder<ButtonState>(
                          valueListenable: _pageManager.buttonNotifier,
                          builder: (_, value, __) {
                            switch (value) {
                              case ButtonState.loading:
                                return SizedBox(
                                  width: 52.0,
                                  height: 52.0,
                                  child: CircularProgressIndicator(
                                    color: isPlaying
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                  ),
                                );
                              case ButtonState.paused:
                                return RoundIconButton(
                                    isPlaying: isPlaying,
                                    icon: FontAwesomeIcons.play,
                                    onPressed: bottomAnimation
                                        ? () {
                                            _pageManager.resume();
                                            setState(() {
                                              isPlaying = true;
                                              _controller?.repeat();
                                            });
                                          }
                                        : null);
                              case ButtonState.playing:
                                return RoundIconButton(
                                    isPlaying: isPlaying,
                                    icon: FontAwesomeIcons.pause,
                                    onPressed: () {
                                      _pageManager.pause();
                                      setState(() {
                                        isPlaying = false;

                                        _controller?.reset();
                                      });
                                    });
                            }
                          },
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: visible || !isPlaying ? 0 : 1,
                        duration: const Duration(milliseconds: 500),
                        child: ElevatedButton.icon(
                          onPressed: visible || !isPlaying
                              ? null
                              : _openSleepTimerOverlay,
                          icon: Icon(
                            FontAwesomeIcons.clock,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                          label: Text(
                            'Timer',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
        const SizedBox(
          height: 15,
        ),
        Text(
          'Time in Amritsar: $_timeString',
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
              color: isPlaying
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.inverseSurface),
        ),
      ],
    );
  }

  void showInterstitialAdRandom() async {
    final randomNumber = random.nextInt(10);
    // print(randomNumber);
    if (randomNumber == 0) {
      await interstitialAd?.show();
      _loadInterstitialAd();
    }
  }

  void selectTimer(TimerModel time) {
    final snackBar = SnackBar(
      elevation: 8,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      content: Text(
        'Timer set for ${time.title}.',
        style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface),
      ),
      action: SnackBarAction(
        textColor: Theme.of(context).colorScheme.onInverseSurface,
        label: "Cancel",
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
              Text('Timer',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontWeight: FontWeight.bold)),
              const SizedBox(
                height: 10,
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
      backgroundColor: Theme.of(context).colorScheme.background,
      elevation: 2.0,
    );
  }

  @override
  void initState() {
    super.initState();
    _pageManager = PageManager();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 10));
    ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    _timeString = _formatDateTime(ist);
    _downloading = false;
    random = Random();

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
    _controller?.dispose();
    _pageManager.dispose();
    interstitialAd?.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMMM dd, yyyy - HH:mm:ss').format(dateTime);
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
        DateFormat('MMMM dd, yyyy - HH:mm:ss').format(ist);

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
    final snackBar = SnackBar(
      elevation: 8,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      content: Text(
        'Recording Saved at: /storage/emulated/0/Music/',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onInverseSurface,
        ),
      ),
      action: SnackBarAction(
        textColor: Theme.of(context).colorScheme.onInverseSurface,
        label: "Open",
        onPressed: () async {
          await OpenFile.open('/storage/emulated/0/Music');
          print('file opened $_localFilePath');
        },
      ),
    );
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    await client.close();
    setState(() {
      _elapsedTime = Duration.zero;
      _downloading = false;
    });
  }

  void _startDownload() async {
    bool hasPermission = await PermissionHandler.checkStoragePermission();

    if (hasPermission) {
      setState(() {
        _downloading = true;
        _elapsedTime = Duration.zero;
        loading = true;
      });

      client = http.Client();
      final request = http.Request('GET', Uri.parse(streamUrl));
      _response = await client.send(request);

      setState(() {
        loading = false;
      });

      // final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final file = File('/storage/emulated/0/Music/live_darbar_$timestamp.mp3');
      _localFilePath = file.path;

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
    }

    // cancel the stream
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (!liveStarted)
                const TextScroll(
                  "The Live Kirtan may not be started yet. Refer to daily routine time.",
                  velocity: Velocity(pixelsPerSecond: Offset(30, 0)),
                  // delayBefore: Duration(seconds: 1),
                  intervalSpaces: 60,
                  style: TextStyle(
                    color: Color(0xFFE9E1D9),
                    fontFamily: 'Rubik',
                  ),
                ),
              AnimatedContainer(
                height: 200,
                padding: const EdgeInsets.all(10.0),
                duration: const Duration(seconds: 1),
                decoration: BoxDecoration(
                  color: isPlaying
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onInverseSurface,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                curve: Curves.fastOutSlowIn,
                child: playerHeader(),
              ),
              const SizedBox(
                height: 20.0,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ListTile(
                      onTap: () {
                        _pageManager.play(0);

                        setState(() {
                          selectedChannel = Channel.liveKirtan;
                          isPlaying = true;
                          visible = false;
                          _headerImagePath = 'images/live_kirtan.jpg';
                          _controller?.repeat();
                          bottomAnimation = true;
                        });
                        showInterstitialAdRandom();
                      },

                      // tileColor: Theme.of(context).colorScheme.onInverseSurface,
                      leading: Image.asset(
                        "images/live_kirtan.jpg",
                        width: 50.0,
                        fit: BoxFit.cover,
                      ),
                      title: Text(
                        'Live Kirtan',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: selectedChannel == Channel.liveKirtan
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .inverseSurface,
                            ),
                      ),
                      trailing:
                          selectedChannel == Channel.liveKirtan && isPlaying
                              ? Image.asset(
                                  'images/bars.gif',
                                  width: 20.0,
                                )
                              : const SizedBox(),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    ListTile(
                      onTap: () {
                        _pageManager.play(1);

                        setState(() {
                          selectedChannel = Channel.mukhwak;
                          isPlaying = true;
                          visible = true;
                          _headerImagePath = 'images/mukhwak.jpg';
                          _controller?.repeat();
                          bottomAnimation = true;
                        });
                        showInterstitialAdRandom();
                      },
                      leading: Image.asset(
                        "images/mukhwak.jpg",
                        width: 50.0,
                        fit: BoxFit.cover,
                      ),
                      title: Text(
                        'Today\'s Mukhwak',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: selectedChannel == Channel.mukhwak
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .inverseSurface,
                            ),
                      ),
                      trailing: selectedChannel == Channel.mukhwak && isPlaying
                          ? Image.asset(
                              'images/bars.gif',
                              width: 20.0,
                            )
                          : const SizedBox(),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    ListTile(
                      onTap: () {
                        _pageManager.play(2);

                        setState(() {
                          selectedChannel = Channel.mukhwakKatha;
                          isPlaying = true;
                          visible = true;
                          _headerImagePath = 'images/katha.jpg';
                          _controller?.repeat();
                          bottomAnimation = true;
                        });
                        showInterstitialAdRandom();
                      },
                      leading: Image.asset(
                        "images/katha.jpg",
                        width: 50.0,
                        fit: BoxFit.cover,
                      ),
                      title: Text(
                        'Mukhwak Katha',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: selectedChannel == Channel.mukhwakKatha
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .inverseSurface,
                            ),
                      ),
                      trailing:
                          selectedChannel == Channel.mukhwakKatha && isPlaying
                              ? Image.asset(
                                  'images/bars.gif',
                                  width: 20.0,
                                )
                              : const SizedBox(),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Card(
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5)),
                                  tileColor: Theme.of(context)
                                      .colorScheme
                                      .onInverseSurface,
                                  onTap: () async {
                                    await showDialog(
                                      context: context,
                                      builder: (_) => const WebViewApp(
                                        url:
                                            'https://old.sgpc.net/hukumnama/jpeg%20hukamnama/hukamnama.gif',
                                      ),
                                    );
                                    showInterstitialAdRandom();
                                  },
                                  leading: Icon(
                                    FontAwesomeIcons.bookOpenReader,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .inverseSurface,
                                  ),
                                  title: Text(
                                    'Read Mukhwak',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium!
                                        .copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .inverseSurface,
                                        ),
                                  ),
                                ),
                              ),
                              Card(
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5)),
                                  tileColor: Theme.of(context)
                                      .colorScheme
                                      .onInverseSurface,
                                  onTap: () async {
                                    await showDialog(
                                        context: context,
                                        builder: (_) => const WebViewApp(
                                              url:
                                                  'https://sgpc.net/wp-content/uploads/2014/04/maryada_11.jpg',
                                            ));
                                    showInterstitialAdRandom();
                                  },
                                  leading: Icon(
                                    FontAwesomeIcons.calendarDays,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .inverseSurface,
                                  ),
                                  title: Text(
                                    'Daily Routine',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium!
                                        .copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .inverseSurface,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Card(
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5)),
                                  tileColor: Theme.of(context)
                                      .colorScheme
                                      .onInverseSurface,
                                  onTap: () async {
                                    await showDialog(
                                        context: context,
                                        builder: (_) => RagiListDialog(
                                            ragiList: _todayDuties,
                                            current: _currentDuty));
                                    showInterstitialAdRandom();
                                  },
                                  leading: Icon(
                                    FontAwesomeIcons.userClock,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .inverseSurface,
                                  ),
                                  title: Text(
                                    'Ragi Duties',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium!
                                        .copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .inverseSurface,
                                        ),
                                  ),
                                ),
                              ),
                              if (!_downloading)
                                Card(
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5)),
                                    tileColor: Theme.of(context)
                                        .colorScheme
                                        .onInverseSurface,
                                    leading: Icon(
                                      FontAwesomeIcons.microphone,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .inverseSurface,
                                    ),
                                    title: Text(
                                      'Record',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .inverseSurface,
                                          ),
                                    ),
                                    onTap: () {
                                      _startDownload();
                                    },
                                  ),
                                ),
                              if (_downloading)
                                Card(
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5)),
                                    tileColor: loading
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onInverseSurface
                                        : Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                    leading: loading
                                        ? null
                                        : Icon(FontAwesomeIcons.microphoneSlash,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onInverseSurface),
                                    title: loading
                                        ? Center(
                                            child: CircularProgressIndicator(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                          )
                                        : Text(
                                            _formatDuration(_elapsedTime),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium!
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onInverseSurface,
                                                ),
                                          ),
                                    onTap: loading
                                        ? null
                                        : () {
                                            _stopDownload();
                                          },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
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
          ),
        ),
      ),
    );
  }
}

class AudioProgressBar extends StatelessWidget {
  const AudioProgressBar({Key? key, required this.isPlaying}) : super(key: key);

  final bool isPlaying;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProgressBarState>(
      valueListenable: _pageManager.progressNotifier,
      builder: (_, value, __) {
        return ProgressBar(
          baseBarColor: isPlaying
              ? Theme.of(context).colorScheme.onInverseSurface
              : Theme.of(context).colorScheme.inverseSurface,
          progressBarColor: isPlaying
              ? Theme.of(context).colorScheme.onTertiaryContainer
              : Theme.of(context).colorScheme.tertiary,
          bufferedBarColor: isPlaying
              ? Theme.of(context).colorScheme.tertiaryContainer
              : Theme.of(context).colorScheme.onTertiary,
          thumbColor: isPlaying
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.onSecondaryContainer,
          thumbGlowColor: isPlaying
              ? Theme.of(context).colorScheme.onSecondary
              : Theme.of(context).colorScheme.secondary,
          timeLabelLocation: TimeLabelLocation.sides,
          progress: value.current,
          buffered: value.buffered,
          total: value.total,
          onSeek: _pageManager.seek,
          timeLabelTextStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: isPlaying
                  ? Theme.of(context).colorScheme.onInverseSurface
                  : Theme.of(context).colorScheme.inverseSurface),
        );
      },
    );
  }
}

enum Channel { liveKirtan, mukhwak, mukhwakKatha }
