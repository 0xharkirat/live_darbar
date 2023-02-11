import 'package:flutter/material.dart';
import 'package:live_darbar/screens/homepage.dart';
import 'package:live_darbar/services/service_locator.dart';

void main() async {
  await setupServiceLocator();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),

    );
  }
}


