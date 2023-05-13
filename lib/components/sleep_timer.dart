import 'package:flutter/material.dart';
import 'package:live_darbar/models/timer.dart';

class SleepTimer extends StatelessWidget {
  const SleepTimer(
      {super.key, required this.timerModel, required this.onSelectTimer});
  final TimerModel timerModel;
  final Function() onSelectTimer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: InkWell(
          onTap: onSelectTimer,
          splashColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Text(
            timerModel.title,
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ),
    );
  }
}
