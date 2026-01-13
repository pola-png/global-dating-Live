import 'dart:async';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'analytics_service.dart';

class AdMobService {
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3088816615654692/3557569577';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3088816615654692/3557569577';
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3088816615654692/6151943324';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3088816615654692/6151943324';
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3088816615654692/5305797337';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3088816615654692/5305797337';
    }
    throw UnsupportedError('Unsupported platform');
  }

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          AnalyticsService.logAdImpression(adType: 'banner', placement: 'feed');
        },
        onAdClicked: (ad) {
          AnalyticsService.logAdClick(adType: 'banner', placement: 'feed');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
  }

  static Future<NativeAd?> createNativeAd() async {
    final ad = NativeAd(
      adUnitId: nativeAdUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          AnalyticsService.logAdImpression(adType: 'native', placement: 'feed');
        },
        onAdClicked: (ad) {
          AnalyticsService.logAdClick(adType: 'native', placement: 'feed');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    await ad.load();
    return ad;
  }

  static Future<RewardedAd?> loadRewardedAd() async {
    final completer = Completer<RewardedAd?>();
    
    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            completer.complete(null);
          },
        ),
      );
      
      return await completer.future;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> showRewardedAd(RewardedAd ad) async {
    bool adShown = false;
    bool rewarded = false;
    
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        adShown = true;
        AnalyticsService.logAdImpression(adType: 'rewarded', placement: 'action');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
        AnalyticsService.logAdRewarded(placement: 'action', coinsEarned: 30);
      },
    );

    // If ad was shown but reward callback didn't fire, still consider it watched
    return adShown || rewarded;
  }
}
