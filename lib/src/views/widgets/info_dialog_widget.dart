import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoDialogWidget extends StatelessWidget {
  const InfoDialogWidget({
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
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(LucideIcons.x),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: const Text('Information'),
          backgroundColor: ShadTheme.of(context).colorScheme.accent,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // About the App Section
                const Text(
                  'About the App',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This app is my humble contribution to the Sikh community all around the world, enabling listening to the divine kirtan anywhere in the world from Darbar Sahib Amritsar, which is the holiest site in Sikhism.',
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'By no means am I using this app for commercial purposes or with the intention of making a profit from it. If you have any concerns, kindly contact me at:',
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _launchUrl(
                    'mailto:info.sandhukirat23@gmail.com?subject=Feedback%20on%20Live%20Darbar%20App',
                  ),
                  child: const Text(
                    'Email: info.sandhukirat23@gmail.com',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Licensing Information Section
                const Text(
                  'Licensing Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Audio Source: ',
                      style: TextStyle(fontSize: 18),
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
                          style: TextStyle(
                            fontSize: 18,
                            color: ShadTheme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '2. App logo: ',
                      style: TextStyle(fontSize: 18),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _launchUrl(
                          'https://www.flaticon.com/free-icons/punjab',
                        ),
                        child: Text(
                          'Used under free license from Punjab icons created by Freepik - Flaticon',
                          style: TextStyle(
                            fontSize: 18,
                            color: ShadTheme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '3. Images: ',
                      style: TextStyle(fontSize: 18),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _launchUrl(
                          'https://artofpunjab.com/en-au/',
                        ),
                        child: Text(
                          'Sourced from Art of Punjab: https://artofpunjab.com/en-au/. They are copyright owner of all the images.',
                          style: TextStyle(
                            fontSize: 18,
                            color: ShadTheme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
