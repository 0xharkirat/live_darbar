import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/review_prompt_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/core/open_link.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/platform.dart';
import 'package:live_darbar/src/core/share.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/home_screen_widget/widget_install.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/widgets/app_nav_bar.dart';
import 'package:live_darbar/src/views/widgets/history_setting.dart';
import 'package:live_darbar/src/views/widgets/language_switch.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/reminder_setting.dart';
import 'package:live_darbar/src/views/widgets/settings_group.dart';
import 'package:live_darbar/src/views/widgets/update_setting.dart';
import 'package:live_darbar/src/views/widgets/widget_setting.dart';

/// About the app, the person who made it, and whose work it carries.
///
/// One scrolling page instead of three tabs in a dialog. Tabs hid two thirds
/// of the content behind labels nobody tapped, and a dialog has no back
/// gesture; a page has both a title and the edge swipe people already know.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  /// The widest the page runs. The nav bar lines up with it on the web.
  static const maxWidth = 540.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final version = ref.watch(appVersionProvider).value;
    final notifies = ref.watch(reminderPlatformProvider).isSupported;
    final widgets = ref.watch(widgetInstallProvider).isSupported;

    return Scaffold(
      backgroundColor: Palette.background,
      body: CustomScrollView(
        slivers: [
          AppNavBar(title: l10n.about_this_app, contentWidth: maxWidth),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Prose([l10n.about_section_p1, l10n.about_section_p2]),
                        const SizedBox(height: 16),
                        SettingsGroup(
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
                              // At a large text size the switch no longer
                              // fits beside the label, and drops under it.
                              // The group's column centres a child that is
                              // narrower than it, and a Wrap is only as wide
                              // as its runs, so the row takes the full width:
                              // the icon then lines up with the icons under it
                              // and the switch with the toggles, whatever the
                              // length of the label in each language.
                              child: SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runSpacing: 8,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          CupertinoIcons.globe,
                                          size: 20,
                                          color: Palette.gold,
                                        ),
                                        const SizedBox(width: 16),
                                        Flexible(
                                          child: Text(
                                            l10n.language_tooltip,
                                            style: AppType.body,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const LanguageSwitch(),
                                  ],
                                ),
                              ),
                            ),
                            // The daily reminder is a setting like the
                            // language, so it sits beside it, and so does
                            // the history notification that follows its time.
                            // The web cannot notify with the page closed, so
                            // it has neither.
                            if (notifies) ...const [
                              ReminderSetting(),
                              HistorySetting(),
                            ],
                            // The widget is a setting too, and it stays here
                            // after the card on home has gone. The web has no
                            // home screen to put it on.
                            if (widgets) const WidgetSetting(),
                            // The apps offer a new version once, at launch.
                            // This asks again, when the listener wants. On the
                            // web a reload is the update.
                            if (!ref.watch(isWebProvider))
                              const UpdateSetting(),
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
                            // Someone who arrived on the site and wandered
                            // into the app can get back to the site. It opens
                            // in a new tab, so the kirtan keeps playing.
                            if (ref.watch(isWebProvider))
                              _LinkRow(
                                icon: CupertinoIcons.house,
                                label: l10n.about_site,
                                url: kSiteUrl,
                              ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        // Free forever, so the only help asked for is a
                        // share or a rating. No money, no tip jar.
                        _Heading(l10n.support_heading),
                        _Prose([l10n.support_body]),
                        const SizedBox(height: 16),
                        SettingsGroup(
                          children: [
                            _LinkRow.action(
                              icon: CupertinoIcons.share,
                              label: l10n.share_app,
                              onTap: (context) => shareApp(context),
                            ),
                            // The web has no store of its own; its footer on
                            // Home already links both.
                            if (!ref.watch(isWebProvider))
                              _LinkRow.action(
                                icon: CupertinoIcons.star,
                                label: l10n.rate_app,
                                trailing: CupertinoIcons.arrow_up_right,
                                onTap: (_) => ref
                                    .read(reviewPlatformProvider)
                                    .openStoreListing(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        _Heading(l10n.about_me_heading),
                        _Prose([l10n.about_me_p1, l10n.about_me_p2]),
                        const SizedBox(height: 16),
                        SettingsGroup(
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
                              icon: CupertinoIcons
                                  .chevron_left_slash_chevron_right,
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
                        SettingsGroup(
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

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.url})
      : action = null,
        trailing = CupertinoIcons.arrow_up_right;

  /// A row that does something in the app, such as opening the share sheet,
  /// rather than opening a link. [action] gets the row's own context, which
  /// the share sheet points at on an iPad.
  const _LinkRow.action({
    required this.icon,
    required this.label,
    required void Function(BuildContext context) onTap,
    this.trailing = CupertinoIcons.chevron_right,
  })  : action = onTap,
        url = null;

  final IconData icon;
  final String label;
  final String? url;
  final void Function(BuildContext context)? action;
  final IconData trailing;

  void _onTap(BuildContext context) {
    final url = this.url;
    if (url != null) {
      openLink(url);
    } else {
      action?.call(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.99,
      semanticLabel: label,
      onTap: () => _onTap(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Palette.gold),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: AppType.body)),
              Icon(trailing, size: 15, color: Palette.faint),
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
