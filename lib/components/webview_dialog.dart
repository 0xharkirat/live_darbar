import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class WebViewApp extends StatelessWidget {
  const WebViewApp({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Dialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: const Color(0xFF040508).withOpacity(0.80),
        insetPadding: const EdgeInsets.all(8),
        child: InteractiveViewer(
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Center(
                  child: CircularProgressIndicator(
                color: Color(0xFFD6DCE6),
              )),
              CachedNetworkImage(
                imageUrl: url,
              )
            ],
          ),
        ));
  }
}
