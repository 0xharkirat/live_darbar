import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AudioTileWidget extends StatelessWidget {
  const AudioTileWidget({
    super.key,
    required this.text,
    required this.imageUrl,
    required this.height,
    required this.width,
    required this.style,
    required this.onTap,
  });

  final String text;
  final String imageUrl;
  final double? height;
  final double? width;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(16), // Match the card's border radius
          child: Container(
            height: height,
            width: width,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: ShadTheme.of(context).colorScheme.border,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
              // image: DecorationImage(
              //   image: AssetImage(imageUrl),
              //   fit: BoxFit.cover,
              // ),
            ),
            child: Center(
                child: Text(
              text,
              textAlign: TextAlign.center,
              style: style,
            )),
          ),
        ),
      ),
    );
  }
}
