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

  /// Label of the About switch that turns the daily Hukamnama reminder on or off, and what a screen reader says for the bell in the top bar of the Hukamnama screen, which opens the reminder's sheet
  ///
  /// In en, this message translates to:
  /// **'Daily Hukamnama reminder'**
  String get reminder_setting;

  /// Label of the row that shows the time of the daily reminder, and the title of the sheet where the listener picks that time
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminder_time;

  /// The time of the reminder when it follows Amritsar: its time at Sri Harmandir Sahib, then the same moment on the listener’s own clock. Both times are already written for the listener, for example 7:00 AM in Amritsar, 12:30 PM here
  ///
  /// In en, this message translates to:
  /// **'{amritsar} in Amritsar, {here} here'**
  String reminder_time_amritsar(String amritsar, String here);

  /// The time of the reminder when it follows Amritsar and the listener’s own clock shows the same time, for example in India. The time is already written for the listener, for example 7:00 AM
  ///
  /// In en, this message translates to:
  /// **'{amritsar} in Amritsar'**
  String reminder_time_amritsar_only(String amritsar);

  /// Line under the title of the sheet where the listener picks the reminder time, while the reminder follows Amritsar. It says what the time is now, and that a time the listener picks uses their own clock. The time is already written for the listener, for example 7:00 AM in Amritsar, 12:30 PM here
  ///
  /// In en, this message translates to:
  /// **'Now: {when}. A time you pick is on your own clock.'**
  String reminder_time_note(String when);

  /// Quiet button on the sheet where the listener picks the reminder time, shown when the time is on the listener’s own clock. It goes back to the default, 7:00 in Amritsar, and closes the sheet
  ///
  /// In en, this message translates to:
  /// **'Use Amritsar time'**
  String get reminder_use_amritsar;

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

  /// Body of the reminder sheet, the first time the listener opens the Hukamnama screen. It says when the reminder comes and where to change it. The time is already written for the listener, for example 7:00 AM in Amritsar, 12:30 PM here
  ///
  /// In en, this message translates to:
  /// **'Read the Hukamnama each day. We remind you at {time}. Change it any time with the bell.'**
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

  /// Body of the reminder sheet when the listener opens it with the bell and the reminder is already on. The time is already written for the listener, for example 7:00 AM in Amritsar, 12:30 PM here
  ///
  /// In en, this message translates to:
  /// **'The reminder is on. It comes each day at {time}.'**
  String reminder_on_body(String time);

  /// Gold button on the reminder sheet, when the reminder is on. It closes the sheet and opens the sheet where the listener picks the time
  ///
  /// In en, this message translates to:
  /// **'Change time'**
  String get reminder_change_time;

  /// Quiet button on the reminder sheet, when the reminder is on. It turns the daily reminder off and closes the sheet
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get reminder_turn_off;

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

  /// Name of the feature that shows the days of Sikh history from SGPC's calendar. It is the title of the Sikh history screen, the title of the notification, the name of its Android notification channel, and what a screen reader says before the event on the home screen
  ///
  /// In en, this message translates to:
  /// **'Today in Sikh history'**
  String get history_title;

  /// Title of the Sikh history screen, which lists the days of Sikh history in the Nanakshahi year. It is shorter than history_title, so the large title fits on one line
  ///
  /// In en, this message translates to:
  /// **'Sikh history'**
  String get history_screen_title;

  /// Label of the switch for the Today in Sikh history notification, on the About screen and on the Sikh history screen. It names the notification. history_title names the feature
  ///
  /// In en, this message translates to:
  /// **'Today in Sikh history notification'**
  String get history_setting;

  /// Line under the About switch for the Today in Sikh history notification. It says when the notice comes: on days that have an event, at the time of the daily reminder
  ///
  /// In en, this message translates to:
  /// **'A notice comes at the reminder time on days with an event.'**
  String get history_setting_detail;

  /// Message shown when the phone could not set the Today in Sikh history notification for a reason that is not a missing permission
  ///
  /// In en, this message translates to:
  /// **'Today in Sikh history did not start. Try again.'**
  String get history_failed_hint;

  /// Line under the title of the Sikh history screen. It names the Nanakshahi year that the screen lists, and says where the days come from. The year is a number, written in Gurmukhi digits in Punjabi
  ///
  /// In en, this message translates to:
  /// **'Nanakshahi {year}, from the SGPC calendar.'**
  String history_screen_intro(String year);

  /// Small label on the row of today's event, on the Sikh history screen. It also marks the day for a screen reader
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get history_today;

  /// Small label on the Home line for Sikh history, on a day with no event. It leads the next event that SGPC's calendar lists, with its date: Next · 8 Nov. English writes it in capitals
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get history_next;

  /// What a screen reader says for the Home line for Sikh history on a day with no event. It names the date of the next event, then its title. The date is already written out, for example 8 November
  ///
  /// In en, this message translates to:
  /// **'Next in Sikh history, {date}: {title}'**
  String history_next_semantics(String date, String title);

  /// Message on the Sikh history screen when no calendar file covers the year
  ///
  /// In en, this message translates to:
  /// **'No days of Sikh history are listed for this year.'**
  String get history_empty;

  /// What a screen reader says on the home screen line for Sikh history, after the first event, when the day has more events. The line opens the Sikh history screen
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{and 1 more} other{and {count} more}}'**
  String history_and_more(int count);

  /// Description of the Android notification channel for Today in Sikh history, shown in the phone's notification settings
  ///
  /// In en, this message translates to:
  /// **'A quiet notice on days with an event in Sikh history.'**
  String get history_channel_description;

  /// Words on the small card on the home screen that offers the home screen widget, once. It says what the widget gives: today's Hukamnama on the phone's home screen
  ///
  /// In en, this message translates to:
  /// **'Today’s Hukamnama on your home screen'**
  String get widget_card_title;

  /// Gold button on the home screen card. On Android it asks the phone to put the widget on the home screen. On iPhone it opens the steps
  ///
  /// In en, this message translates to:
  /// **'Add widget'**
  String get widget_card_add;

  /// Quiet button on the home screen card that hides the card for good. The app does not offer the widget on the home screen again, but About keeps a row for it
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get widget_card_dismiss;

  /// Label of the About row that adds the home screen widget
  ///
  /// In en, this message translates to:
  /// **'Home screen widget'**
  String get widget_setting_title;

  /// Line under the label of the About row for the home screen widget. It says what the widget does: its buttons play the Hukamnama and Live Kirtan with the app closed
  ///
  /// In en, this message translates to:
  /// **'Play without opening the app.'**
  String get widget_setting_detail;

  /// Short word at the end of the About row for the home screen widget, while the widget is not on the home screen. A tap on the row adds it
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get widget_setting_add;

  /// Word at the end of the About row for the home screen widget when the widget is on the home screen. A screen reader also says it as the value of the row
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get widget_setting_added;

  /// Title of the sheet with the steps to add the home screen widget by hand. iPhone has no call that adds a widget, and some Android launchers cannot pin one
  ///
  /// In en, this message translates to:
  /// **'Add the widget'**
  String get widget_steps_title;

  /// Step 1 of adding the widget, on iPhone and Android: press and hold the home screen until the phone starts to edit it
  ///
  /// In en, this message translates to:
  /// **'Press and hold an empty part of the home screen.'**
  String get widget_steps_press_hold;

  /// Step 2 of adding the widget on iPhone. Edit and Add Widget are the names that iOS shows in English, so they stay in English
  ///
  /// In en, this message translates to:
  /// **'Tap Edit, then Add Widget.'**
  String get widget_steps_iphone_add;

  /// Step 3 of adding the widget on iPhone. Live Darbar is the app's name on the home screen, in English. The widget has 1 size, medium
  ///
  /// In en, this message translates to:
  /// **'Search for Live Darbar, then add the medium size.'**
  String get widget_steps_iphone_find;

  /// Step 2 of adding the widget on Android, for a launcher that cannot pin it from the app. Widgets is the name of the launcher's menu
  ///
  /// In en, this message translates to:
  /// **'Tap Widgets.'**
  String get widget_steps_android_widgets;

  /// Step 3 of adding the widget on Android, for a launcher that cannot pin it from the app
  ///
  /// In en, this message translates to:
  /// **'Find Live Darbar, then drag its widget to the home screen.'**
  String get widget_steps_android_find;

  /// Button that closes the sheet with the steps to add the home screen widget
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get widget_steps_done;

  /// Title of the screen that replaces the app when start-up fails. It shows in English and Punjabi together
  ///
  /// In en, this message translates to:
  /// **'Live Darbar did not start.'**
  String get launch_failed_title;

  /// Line under the title of the start-up failure screen. Retry is the name of the button on that screen
  ///
  /// In en, this message translates to:
  /// **'Tap Retry. If it fails again, close the app and open it again.'**
  String get launch_failed_body;

  /// Small box that replaces a part of a screen that failed to build. It shows in English and Punjabi together, because the part that failed may be the language setting
  ///
  /// In en, this message translates to:
  /// **'This part did not load'**
  String get error_view_title;

  /// Title of the sheet that shows once, the first time the app opens after an update. {version} is the release, for example 3.1
  ///
  /// In en, this message translates to:
  /// **'What’s new in {version}'**
  String whats_new_title(String version);

  /// Button that closes the sheet of what is new
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get whats_new_done;

  /// Title of the update sheet when the installed version is below the least version that still works. The sheet cannot be dismissed
  ///
  /// In en, this message translates to:
  /// **'Please update'**
  String get update_required_title;

  /// Line under the title of the update sheet that cannot be dismissed
  ///
  /// In en, this message translates to:
  /// **'This version is too old to work well. Update it from the store to go on.'**
  String get update_required_body;
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
