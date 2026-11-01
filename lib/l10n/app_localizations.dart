import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pa')
  ];

  /// Title of the app
  ///
  /// In en, this message translates to:
  /// **'Live Darbar'**
  String get app_title;

  /// Live Kirtan
  ///
  /// In en, this message translates to:
  /// **'Live Kirtan'**
  String get live_kirtan;

  /// Mukhwak
  ///
  /// In en, this message translates to:
  /// **'Mukhwak'**
  String get mukhwak;

  /// Mukhwak Katha
  ///
  /// In en, this message translates to:
  /// **'Mukhwak Katha'**
  String get mukhwak_katha;

  /// Loading...
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// About Tooltip
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about_tooltip;

  /// Change Language Tooltip
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get language_tooltip;

  /// Download Tooltip
  ///
  /// In en, this message translates to:
  /// **'Download the app'**
  String get download_tooltip;

  /// About the App Section Heading
  ///
  /// In en, this message translates to:
  /// **'About the App'**
  String get about_section_heading;

  /// One line saying what the app does
  ///
  /// In en, this message translates to:
  /// **'Live kirtan from Sri Darbar Sahib in Amritsar, wherever you are.'**
  String get about_section_p1;

  /// States that the app is non-commercial
  ///
  /// In en, this message translates to:
  /// **'It is free and I make no money from it. That will not change.'**
  String get about_section_p2;

  /// Button that opens the feedback form
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get about_section_contact;

  /// About Me Section Heading
  ///
  /// In en, this message translates to:
  /// **'About Me'**
  String get about_me_heading;

  /// Who the author is
  ///
  /// In en, this message translates to:
  /// **'I am Harkirat, Hark for short. Born in Amritsar, now a software engineer at SSW in Newcastle, Australia.'**
  String get about_me_p1;

  /// The author's connection to kirtan
  ///
  /// In en, this message translates to:
  /// **'I have played tabla since year 5, back in Amritsar. These days it is the Newcastle Gurdwara on Saturdays and Sundays.'**
  String get about_me_p2;

  /// The author's motto, carried over from harksingh.com. Memento Homo is Latin and stays untranslated
  ///
  /// In en, this message translates to:
  /// **'Memento Homo. Remember, you are only a man.'**
  String get about_me_motto;

  /// Link to the author's website. A domain name, so it is the same in every language
  ///
  /// In en, this message translates to:
  /// **'harksingh.com'**
  String get about_me_website;

  /// Link to a YouTube playlist of the author playing tabla
  ///
  /// In en, this message translates to:
  /// **'My tabla videos'**
  String get about_me_tabla_button;

  /// Link to the author's GitHub. A brand name, so it is the same in every language
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get about_me_github;

  /// Link to the author's LinkedIn. A brand name, so it is the same in every language
  ///
  /// In en, this message translates to:
  /// **'LinkedIn'**
  String get about_me_linkedin;

  /// Link to the author's YouTube channel. A brand name, so it is the same in every language
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get about_me_youtube;

  /// Link to the author's X profile. A brand name, so it is the same in every language
  ///
  /// In en, this message translates to:
  /// **'X'**
  String get about_me_x;

  /// Link to the author's Instagram. A brand name, so it is the same in every language
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get about_me_instagram;

  /// Licensing Information Section Heading
  ///
  /// In en, this message translates to:
  /// **'Licensing Info'**
  String get licensing_heading;

  /// Link text for the audio attribution. A domain name, so it is the same in every language
  ///
  /// In en, this message translates to:
  /// **'sgpc.net'**
  String get licensing_audio_source;

  /// Attribution for the audio stream
  ///
  /// In en, this message translates to:
  /// **'Live kirtan audio, streamed from SGPC. The copyright is theirs.'**
  String get licensing_audio;

  /// Link text for the logo attribution. Flaticon's free licence requires this exact credit line, so leave it in English
  ///
  /// In en, this message translates to:
  /// **'Punjab icons created by Freepik - Flaticon'**
  String get licensing_logo_source;

  /// Attribution for the app logo
  ///
  /// In en, this message translates to:
  /// **'App logo, used under Flaticon\'s free licence.'**
  String get licensing_logo;

  /// Link text for the artwork attribution. The name of a studio, so it is the same in every language
  ///
  /// In en, this message translates to:
  /// **'Art of Punjab'**
  String get licensing_images_source;

  /// Attribution for the artwork used in the app
  ///
  /// In en, this message translates to:
  /// **'Artwork by Kanwar Singh and his team. The copyright is theirs.'**
  String get licensing_images;

  /// Closing line disclaiming ownership and repeating that the app is non-commercial
  ///
  /// In en, this message translates to:
  /// **'None of this is mine. I have only put it in one place, and I make no money from it.'**
  String get licensing_final_p;

  /// Information
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// Google Play Store
  ///
  /// In en, this message translates to:
  /// **'Google Play Store'**
  String get google_play;

  /// Apple App Store
  ///
  /// In en, this message translates to:
  /// **'Apple App Store'**
  String get apple_store;

  /// Live
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// Youtube video
  ///
  /// In en, this message translates to:
  /// **'YouTube Video'**
  String get youtube;

  /// Title for the Daily Mukhwak PDF screen
  ///
  /// In en, this message translates to:
  /// **'Daily Mukhwak (PDF)'**
  String get mukhwak_pdf_title;

  /// Button that reconnects the stream to jump back to the live edge
  ///
  /// In en, this message translates to:
  /// **'Go live'**
  String get go_live;

  /// How far the playhead trails the live broadcast, shown after a long pause
  ///
  /// In en, this message translates to:
  /// **'{seconds}s behind'**
  String behind_live(int seconds);

  /// Shown while the app is retrying a dropped stream connection
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get reconnecting;

  /// Shown when playback has fallen back to the 28 kbps tier
  ///
  /// In en, this message translates to:
  /// **'Low quality stream'**
  String get low_quality_stream;

  /// Banner shown while the device has no network interface at all
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get offline_banner;

  /// Second line of the offline banner, telling the user they need do nothing
  ///
  /// In en, this message translates to:
  /// **'Playback will resume when you are back online'**
  String get offline_banner_detail;

  /// Shown when the device is online but the SGPC server cannot be reached
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the kirtan stream'**
  String get stream_unreachable;

  /// Button that retries a failed connection immediately
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Replaces a raw exception when the Mukhwak PDF fails to load
  ///
  /// In en, this message translates to:
  /// **'Could not load today\'s Mukhwak'**
  String get mukhwak_load_failed;

  /// Chip in the player saying the loaded Mukhwak or Katha is the previous day's, because today's has not been published yet
  ///
  /// In en, this message translates to:
  /// **'Yesterday\'s recording'**
  String get yesterdays_recording;

  /// Banner above the PDF viewer when the cached document is the previous day's
  ///
  /// In en, this message translates to:
  /// **'Yesterday\'s Mukhwak. Today\'s has not been published yet.'**
  String get mukhwak_from_yesterday;

  /// Replaces a raw exception in the player when progress cannot be read
  ///
  /// In en, this message translates to:
  /// **'Playback problem'**
  String get playback_error;

  /// App bar button that stops playback and dismisses the media notification
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get stop_tooltip;

  /// Heading of the update sheet
  ///
  /// In en, this message translates to:
  /// **'A new version is available'**
  String get update_available;

  /// Subtitle naming the new version number
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String update_version(String version);

  /// Primary button that opens the app store listing
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get update_now;

  /// Secondary button that dismisses the update sheet for this release
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get update_later;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'pa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'pa': return AppLocalizationsPa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
