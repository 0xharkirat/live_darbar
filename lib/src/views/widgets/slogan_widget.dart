import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  /// Custom TextStyle for Emojis
  TextStyle? _emojiTextStyle(TextStyle? baseStyle) {
    return baseStyle?.copyWith(
      fontFamily: GoogleFonts.notoColorEmoji()
          .fontFamily, // Ensure colorful emoji rendering
      fontSize: baseStyle.fontSize ?? 16.0, // Match size with default text
    );
  }
}
