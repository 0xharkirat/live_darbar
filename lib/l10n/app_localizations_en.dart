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
  String get play_live_kirtan => 'Play live kirtan';

  @override
  String get mukhwak => 'Hukamnama';

  @override
  String get mukhwak_katha => 'Hukamnama Katha';

  @override
  String get loading => 'Loading…';

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
  String get about_section_p1 => 'Live kirtan from Sri Darbar Sahib, Amritsar, and the daily Hukamnama and Katha.';

  @override
  String get about_section_p2 => 'The app is free and has no ads.';

  @override
  String get about_section_contact => 'Send feedback';

  @override
  String get about_me_heading => 'About Me';

  @override
  String get about_me_p1 => 'I am Harkirat, Hark for short. Born in Amritsar, now a software engineer at SSW in Newcastle, Australia.';

  @override
  String get about_me_p2 => 'I have played tabla since year 5, back in Amritsar. These days it is the Newcastle Gurdwara on Saturdays and Sundays.';

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
  String get licensing_logo => 'App logo, used under Flaticon’s free licence.';

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
  String get go_live => 'Go live';

  @override
  String behind_live(int minutes) {
    return '$minutes min behind';
  }

  @override
  String get reconnecting => 'Reconnecting…';

  @override
  String get low_quality_stream => 'Low quality stream';

  @override
  String get offline_banner => 'No internet connection';

  @override
  String get offline_banner_detail => 'Playback will resume when you are back online';

  @override
  String get stream_unreachable => 'Can’t reach the kirtan stream';

  @override
  String get retry => 'Retry';

  @override
  String get yesterdays_recording => 'Yesterday’s recording';

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
  String get update_check_title => 'Check for updates';

  @override
  String update_check_latest(String version) {
    return 'You have the newest version, $version.';
  }

  @override
  String get update_check_failed => 'Could not check. Try again when you are online.';

  @override
  String get update_now => 'Update now';

  @override
  String get update_later => 'Not now';

  @override
  String get now_playing => 'Playing now';

  @override
  String get live_from_darbar => 'Live from Sri Darbar Sahib';

  @override
  String get todays_recording => 'Today’s recording';

  @override
  String get read_the_words => 'Read the words';

  @override
  String get about_this_app => 'About this app';

  @override
  String get today => 'Today';

  @override
  String get live_location => 'Sri Harmandir Sahib, Amritsar';

  @override
  String get katha_subtitle => 'The meaning of today’s Hukamnama';

  @override
  String get read_hukamnama => 'Read today’s Hukamnama';

  @override
  String get read_hukamnama_detail => 'As published by SGPC';

  @override
  String get read => 'Read';

  @override
  String get skip_back => 'Back 15 seconds';

  @override
  String get skip_forward => 'Forward 15 seconds';

  @override
  String get privacy_policy => 'Privacy policy';

  @override
  String get about_site => 'darbar.live';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get katha => 'Katha';

  @override
  String get quality => 'Sound quality';

  @override
  String get quality_automatic => 'Automatic';

  @override
  String get quality_high => 'High';

  @override
  String get quality_data_saver => 'Data saver';

  @override
  String get quality_automatic_detail => 'High quality, and less data when the connection is weak';

  @override
  String get quality_high_detail => '96 kbps, about 43 MB an hour';

  @override
  String get quality_data_saver_detail => '28 kbps, about 13 MB an hour';

  @override
  String get quality_note => 'Applies to live kirtan. Hukamnama and Katha recordings are always the same size.';

  @override
  String get listen => 'Listen';

  @override
  String get sgpc_pdf => 'SGPC PDF';

  @override
  String hukamnama_ang(String ang) {
    return 'Ang $ang';
  }

  @override
  String hukamnama_lines_credit(String meanings, String pauses, String source) {
    return 'Line meanings by $meanings. Pauses by $pauses. From $source.';
  }

  @override
  String hukamnama_source(String source) {
    return 'Hukamnama from $source';
  }

  @override
  String text_source(String source) {
    return 'Text and meaning from $source';
  }

  @override
  String get smaller_text => 'Smaller text';

  @override
  String get larger_text => 'Larger text';

  @override
  String get hukamnama_unavailable => 'Today’s Hukamnama text could not be loaded';

  @override
  String hukamnama_of(String date) {
    return 'Hukamnama of $date';
  }

  @override
  String hukamnama_not_out(String date) {
    return 'Today’s Hukamnama is not out yet. This is the one from $date.';
  }

  @override
  String get hukamnama_pick_day => 'Choose another day';

  @override
  String get archive_title => 'Earlier Hukamnama';

  @override
  String get archive_body => 'Pick a day to read its Hukamnama.';

  @override
  String archive_body_web(String days) {
    return 'Pick a day from the last $days days.';
  }

  @override
  String get archive_open => 'Open';

  @override
  String get archive_yesterday => 'Yesterday';

  @override
  String get archive_none => 'There is no Hukamnama for this day.';

  @override
  String get archive_failed => 'This Hukamnama could not be loaded';

  @override
  String get archive_other_day => 'Choose another day';

  @override
  String get meaning => 'Meaning';

  @override
  String get sangrand_title => 'Sangrand Hukamnama';

  @override
  String get barah_maha => 'Barah Maha';

  @override
  String sangrand_row(String month) {
    return 'Sangrand · $month';
  }

  @override
  String sangrand_row_today(String month) {
    return 'Today is Sangrand · $month';
  }

  @override
  String get reader_options => 'Reading options';

  @override
  String get reader_text_size => 'Text size';

  @override
  String get reader_meanings => 'Meanings';

  @override
  String get open_on_sgpc => 'Read it on SGPC’s website';

  @override
  String widget_live_control(String state) {
    String _temp0 = intl.Intl.selectLogic(
      state,
      {
        'loading': 'Live kirtan, starting. Double tap to cancel.',
        'playing': 'Live kirtan, playing. Double tap to stop.',
        'paused': 'Live kirtan, paused. Double tap to play.',
        'other': 'Play live kirtan',
      },
    );
    return '$_temp0';
  }

  @override
  String widget_hukamnama_control(String state) {
    String _temp0 = intl.Intl.selectLogic(
      state,
      {
        'loading': 'Hukamnama, starting. Double tap to cancel.',
        'playing': 'Hukamnama, playing. Double tap to pause.',
        'paused': 'Hukamnama, paused. Double tap to resume.',
        'other': 'Play today’s Hukamnama',
      },
    );
    return '$_temp0';
  }

  @override
  String get reminder_setting => 'Daily Hukamnama reminder';

  @override
  String get reminder_time => 'Reminder time';

  @override
  String reminder_time_amritsar(String amritsar, String here) {
    return '$amritsar in Amritsar, $here here';
  }

  @override
  String reminder_wheel_amritsar(String here, String amritsar) {
    return '$here here is $amritsar in Amritsar';
  }

  @override
  String reminder_time_amritsar_only(String amritsar) {
    return '$amritsar in Amritsar';
  }

  @override
  String reminder_time_note(String when) {
    return 'Now: $when. A time you pick is on your own clock.';
  }

  @override
  String get reminder_use_amritsar => 'Use Amritsar time';

  @override
  String get reminder_on => 'On';

  @override
  String get reminder_off => 'Off';

  @override
  String get reminder_done => 'Done';

  @override
  String get reminder_blocked_hint => 'Notifications are off for Live Darbar. Turn them on in your phone’s settings.';

  @override
  String get reminder_failed_hint => 'The reminder did not start. Try again.';

  @override
  String get reminder_prompt_title => 'Daily Hukamnama reminder';

  @override
  String reminder_prompt_body(String time) {
    return 'Read the Hukamnama each day. We remind you at $time. Change it any time with the bell.';
  }

  @override
  String get reminder_prompt_yes => 'Remind me';

  @override
  String get reminder_prompt_no => 'Not now';

  @override
  String reminder_on_body(String time) {
    return 'The reminder is on. It comes each day at $time.';
  }

  @override
  String get reminder_change_time => 'Change time';

  @override
  String get reminder_turn_off => 'Turn off';

  @override
  String get reminder_notification_title => 'Today’s Hukamnama';

  @override
  String get reminder_notification_body => 'Read the Hukamnama from Sri Darbar Sahib.';

  @override
  String get reminder_channel_name => 'Daily Hukamnama';

  @override
  String get reminder_channel_description => 'A reminder each day to read the Hukamnama.';

  @override
  String get history_title => 'Today in Sikh history';

  @override
  String get history_screen_title => 'Sikh history';

  @override
  String get history_setting => 'Today in Sikh history notification';

  @override
  String get history_setting_detail => 'A notice comes at the reminder time on days with an event.';

  @override
  String get history_failed_hint => 'Today in Sikh history did not start. Try again.';

  @override
  String history_screen_intro(String year) {
    return 'Nanakshahi $year, from the SGPC calendar.';
  }

  @override
  String get history_today => 'Today';

  @override
  String get history_next => 'Next';

  @override
  String history_next_semantics(String date, String title) {
    return 'Next in Sikh history, $date: $title';
  }

  @override
  String get history_empty => 'No days of Sikh history are listed for this year.';

  @override
  String get history_search_hint => 'Search Sikh history';

  @override
  String get history_search_clear => 'Clear search';

  @override
  String history_search_empty(String query) {
    return 'Nothing found for “$query”. Try fewer letters.';
  }

  @override
  String history_search_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String history_and_more(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String get history_channel_description => 'A quiet notice on days with an event in Sikh history.';

  @override
  String get widget_card_title => 'Today’s Hukamnama on your home screen';

  @override
  String get widget_card_add => 'Add widget';

  @override
  String get widget_card_dismiss => 'Not now';

  @override
  String get widget_setting_title => 'Home screen widget';

  @override
  String get widget_setting_detail => 'Play without opening the app.';

  @override
  String get widget_setting_add => 'Add';

  @override
  String get widget_setting_added => 'Added';

  @override
  String get widget_steps_title => 'Add the widget';

  @override
  String get widget_steps_press_hold => 'Press and hold an empty part of the home screen.';

  @override
  String get widget_steps_iphone_add => 'Tap Edit, then Add Widget.';

  @override
  String get widget_steps_iphone_find => 'Search for Live Darbar, then add the medium size.';

  @override
  String get widget_steps_android_widgets => 'Tap Widgets.';

  @override
  String get widget_steps_android_find => 'Find Live Darbar, then drag its widget to the home screen.';

  @override
  String get widget_steps_done => 'Done';

  @override
  String get launch_failed_title => 'Live Darbar did not start.';

  @override
  String get launch_failed_body => 'Tap Retry. If it fails again, close the app and open it again.';

  @override
  String get error_view_title => 'This part did not load';

  @override
  String whats_new_title(String version) {
    return 'What’s new in $version';
  }

  @override
  String get whats_new_done => 'Got it';

  @override
  String get update_required_title => 'Please update';

  @override
  String get update_required_body => 'This version is too old to work well. Update it from the store to go on.';

  @override
  String get support_heading => 'Help others find it';

  @override
  String get support_body => 'Live Darbar is free and will stay free, with no ads. Sharing it or rating it helps more of the sangat find it.';

  @override
  String get share_app => 'Share Live Darbar';

  @override
  String get share_app_message => 'Live kirtan from Sri Darbar Sahib, Amritsar, and the daily Hukamnama and Katha. Free, with no ads.';

  @override
  String get rate_app => 'Rate Live Darbar';

  @override
  String get share => 'Share';

  @override
  String get share_hukamnama => 'Share this Hukamnama';

  @override
  String share_hukamnama_title(String date) {
    return 'Hukamnama from Sri Darbar Sahib, $date';
  }

  @override
  String get share_hukamnama_footer => 'Read it all and listen:';

  @override
  String get share_hukamnama_footer_day => 'Read it all:';

  @override
  String get link_copied => 'Copied. Paste it to share.';

  @override
  String get youtube_live => 'Watch live on YouTube';

  @override
  String get youtube_live_semantics => 'Watch live video from Sri Harmandir Sahib on YouTube. Opens the YouTube app.';

  @override
  String get scrubber_label => 'Playback position';

  @override
  String scrubber_value(String elapsed, String total) {
    return '$elapsed of $total';
  }
}
