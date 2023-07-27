import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_offline/flutter_offline.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:live_darbar/components/ragi_list_dialog.dart';
import 'package:live_darbar/components/sleep_timer.dart';
import 'package:live_darbar/components/webview_dialog.dart';
import 'package:live_darbar/components/youtube_link.dart';
import 'package:live_darbar/data/timer_data.dart';
import 'package:live_darbar/logics/page_manager.dart';
import 'package:live_darbar/models/duty.dart';
import 'package:live_darbar/models/timer.dart';
import 'package:live_darbar/models/youtube.dart';
import 'package:live_darbar/notifiers/progress_notifier.dart';
import 'package:live_darbar/utils/firestore.dart';
import 'package:live_darbar/utils/permission.dart';
import 'package:path_provider/path_provider.dart';
import 'package:live_darbar/components/round_icon_button.dart';
import 'package:intl/intl.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

late final PageManager _pageManager;
late final Random random;

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool isPlaying = false;
  late http.StreamedResponse _response;
  late bool _downloading;

  String _headerImagePath = 'images/player.jpg';

  var client;
  bool loading = false;

  Duration _elapsedTime = Duration.zero;

  List<Duty> _todayDuties = [];
  List<YoutubeLink> _todayLinks = [];
  Duty? _currentDuty;
  YoutubeLink? _currentLive;
  late DateTime ist;
  late String today;

  late String _timeString;
  late Timer timer;
  late Timer t;

  bool sleepTimerSet = false;

  Channel? selectedChannel;

  bool visible = false;
  bool bottomAnimation = false;

  late bool liveStarted;
  int single = 0;

  double getAngle() {
    var value = _controller?.value ?? 0;
    return -value * 2 * pi;
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
                                print('loading...........');

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
                                print('paused..............');
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
                                print("playing.........");
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
                              case ButtonState.completed:
                                if (single == 0) {
                                  single = 1;
                                  isPlaying = false;
                                  _controller?.reset();
                                }
                                return RoundIconButton(
                                    isPlaying: isPlaying,
                                    icon: FontAwesomeIcons.play,
                                    onPressed: bottomAnimation
                                        ? () {
                                            single = 0;
                                            _pageManager.resume();
                                            setState(() {
                                              isPlaying = true;
                                              _controller?.repeat();
                                            });
                                          }
                                        : null);
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
        setState(() {
          isPlaying = false;

          _controller?.reset();
        });
      });
    } else {
      t.cancel();
      sleepTimerSet = true;
      t = Timer(Duration(minutes: time.time), () {
        _pageManager.pause();
        sleepTimerSet = false;
        setState(() {
          isPlaying = false;

          _controller?.reset();
        });
      });
    }
  }

  void _openYoutubeLiveOverlay() {
    showModalBottomSheet(
        isScrollControlled: true,
        useSafeArea: true,
        context: context,
        builder: ((context) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Live YouTube Channel',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontWeight: FontWeight.bold)),
                const SizedBox(
                  height: 10,
                ),
                for (final link in _todayLinks)
                  YoutubeTile(
                      link: link,
                      onTapLink: _launchYouTubeVideo,
                      current: _currentLive)
              ],
            ),
          );
        }));
  }

  void _launchYouTubeVideo(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
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
  }

  @override
  void dispose() {
    super.dispose();
    timer.cancel();

    _controller?.dispose();
    _pageManager.dispose();
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

    if (_todayLinks.isNotEmpty) {
      final morningLiveStart =
          DateTime.utc(ist.year, ist.month, ist.day, 3, 30);

      final afternoonLive = DateTime.utc(ist.year, ist.month, ist.day, 12, 30);
      final eveningLive = DateTime.utc(ist.year, ist.month, ist.day, 18, 30);

      if (ist.isAfter(morningLiveStart) &&
          ist.isBefore(morningLiveStart.add(const Duration(hours: 5, minutes: 20)))) {
        // print('morning live now');

        setState(() {
          _currentLive = _todayLinks[0];
        });
      } else if (ist.isAfter(afternoonLive) &&
          ist.isBefore(afternoonLive.add(const Duration(hours: 2, minutes: 20)))) {
        // print('afternoon live now');
        setState(() {
          _currentLive = _todayLinks[1];
        });
      } else if (ist.isAfter(eveningLive) &&
          ist.isBefore(eveningLive.add(const Duration(hours: 2, minutes: 20)))) {
        // print('evening live now');
        setState(() {
          _currentLive = _todayLinks[2];
        });
      }

      // print(_currentLive!.time);
    }

    setState(() {
      _timeString = formattedDateTime;
      // isliveStarted(ist);
    });
  }

  void _getData() async {
    final List<dynamic> listData = await FirestoreData.getRagiData();
    final List<dynamic> linkData = await FirestoreData.getYoutubeLinks();

    final List<Duty> loadedDuties = [];
    final List<YoutubeLink> loadedLinks = [];

    for (final duty in listData) {
      

      if (duty['id'] != null) {
        loadedDuties.add(Duty(
            ragi: duty['ragi'],
            startTime: duty['duty_start'],
            endTime: duty['duty_end']));
      } else if (duty['date'].length != 0) {
        today = duty['date'];
      }
    }

    for (final link in linkData) {
      
      loadedLinks.add(YoutubeLink(
          date: link['date'], link: link['link'], time: link['id']));
    }

    setState(() {
      _todayDuties = loadedDuties;
      _todayLinks = loadedLinks;
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
        Platform.isAndroid
            ? 'Recording Saved at: /storage/emulated/0/Music/'
            : 'Recording Saved at: Files/Live Darbar/',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onInverseSurface,
        ),
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
      final request = http.Request('GET', Uri.parse(PageManager.liveKirtan));
      _response = await client.send(request);

      setState(() {
        loading = false;
      });

      // final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().microsecondsSinceEpoch;

      File file;

      if (Platform.isIOS) {
        final documents = await getApplicationDocumentsDirectory();
        file = File('${documents.path}/live_darbar_$timestamp.mp3');
        // print(documents.path);
      } else {
        file = File('/storage/emulated/0/Music/live_darbar_$timestamp.mp3');
      }

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
        body: OfflineBuilder(
          connectivityBuilder: (
            BuildContext context,
            ConnectivityResult connectivity,
            Widget child,
          ) {
            final connected = connectivity != ConnectivityResult.none;
            if (!connected) {
              _pageManager.stop();
              isPlaying = false;
              selectedChannel = null;
              _controller?.reset();
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    height: 32.0,
                    left: 0.0,
                    right: 0.0,
                    bottom: 0.0,
                    child: AnimatedOpacity(
                      opacity: !connected ? 1.0 : 0,
                      duration: const Duration(seconds: 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        color: connected
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.error,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: connected
                              ? const Text('Back Online')
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    const Text('No connection'),
                                    const SizedBox(width: 8.0),
                                    SizedBox(
                                      width: 12.0,
                                      height: 12.0,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Theme.of(context)
                                                    .colorScheme
                                                    .onError),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      "You're offline. Check your connection.",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground),
                    ),
                  ),
                ],
              );
            }

            return child;
          },
          child: Container(
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
                            _headerImagePath = 'images/live_kirtan_player.jpg';
                            _controller?.repeat();
                            bottomAnimation = true;
                          });
                        },

                        // tileColor: Theme.of(context).colorScheme.onInverseSurface,
                        leading: Image.asset(
                          "images/live_kirtan.jpg",
                          width: 50.0,
                          fit: BoxFit.cover,
                        ),
                        title: Text(
                          'Live Kirtan',
                          style:
                              Theme.of(context).textTheme.titleLarge!.copyWith(
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
                          single = 0;

                          setState(() {
                            selectedChannel = Channel.mukhwak;
                            isPlaying = true;
                            visible = true;
                            _headerImagePath = 'images/mukhwak_player.jpg';
                            _controller?.repeat();
                            bottomAnimation = true;
                          });
                        },
                        leading: Image.asset(
                          "images/mukhwak.jpg",
                          width: 50.0,
                          fit: BoxFit.cover,
                        ),
                        title: Text(
                          'Today\'s Mukhwak',
                          style:
                              Theme.of(context).textTheme.titleLarge!.copyWith(
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
                        trailing:
                            selectedChannel == Channel.mukhwak && isPlaying
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
                          single = 0;

                          setState(() {
                            selectedChannel = Channel.mukhwakKatha;
                            isPlaying = true;
                            visible = true;
                            _headerImagePath = 'images/katha_player.jpg';
                            _controller?.repeat();
                            bottomAnimation = true;
                          });
                        },
                        leading: Image.asset(
                          "images/katha.jpg",
                          width: 50.0,
                          fit: BoxFit.cover,
                        ),
                        title: Text(
                          'Mukhwak Katha',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .copyWith(
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
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Card(
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5)),
                                        tileColor: Theme.of(context)
                                            .colorScheme
                                            .onInverseSurface,
                                        onTap: () async {
                                          await showDialog(
                                            context: context,
                                            builder: (_) => const WebViewApp(
                                              url:
                                                  'https://old.sgpc.net/hukumnama/jpeg%20hukamnama/hukamnama.gif',
                                              title: 'Mukhwak',
                                            ),
                                          );
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
                                  ),
                                  Expanded(
                                    child: Card(
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5)),
                                        tileColor: Theme.of(context)
                                            .colorScheme
                                            .onInverseSurface,
                                        onTap: () async {
                                          await showDialog(
                                              context: context,
                                              builder: (_) => const WebViewApp(
                                                    url:
                                                        'https://sgpc.net/wp-content/uploads/2014/04/maryada_11.jpg',
                                                    title: 'Daily Routine',
                                                  ));
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
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Card(
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5)),
                                        tileColor: Theme.of(context)
                                            .colorScheme
                                            .onInverseSurface,
                                        onTap: () async {
                                          await showDialog(
                                              context: context,
                                              builder: (_) => RagiListDialog(
                                                    ragiList: _todayDuties,
                                                    current: _currentDuty,
                                                    today: today,
                                                  ));
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
                                  ),
                                  Expanded(
                                    child: !_downloading
                                        ? Card(
                                            child: ListTile(
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(5)),
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .inverseSurface,
                                                    ),
                                              ),
                                              onTap: () {
                                                _startDownload();
                                              },
                                            ),
                                          )
                                        : Card(
                                            child: ListTile(
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(5)),
                                              tileColor: loading
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onInverseSurface
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer,
                                              leading: loading
                                                  ? null
                                                  : Icon(
                                                      FontAwesomeIcons
                                                          .microphoneSlash,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onInverseSurface),
                                              title: loading
                                                  ? Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .error,
                                                      ),
                                                    )
                                                  : Text(
                                                      _formatDuration(
                                                          _elapsedTime),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium!
                                                          .copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Theme.of(
                                                                    context)
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
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Card(
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5)),
                                        tileColor: Theme.of(context)
                                            .colorScheme
                                            .onInverseSurface,
                                        onTap: _openYoutubeLiveOverlay,
                                        leading: Icon(
                                          FontAwesomeIcons.youtube,
                                          color: _currentLive != null
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onErrorContainer
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .inverseSurface,
                                        ),
                                        title: Text(
                                          'Live YouTube Channel',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium!
                                              .copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: _currentLive != null
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .onErrorContainer
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .inverseSurface,
                                              ),
                                        ),
                                        trailing: _currentLive != null
                                            ? Image.asset(
                                                'images/live.gif',
                                                width: 20.0,
                                              )
                                            : const SizedBox(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const TextScroll(
                  "All data is sourced from SGPC.net; SGPC is copyright owner of all the data and media; Ragi list and duties may not be updated on SGPC.net in realtime.",
                  velocity: Velocity(pixelsPerSecond: Offset(30, 0)),
                  // delayBefore: Duration(seconds: 1),
                  intervalSpaces: 110,
                  style: TextStyle(
                    color: Color(0xFFE9E1D9),
                    fontFamily: 'Rubik',
                  ),
                ),
              ],
            ),
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
