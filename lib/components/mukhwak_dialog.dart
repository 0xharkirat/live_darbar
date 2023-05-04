import 'package:flutter/material.dart';

class MukhwakDialog extends StatelessWidget {
  const MukhwakDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(8),
        child: InteractiveViewer(
          child: Image.network(
              'https://old.sgpc.net/hukumnama/jpeg%20hukamnama/hukamnama.gif'),
        ));
  }
}
