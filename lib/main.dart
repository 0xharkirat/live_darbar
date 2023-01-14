import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.orange.shade800,
          title: Text("Sri Darbar Sahib Live",
          ),
        ),
        body: SafeArea(
          child: AppBody(),
        ),


      ),
    );
  }
}

class AppBody extends StatefulWidget {
  const AppBody({Key? key}) : super(key: key);

  @override
  State<AppBody> createState() => _AppBodyState();
}

class _AppBodyState extends State<AppBody> {

  String buttonText = "Play";
  bool isPlaying = false;
  final liveKirtan = AudioPlayer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.orange.shade800,
        ),
        onPressed: (){

          setState( () {
            if (isPlaying){
              buttonText = "Play";
              isPlaying = false;
              liveKirtan.stop();

            }
            else{
              buttonText = "Pause";
              isPlaying = true;
              liveKirtan.play(UrlSource("https://live.sgpc.net:8443/;nocache=889869audio_file.mp3"));

            }


          });
          print("is playing: $isPlaying");
        },
        child: Text(buttonText),
      ),
    );
  }
}
