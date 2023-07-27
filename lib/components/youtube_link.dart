import 'package:flutter/material.dart';
import 'package:live_darbar/models/youtube.dart';

class YoutubeTile extends StatelessWidget {
  const YoutubeTile(
      {super.key,
      required this.link,
      required this.onTapLink,
      required this.current});

  final YoutubeLink link;
  final void Function(String link) onTapLink;
  final YoutubeLink? current;

  String capitalize(String word) {
    return word[0].toUpperCase() + word.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        onTapLink(link.link);
      },
      title: Text(
          current == link
              ? '${capitalize(link.time)} - Now Live'
              : '${capitalize(link.time)} - Recording',
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.bold,
              )),
      subtitle: Text(
        'Date: ${link.date}',
        style: Theme.of(context)
            .textTheme
            .titleMedium!
            .copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      trailing: current == link
          ? Image.asset(
              'images/live.gif',
              width: 20.0,
            )
          : const SizedBox(),
    );
  }
}
