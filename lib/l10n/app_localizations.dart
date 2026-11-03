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

  /// What a screen reader says for the live play button on the home screen widget
  ///
  /// In en, this message translates to:
  /// **'Play live kirtan'**
  String get play_live_kirtan;

  /// Mukhwak
  ///
  /// In en, this message translates to:
  /// **'Hukamnama'**
  String get mukhwak;

  /// Mukhwak Katha
  ///
  /// In en, this message translates to:
  /// **'Hukamnama Katha'**
  String get mukhwak_katha;

  /// Loading...
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
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
  /// **'Live kirtan from Sri Darbar Sahib, Amritsar, and the daily Hukamnama and Katha.'**
  String get about_section_p1;

  /// States that the app is non-commercial
  ///
  /// In en, this message translates to:
  /// **'The app is free and has no ads.'**
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
  /// **'App logo, used under Flaticon’s free licence.'**
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

  /// Button that reconnects the stream to jump back to the live edge
  ///
  /// In en, this message translates to:
  /// **'Go live'**
  String get go_live;

  /// Shown when live playback is 2 minutes or more behind the broadcast
  ///
  /// In en, this message translates to:
  /// **'{minutes} min behind'**
  String behind_live(int minutes);

  /// Shown while the app is retrying a dropped stream connection
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
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
  /// **'Can’t reach the kirtan stream'**
  String get stream_unreachable;

  /// Button that retries a failed connection immediately
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Chip in the player saying the loaded Mukhwak or Katha is the previous day's, because today's has not been published yet
  ///
  /// In en, this message translates to:
  /// **'Yesterday’s recording'**
  String get yesterdays_recording;

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

  /// Second line on the row that is currently sounding
  ///
  /// In en, this message translates to:
  /// **'Playing now'**
  String get now_playing;

  /// Second line on the live kirtan row when it is not playing
  ///
  /// In en, this message translates to:
  /// **'Live from Sri Darbar Sahib'**
  String get live_from_darbar;

  /// Second line when the current day's audio is what will play
  ///
  /// In en, this message translates to:
  /// **'Today’s recording'**
  String get todays_recording;

  /// Second line on the row that opens the Mukhwak PDF
  ///
  /// In en, this message translates to:
  /// **'Read the words'**
  String get read_the_words;

  /// Row that opens the information screens
  ///
  /// In en, this message translates to:
  /// **'About this app'**
  String get about_this_app;

  /// Section label above the daily Hukamnama and Katha
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Where the live kirtan comes from, under its title
  ///
  /// In en, this message translates to:
  /// **'Sri Harmandir Sahib, Amritsar'**
  String get live_location;

  /// Second line under the Katha tile
  ///
  /// In en, this message translates to:
  /// **'The meaning of today’s Hukamnama'**
  String get katha_subtitle;

  /// Card that opens the Hukamnama text
  ///
  /// In en, this message translates to:
  /// **'Read today’s Hukamnama'**
  String get read_hukamnama;

  /// Second line of the read card
  ///
  /// In en, this message translates to:
  /// **'As published by SGPC'**
  String get read_hukamnama_detail;

  /// Short button in the player that opens the Hukamnama text
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// Screen reader label for the skip back button
  ///
  /// In en, this message translates to:
  /// **'Back 15 seconds'**
  String get skip_back;

  /// Screen reader label for the skip forward button
  ///
  /// In en, this message translates to:
  /// **'Forward 15 seconds'**
  String get skip_forward;

  /// Link on the About screen
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacy_policy;

  /// Link on the About screen, web only, to the Live Darbar site. A domain name, so it is the same in every language
  ///
  /// In en, this message translates to:
  /// **'darbar.live'**
  String get about_site;

  /// Screen reader label for the play button
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// Screen reader label for the pause button
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Short name for the Hukamnama Katha, in the player source switcher
  ///
  /// In en, this message translates to:
  /// **'Katha'**
  String get katha;

  /// Button and sheet title for the stream quality setting
  ///
  /// In en, this message translates to:
  /// **'Sound quality'**
  String get quality;

  /// Quality option: adapts to the connection
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get quality_automatic;

  /// Quality option: always the 96 kbps stream
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get quality_high;

  /// Quality option: always the 28 kbps stream
  ///
  /// In en, this message translates to:
  /// **'Data saver'**
  String get quality_data_saver;

  /// Explains the automatic quality option
  ///
  /// In en, this message translates to:
  /// **'High quality, and less data when the connection is weak'**
  String get quality_automatic_detail;

  /// Explains the high quality option
  ///
  /// In en, this message translates to:
  /// **'96 kbps, about 43 MB an hour'**
  String get quality_high_detail;

  /// Explains the data saver option
  ///
  /// In en, this message translates to:
  /// **'28 kbps, about 13 MB an hour'**
  String get quality_data_saver_detail;

  /// Note under the quality options
  ///
  /// In en, this message translates to:
  /// **'Applies to live kirtan. Hukamnama and Katha recordings are always the same size.'**
  String get quality_note;

  /// Button in the Hukamnama reader that plays the recording
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// Button in the Hukamnama reader that opens SGPC's PDF
  ///
  /// In en, this message translates to:
  /// **'SGPC PDF'**
  String get sgpc_pdf;

  /// The page of Sri Guru Granth Sahib Ji the Hukamnama is from. The number arrives already written: Gurmukhi digits in Punjabi, Latin digits in English
  ///
  /// In en, this message translates to:
  /// **'Ang {ang}'**
  String hukamnama_ang(String ang);

  /// Credit under the Hukamnama text
  ///
  /// In en, this message translates to:
  /// **'Text and meaning from {source}'**
  String text_source(String source);

  /// Screen reader label for the text size down button
  ///
  /// In en, this message translates to:
  /// **'Smaller text'**
  String get smaller_text;

  /// Screen reader label for the text size up button
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get larger_text;

  /// Shown when the Hukamnama text fails and nothing is stored
  ///
  /// In en, this message translates to:
  /// **'Today’s Hukamnama text could not be loaded'**
  String get hukamnama_unavailable;

  /// Home card label while today's Hukamnama is not out; date like 1 November
  ///
  /// In en, this message translates to:
  /// **'Hukamnama of {date}'**
  String hukamnama_of(String date);

  /// Note in the reader while showing an older Hukamnama
  ///
  /// In en, this message translates to:
  /// **'Today’s Hukamnama is not out yet. This is the one from {date}.'**
  String hukamnama_not_out(String date);

  /// Heading above the explanation of the Hukamnama
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get meaning;

  /// Web only: link to SGPC's site, shown beside Retry when the Hukamnama text could not be loaded
  ///
  /// In en, this message translates to:
  /// **'Read it on SGPC’s website'**
  String get open_on_sgpc;

  /// What a screen reader says for the big gold button on the home screen widget. The state is idle, loading, playing or paused, and it describes live kirtan
  ///
  /// In en, this message translates to:
  /// **'{state, select, loading{Live kirtan, starting. Double tap to cancel.} playing{Live kirtan, playing. Double tap to stop.} paused{Live kirtan, paused. Double tap to play.} other{Play live kirtan}}'**
  String widget_live_control(String state);

  /// What a screen reader says for the Hukamnama button on the home screen widget. The state is idle, loading, playing or paused, and it describes the Hukamnama recording
  ///
  /// In en, this message translates to:
  /// **'{state, select, loading{Hukamnama, starting. Double tap to cancel.} playing{Hukamnama, playing. Double tap to pause.} paused{Hukamnama, paused. Double tap to resume.} other{Play today’s Hukamnama}}'**
  String widget_hukamnama_control(String state);

  /// Label of the switch on the About screen that turns the daily Hukamnama reminder on or off
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get reminder_setting;

  /// Label of the row that shows the time of the daily reminder, and the title of the sheet where the listener picks that time
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminder_time;

  /// What a screen reader says for the daily reminder switch when the reminder is on
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get reminder_on;

  /// What a screen reader says for the daily reminder switch when the reminder is off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get reminder_off;

  /// Button that saves the chosen reminder time, or closes a message, and then closes the sheet
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reminder_done;

  /// Message shown when the phone does not let the app show notifications, so the daily reminder cannot appear
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Live Darbar. Turn them on in your phone’s settings.'**
  String get reminder_blocked_hint;

  /// Message shown when the phone could not set the daily reminder for a reason that is not a missing permission
  ///
  /// In en, this message translates to:
  /// **'The reminder did not start. Try again.'**
  String get reminder_failed_hint;

  /// Title of the sheet that asks, once, if the listener wants a daily reminder to read the Hukamnama
  ///
  /// In en, this message translates to:
  /// **'Daily Hukamnama reminder'**
  String get reminder_prompt_title;

  /// Body of the reminder sheet. It names the default time and says where to change it. The time is already written in the listener's style, for example 7:00 AM
  ///
  /// In en, this message translates to:
  /// **'Get a reminder each day at {time} to read the Hukamnama. You can change this later in About.'**
  String reminder_prompt_body(String time);

  /// Gold button on the reminder sheet that turns the daily reminder on
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get reminder_prompt_yes;

  /// Quiet button on the reminder sheet that closes it. The app does not ask again
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get reminder_prompt_no;

  /// Title of the daily reminder notification
  ///
  /// In en, this message translates to:
  /// **'Today’s Hukamnama'**
  String get reminder_notification_title;

  /// Body of the daily reminder notification. A tap on it opens the Hukamnama reader
  ///
  /// In en, this message translates to:
  /// **'Read the Hukamnama from Sri Darbar Sahib.'**
  String get reminder_notification_body;

  /// Name of the Android notification channel for the daily reminder, shown in the phone's notification settings
  ///
  /// In en, this message translates to:
  /// **'Daily Hukamnama'**
  String get reminder_channel_name;

  /// Description of the Android notification channel for the daily reminder, shown in the phone's notification settings
  ///
  /// In en, this message translates to:
  /// **'A reminder each day to read the Hukamnama.'**
  String get reminder_channel_description;
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
