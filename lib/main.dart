import 'package:flutter/material.dart';
import 'package:live_darbar/screens/homepage.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
      theme: ThemeData().copyWith(
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Color(0xFF3E3B5D)
        ),
      scaffoldBackgroundColor: Color(0xFFDADAF0),
      ),
    );
  }
}


