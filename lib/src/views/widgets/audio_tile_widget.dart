import 'package:flutter/material.dart';

class AudioTileWidget extends StatelessWidget {
  const AudioTileWidget({
    super.key,
    required this.text,
    required this.imageUrl,
    required this.height,
    required this.width,
    required this.style,
  });

  final String text;
  final String imageUrl;
  final double? height;
  final double? width;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(15), // Match the card's border radius
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primaryFixed,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(15),
            image: DecorationImage(
              image: AssetImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
              child: Text(
            text,
            textAlign: TextAlign.center,
            style: style,
          )),
        ),
      ),
    );
  }
}
