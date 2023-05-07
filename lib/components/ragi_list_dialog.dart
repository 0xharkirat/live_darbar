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
      backgroundColor: const Color(0xFF040508),
      insetPadding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Today\'s Duties',
              style: TextStyle(
                color: Color(0xFFD6DCE6),
                fontFamily: 'Rubik',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
                itemCount: ragiList.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    textColor: ragiList[index] == current
                        ? const Color(0xFF040508)
                        : const Color(0xFFD6DCE6),
                    trailing: ragiList[index] == current
                        ? const Icon(Icons.arrow_left)
                        : const SizedBox(),
                    selected: ragiList[index] == current ? true : false,
                    selectedTileColor: const Color(0xFFD6DCE6),
                    leading: Text(
                      '${ragiList[index].startTime} - ${ragiList[index].endTime}',
                      style: const TextStyle(
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    title: Text(
                      ragiList[index].ragi,
                      style: const TextStyle(
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
