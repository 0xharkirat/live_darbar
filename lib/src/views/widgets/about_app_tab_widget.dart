import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AboutAppTabWidget extends StatelessWidget {
  const AboutAppTabWidget({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About the App',
              style: ShadTheme.of(context).textTheme.h3,
            ),
            const SizedBox(height: 16),
            Text(
                'This app is my humble contribution to the Sikh community all around the world, enabling listening to the divine kirtan anywhere in the world from Darbar Sahib Amritsar, which is the holiest site in Sikhism.',
                style: ShadTheme.of(context).textTheme.p),
            const SizedBox(height: 16),
            Text(
                'By no means am I using this app for commercial purposes or with the intention of making a profit from it.',
                style: ShadTheme.of(context).textTheme.p),
            const SizedBox(height: 16),
            Text(
                'If you have any concerns or feedback, feel free to reach out to me using this link:',
                style: ShadTheme.of(context).textTheme.p),
            const SizedBox(height: 16),
            ShadButton.outline(
              icon: const Icon(LucideIcons.externalLink),
              onPressed: onPressed,
              child: const Text(
                'Contact Me',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
