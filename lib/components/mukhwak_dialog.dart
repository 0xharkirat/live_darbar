import 'package:flutter/material.dart';

class InteractiveDialog extends StatelessWidget {
  const InteractiveDialog({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: InteractiveViewer(
          child: Image.network(
              url),
        ));
  }
}
