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
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: ShadTheme.of(context).colorScheme.card,
        border: Border.all(
          color: ShadTheme.of(context).colorScheme.border,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Material(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                  child: Text(
                text,
                textAlign: TextAlign.center,
                style: style,
              )),
            ),
          ),
        ),
      ),
    );
  }
}
