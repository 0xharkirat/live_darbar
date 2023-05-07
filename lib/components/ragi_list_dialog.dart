import 'package:flutter/material.dart';
import 'package:live_darbar/models/duty.dart';

class RagiListDialog extends StatelessWidget {
  const RagiListDialog({super.key, required this.ragiList, required this.current});

  final List<Duty> ragiList;
  final Duty? current;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 9, 11, 18),
      body: Center(
        child: Column(
          children: [
            const Text(
              'Today\'s Duties',
              style: TextStyle(
                color: Color(0xFFD6DCE6),
                fontFamily: 'Rubik',
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ragiList.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListTile(
                        textColor: ragiList[index] == current? const Color.fromARGB(255, 9, 11, 18) : const Color(0xFFD6DCE6),
                        trailing: ragiList[index] == current? const Icon(Icons.arrow_left): const Text(''),
                      
                        selected
                        : ragiList[index] == current? true: false,
                        
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
                      ),
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
