import 'package:flutter/material.dart';
import 'package:live_darbar/models/timer.dart';

class SleepTimer extends StatelessWidget {
  const SleepTimer({super.key, required this.timerModel, required this.onSelectTimer});
  final TimerModel timerModel;
  final Function() onSelectTimer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        onTap: onSelectTimer,
        child: Text(timerModel.title, style: const TextStyle(color: Color(0xFFD6DCE6), fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Rubik'),),
      ),
    );
  }
}
