import 'package:flutter/material.dart';
import 'package:live_darbar/models/duty.dart';

class RagiListDialog extends StatelessWidget {
  const RagiListDialog(
      {super.key, required this.ragiList, required this.current});

  final List<Duty> ragiList;
  final Duty? current;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      elevation: 1.5,
      backgroundColor: Theme.of(context).colorScheme.background,
      insetPadding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Today\'s Duties',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground)),
          ),
          Expanded(
            child: ListView.builder(
                itemCount: ragiList.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    trailing: ragiList[index] == current
                        ? Icon(
                            Icons.arrow_left,
                            color:
                                Theme.of(context).colorScheme.onInverseSurface,
                          )
                        : const SizedBox(),
                    selected: ragiList[index] == current ? true : false,
                    selectedTileColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                    leading: Text(
                      '${ragiList[index].startTime} - ${ragiList[index].endTime}',
                      style: TextStyle(
                        color: ragiList[index] == current
                            ? Theme.of(context).colorScheme.onInverseSurface
                            : Theme.of(context).colorScheme.inverseSurface,
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    title: Text(
                      ragiList[index].ragi,
                      style: TextStyle(
                        color: ragiList[index] == current
                            ? Theme.of(context).colorScheme.onInverseSurface
                            : Theme.of(context).colorScheme.inverseSurface,
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
          ),
        ],
      ),
    );
  }
}
