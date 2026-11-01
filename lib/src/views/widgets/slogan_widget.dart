import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SloganWidget extends StatelessWidget {
  const SloganWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = ShadTheme.of(context).textTheme.p;

    return Column(
      children: [
        // Line 1: Punjabi Slogan with Emojis
        SizedBox(
          width: double.infinity,
          child: SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: "🙏⚔️", style: _emojiTextStyle(defaultTextStyle)),
                TextSpan(text: " ਦੇਗ ਤੇਗ ਫ਼ਤਿਹ ", style: defaultTextStyle),
                TextSpan(
                    text: "⚔️🙏", style: _emojiTextStyle(defaultTextStyle)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Line 2: English Slogan
        SizedBox(
          width: double.infinity,
          child: SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: "🙏⚔️", style: _emojiTextStyle(defaultTextStyle)),
                TextSpan(text: " Degh Tegh Fateh ", style: defaultTextStyle),
                TextSpan(
                    text: "⚔️🙏", style: _emojiTextStyle(defaultTextStyle)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Line 3: English Meaning
        SizedBox(
          width: double.infinity,
          child: SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: "🙏⚔️", style: _emojiTextStyle(defaultTextStyle)),
                TextSpan(
                    text: " Victory to Charity and Arms ",
                    style: defaultTextStyle),
                TextSpan(
                    text: "⚔️🙏", style: _emojiTextStyle(defaultTextStyle)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// Emoji render in the platform's own colour font.
  ///
  /// This used to force Noto Color Emoji through `google_fonts`, which fetches
  /// a multi-megabyte font over the network to draw two glyphs. Android, iOS
  /// and macOS all ship a colour emoji face and pick it up automatically, so
  /// the override bought nothing on the platforms that matter and cost a
  /// download on first launch.
  TextStyle? _emojiTextStyle(TextStyle? baseStyle) {
    return baseStyle?.copyWith(fontSize: baseStyle.fontSize ?? 16.0);
  }
}
