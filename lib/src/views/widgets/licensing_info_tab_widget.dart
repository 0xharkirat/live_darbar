import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class LicensingInfoTabWidget extends StatelessWidget {
  const LicensingInfoTabWidget({super.key});

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
            Text(
              'Licensing Information',
              style: ShadTheme.of(context).textTheme.h3,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Audio Source: ',
                  style: ShadTheme.of(context).textTheme.p,
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _launchUrl(
                        'https://www.sgpc.net/',
                      );
                    },
                    child: Text(
                      'All audio data is streamed from sgpc.net. Sgpc.net is the copyright owner of all the audio data.',
                      style: ShadTheme.of(context).textTheme.p.copyWith(
                            decoration: TextDecoration.underline,
                            color: ShadTheme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. App logo: ',
                  style: ShadTheme.of(context).textTheme.p,
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _launchUrl(
                      'https://www.flaticon.com/free-icons/punjab',
                    ),
                    child: Text(
                      'Used under free license from Punjab icons created by Freepik - Flaticon',
                      style: ShadTheme.of(context).textTheme.p.copyWith(
                            decoration: TextDecoration.underline,
                            color: ShadTheme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3. App Images: ',
                  style: ShadTheme.of(context).textTheme.p,
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _launchUrl(
                      'https://artofpunjab.com/',
                    ),
                    child: Text(
                      'Sourced from Art of Punjab (artofpunjab.com). Artist Kanwar Singh & his team are copyright owner of all the images.',
                      style: ShadTheme.of(context).textTheme.p.copyWith(
                            decoration: TextDecoration.underline,
                            color: ShadTheme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Once again, By no means, I am claiming ownership of any of the above. This app is created for serving the Sikh Community. By no means am I using this app for commercial purposes or with the intention of making a profit from it.',
              style: ShadTheme.of(context).textTheme.p,
            ),
          ],
        ),
      ),
    );
  }
}
