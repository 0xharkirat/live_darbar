// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_title => 'Live Darbar';

  @override
  String get live_kirtan => 'Live Kirtan';

  @override
  String get mukhwak => 'Mukhwak';

  @override
  String get mukhwak_katha => 'Mukhwak Katha';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get about_tooltip => 'About';

  @override
  String get language_tooltip => 'Change Language';

  @override
  String get download_tooltip => 'Download the app';

  @override
  String get about_section_heading => 'About the App';

  @override
  String get about_section_p1 => 'Live kirtan from Sri Darbar Sahib in Amritsar, wherever you are.';

  @override
  String get about_section_p2 => 'It is free and I make no money from it. That will not change.';

  @override
  String get about_section_contact => 'Send feedback';

  @override
  String get about_me_heading => 'About Me';

  @override
  String get about_me_p1 => 'I am Harkirat, Hark for short. Born in Amritsar, now a software engineer at SSW in Newcastle, Australia.';

  @override
  String get about_me_p2 => 'I have played tabla since year 5, back in Amritsar. These days it is the Newcastle Gurdwara on Saturdays and Sundays.';

  @override
  String get about_me_motto => 'Memento Homo. Remember, you are only a man.';

  @override
  String get about_me_website => 'harksingh.com';

  @override
  String get about_me_tabla_button => 'My tabla videos';

  @override
  String get about_me_github => 'GitHub';

  @override
  String get about_me_linkedin => 'LinkedIn';

  @override
  String get about_me_youtube => 'YouTube';

  @override
  String get about_me_x => 'X';

  @override
  String get about_me_instagram => 'Instagram';

  @override
  String get licensing_heading => 'Licensing Info';

  @override
  String get licensing_audio_source => 'sgpc.net';

  @override
  String get licensing_audio => 'Live kirtan audio, streamed from SGPC. The copyright is theirs.';

  @override
  String get licensing_logo_source => 'Punjab icons created by Freepik - Flaticon';

  @override
  String get licensing_logo => 'App logo, used under Flaticon\'s free licence.';

  @override
  String get licensing_images_source => 'Art of Punjab';

  @override
  String get licensing_images => 'Artwork by Kanwar Singh and his team. The copyright is theirs.';

  @override
  String get licensing_final_p => 'None of this is mine. I have only put it in one place, and I make no money from it.';

  @override
  String get information => 'Information';

  @override
  String get google_play => 'Google Play Store';

  @override
  String get apple_store => 'Apple App Store';

  @override
  String get live => 'Live';

  @override
  String get youtube => 'YouTube Video';

  @override
  String get mukhwak_pdf_title => 'Daily Mukhwak (PDF)';

  @override
  String get go_live => 'Go live';

  @override
  String behind_live(int seconds) {
    return '${seconds}s behind';
  }

  @override
  String get reconnecting => 'Reconnecting...';

  @override
  String get low_quality_stream => 'Low quality stream';

  @override
  String get offline_banner => 'No internet connection';

  @override
  String get offline_banner_detail => 'Playback will resume when you are back online';

  @override
  String get stream_unreachable => 'Can\'t reach the kirtan stream';

  @override
  String get retry => 'Retry';

  @override
  String get mukhwak_load_failed => 'Could not load today\'s Mukhwak';

  @override
  String get yesterdays_recording => 'Yesterday\'s recording';

  @override
  String get mukhwak_from_yesterday => 'Yesterday\'s Mukhwak. Today\'s has not been published yet.';

  @override
  String get playback_error => 'Playback problem';

  @override
  String get stop_tooltip => 'Stop playback';

  @override
  String get update_available => 'A new version is available';

  @override
  String update_version(String version) {
    return 'Version $version';
  }

  @override
  String get update_now => 'Update now';

  @override
  String get update_later => 'Not now';
}
