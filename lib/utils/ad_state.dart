import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdState {
  Future<InitializationStatus> initialization;

  AdState(this.initialization);

  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4044023931058018/8808754038';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-4044023931058018/2475279973';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-4044023931058018/4621300853";
    } else if (Platform.isIOS) {
      return "ca-app-pub-4044023931058018/7192420034";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  BannerAdListener get bannerAdListener => _bannerAdListener;

  final BannerAdListener _bannerAdListener = BannerAdListener(
    onAdLoaded: (ad) => print('Ad loaded: ${ad.adUnitId}.'),
    onAdClosed: (ad) => print('Ad closed: ${ad.adUnitId}.'),
    onAdFailedToLoad: (ad, error) {
      print('Ad failed to load: ${ad.adUnitId}, $error.');
      ad.dispose();
    },
    onAdOpened: (ad) => print('Ad opened: ${ad.adUnitId}.'),
    onAdClicked: (ad) => print('Ad clicked: ${ad.adUnitId}.'),
  );
}
