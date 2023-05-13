import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class WebViewApp extends StatelessWidget {
  const WebViewApp({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Dialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        
        insetPadding: const EdgeInsets.all(8),
        child: InteractiveViewer(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                  child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.onBackground,
              ),),
              CachedNetworkImage(
                imageUrl: url,
              )
            ],
          ),
        ));
  }
}
