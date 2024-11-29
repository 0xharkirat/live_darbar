import 'package:flutter/material.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutMeTabWidget extends StatelessWidget {
  const AboutMeTabWidget({
    super.key,
  });

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About Me', style: ShadTheme.of(context).textTheme.h3),
            const SizedBox(height: 16),
            Text(
              'Hi, I am Harkirat, a perpetual learner, constantly exploring new ideas and technologies in the field of computer science.  ',
              style: ShadTheme.of(context).textTheme.p,
            ),
            const SizedBox(height: 16),
            Text(
              'I am learning & creating better technologies for the greater good of Humanity.',
              style: ShadTheme.of(context).textTheme.p,
            ),
            const SizedBox(height: 16),
            Text(
              'I also play Tabla in Kirtan (Religious music).',
              style: ShadTheme.of(context).textTheme.p,
            ),
            const SizedBox(height: 16),
            ShadButton.raw(
              variant: ShadButtonVariant.link,
              icon: const Icon(LucideIcons.youtube),
              child: const Text(
                'My Tabla Videos',
              ),
              onPressed: () => _launchUrl(
                'https://www.youtube.com/watch?v=0lhJ_0ve5q8&list=PLLx2TfaNTPhyQPAIfEnib4MfXppYtYVyB',
              ),
            ),
            ShadButton.raw(
              variant: ShadButtonVariant.link,
              icon: const Icon(LucideIcons.externalLink),
              child: const Text(
                'My Story',
              ),
              onPressed: () => _launchUrl(
                'https://openinapp.link/so8kh',
              ),
            ),
            ShadButton.raw(
              variant: ShadButtonVariant.link,
              icon: const Icon(LucideIcons.linkedin),
              child: const Text(
                'My LinkedIn',
              ),
              onPressed: () => _launchUrl(
                'https://www.linkedin.com/in/0xharkirat/',
              ),
            )
          ],
        ),
      ),
    );
  }
}
