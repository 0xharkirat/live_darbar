# Live Darbar

<p align="center">
  <img src="https://raw.githubusercontent.com/0xharkirat/live_darbar/refs/heads/main/assets/images/splash_logo.png" width="200" />
</p>

A simple yet powerful & intelligent mobile app for live audio & video broadcast from _**[Golden Temple](https://en.wikipedia.org/wiki/Golden_Temple)**_, _**[Amritsar](https://en.wikipedia.org/wiki/Amritsar)**_. Both  [_**Android**_] (Due to change in play store policy about inactivity, they have deleted my developer account; download apk instead)  &  [_**iOS**_](https://apps.apple.com/app/id6449766130)  apps are fully published on their respective app stores.




## App Screenshots
![demo](docs/screenshots.gif =x250)

# About the App

***Current Features:***

 - [x] Listen to live [kirtan](https://en.wikipedia.org/wiki/Sikh_music) from Golden Temple, Amritsar.
 - [x] Listen to daily [Mukhwak](https://en.wikipedia.org/wiki/Hukamnama) and Mukhwak [Katha](https://www.sikhiwiki.org/index.php/Katha).

 
  

 - [x] Users can also set duration for listening live Kirtan (5 Minutes to 1 Hour or Unlimited time). After the set duration time, live kirtan will automatically stop.

  

 - [x] Read the daily Mukhwak in the app.

  

 - [x] Read daily routine.

  

 - [x] Now YouTube live channel redirects are supported.

  
***Advanced Features (Now Available)***  
  

 - [x] Get List of [Ragi](https://en.wikipedia.org/wiki/Ragi_%28Sikhism%29) duties updated daily.

  

 - [x] Automatically displays the current Ragi performing live Kirtan or the name of religious ceremony currently performed at Golden Temple, data sourced from [SGPC.net](https://en.wikipedia.org/wiki/Shiromani_Gurdwara_Parbandhak_Committee).

  

 - [x] Now Record the live Kirtan as long you want and save to your phone.

 
  

 - [x] Automatically show information about whether live kirtan is
       started or not according to the time table in Daily routine by
       SGPC.

  
  
***Permissions and ads.***  

 - [x] No permissions required that invade your privacy.

  

 - [x] In this new release all ads are completely removed.

  

 - [x] App will remain free forever.

  

***Features Under Development.***

  

 - [ ] Advanced Feature: Display the current [shabad](https://www.sikhiwiki.org/index.php/Shabad) playing. [use of Artificial Intelligence and Machine Learning].

# Tech Stack
***Flutter***
-   App’s UI, animations & state management.
-   Sending data requests to Firebase.
-   Live audio logic, background playing & even when device is locked.
-   Playing on bluetooth devices.
-   Recording & saving audio directly from stream link (not from device’s mic - to prevent recording audios from device's surrounding) to local storage.
-   Timer functionality to stop playing after specified time.
-   YouTube live video redirects when live video broadcast starts.
-   ~~Google AdMob to serve ads (now I have removed all ads).~~

***Python & GitHub Actions***

-   App’s backend is in two python scripts hosted on  _**[GitHub Actions](https://github.com/features/actions)**_ which run daily at specific times using cron jobs.
-   Web scraping data for audio stream links, timetable and duty list from _**[Golden Temple’s website](https://sgpc.net/)**_.
-   _**[YouTube data api v3](https://developers.google.com/youtube/v3)**_  to collect live broadcast video links.
-   Pushing and updating all data to Firebase  _**[Cloud Firestore](https://firebase.google.com/docs/firestore)**_.

***Firebase***

-   Cloud Firestore to store all data.

***Flutter Packages Used***
- flutter_native_splash
- just_audio
 - google_fonts
  - font_awesome_flutter
 -  audio_video_progress_bar
 - just_audio_background
-  transparent_image
-  intl
-  text_scroll
-  http
-  path_provider
-  cached_network_image
-  permission_handler
 - cloud_firestore
 - firebase_core
 - flutter_offline
 - connectivity_plus
 - url_launcher
  



## Support the Project.
  
You can support this project by just simply downloading the app.
  
a 0xharkirat (Harkirat Singh) 🦅 production.  

> Creating Better technologies for the greater good of Humanity.
## Copyright & Disclaimer.

All data is sourced from SGPC.net; SGPC is copyright owner of all the data and media; Ragi list and duties may not be updated on SGPC.net in realtime.

