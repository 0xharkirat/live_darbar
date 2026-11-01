import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/core/open_link.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/views/widgets/language_switch.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';

/// About the app, the person who made it, and whose work it carries.
///
/// One scrolling page instead of three tabs in a dialog. Tabs hid two thirds
/// of the content behind labels nobody tapped, and a dialog has no back
/// gesture; a page has both a title and the edge swipe people already know.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final version = ref.watch(appVersionProvider).value;

    return Scaffold(
      backgroundColor: Palette.background,
      body: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(l10n.about_this_app, style: AppType.largeTitle),
            middle: Text(l10n.about_this_app, style: AppType.headline),
            alwaysShowMiddle: false,
            backgroundColor: Palette.background.withValues(alpha: 0.92),
            border: null,
            previousPageTitle: l10n.app_title,
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Prose([l10n.about_section_p1, l10n.about_section_p2]),
                        const SizedBox(height: 16),
                        _Group(
                          children: [
                            // The language lives here as well as on home,
                            // so nobody has to go back to change it.
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                8,
                                8,
                                8,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.globe,
                                    size: 20,
                                    color: Palette.gold,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      l10n.language_tooltip,
                                      style: AppType.body,
                                    ),
                                  ),
                                  const LanguageSwitch(),
                                ],
                              ),
                            ),
                            _LinkRow(
                              icon: CupertinoIcons.chat_bubble_text,
                              label: l10n.about_section_contact,
                              url: kFeedbackUrl,
                            ),
                            _LinkRow(
                              icon: CupertinoIcons.lock_shield,
                              label: l10n.privacy_policy,
                              url: kPrivacyPolicyUrl,
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        _Heading(l10n.about_me_heading),
                        _Prose([l10n.about_me_p1, l10n.about_me_p2]),
                        const SizedBox(height: 16),
                        _Group(
                          children: [
                            _LinkRow(
                              icon: CupertinoIcons.globe,
                              label: l10n.about_me_website,
                              url: 'https://harksingh.com',
                            ),
                            _LinkRow(
                              icon: CupertinoIcons.music_note_2,
                              label: l10n.about_me_tabla_button,
                              url:
                                  'https://www.youtube.com/watch?v=0lhJ_0ve5q8&list=PLLx2TfaNTPhyQPAIfEnib4MfXppYtYVyB',
                            ),
                            _LinkRow(
                              icon: CupertinoIcons.chevron_left_slash_chevron_right,
                              label: l10n.about_me_github,
                              url: 'https://github.com/0xHARKIRAT',
                            ),
                            _LinkRow(
                              icon: CupertinoIcons.briefcase,
                              label: l10n.about_me_linkedin,
                              url: 'https://www.linkedin.com/in/talesofhark',
                            ),
                            _LinkRow(
                              icon: CupertinoIcons.play_rectangle,
                              label: l10n.about_me_youtube,
                              url: 'https://www.youtube.com/@TalesofHark',
                            ),
                            _LinkRow(
                              icon: CupertinoIcons.at,
                              label: l10n.about_me_x,
                              url: 'https://x.com/TalesofHark',
                            ),
                            _LinkRow(
                              icon: CupertinoIcons.camera,
                              label: l10n.about_me_instagram,
                              url: 'https://www.instagram.com/talesofhark',
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        _Heading(l10n.licensing_heading),
                        _Group(
                          children: [
                            _Credit(
                              source: l10n.licensing_audio_source,
                              text: l10n.licensing_audio,
                              url: 'https://www.sgpc.net/',
                            ),
                            _Credit(
                              source: l10n.licensing_images_source,
                              text: l10n.licensing_images,
                              url: 'https://artofpunjab.com/',
                            ),
                            _Credit(
                              source: l10n.licensing_logo_source,
                              text: l10n.licensing_logo,
                              url: 'https://www.flaticon.com/free-icons/punjab',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _Prose([l10n.licensing_final_p]),
                        const SizedBox(height: 40),
                        Text(
                          'ਦੇਗ ਤੇਗ ਫ਼ਤਿਹ',
                          textAlign: TextAlign.center,
                          style: AppType.gurbani.copyWith(
                            color: Palette.gold,
                            fontSize: 20,
                          ),
                        ),
                        if (version != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            l10n.update_version(version),
                            textAlign: TextAlign.center,
                            style: AppType.footnote.copyWith(
                              color: Palette.faint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: AppType.title2),
    );
  }
}

class _Prose extends StatelessWidget {
  const _Prose(this.paragraphs);

  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, p) in paragraphs.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          SelectableText(p, style: AppType.body),
        ],
      ],
    );
  }
}

/// An inset group, iOS Settings style: rows on one surface, hairlines between
/// them indented to the text so they read as one list.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Palette.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Palette.border),
        ),
      ),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 52),
                  child: Divider(height: 1, thickness: 1, color: Palette.border),
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.url});

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.99,
      semanticLabel: label,
      onTap: () => openLink(url),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Palette.gold),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: AppType.body)),
              const Icon(
                CupertinoIcons.arrow_up_right,
                size: 15,
                color: Palette.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit({required this.source, required this.text, required this.url});

  final String source;
  final String text;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.99,
      semanticLabel: source,
      onTap: () => openLink(url),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                CupertinoIcons.heart,
                size: 20,
                color: Palette.gold,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source, style: AppType.headline.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(text, style: AppType.footnote),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
