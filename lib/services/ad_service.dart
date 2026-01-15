import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917'; // Test ID
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Test ID
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test ID

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  BannerAd? _bannerAd;
  bool _isRewardedAdReady = false;
  bool _isInterstitialAdReady = false;
  DateTime? _lastInterstitialAdTime;
  static const Duration _interstitialAdCooldown = Duration(minutes: 3);

  // Initialize Mobile Ads SDK
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  // Load Rewarded Ad
  Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          _setFullScreenContentCallback(ad);
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('RewardedAd failed to load: $error');
          _isRewardedAdReady = false;
        },
      ),
    );
  }

  // Show Rewarded Ad
  Future<bool> showRewardedAd({
    required Function(int rewardAmount, String rewardType) onRewarded,
  }) async {
    if (!_isRewardedAdReady || _rewardedAd == null) {
      await loadRewardedAd();
      return false;
    }

    bool adCompleted = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _isRewardedAdReady = false;
        _rewardedAd = null;
        if (!adCompleted) {
          loadRewardedAd(); // Preload next ad
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _isRewardedAdReady = false;
        _rewardedAd = null;
        loadRewardedAd();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        adCompleted = true;
        onRewarded(reward.amount.toInt(), reward.type);
      },
    );

    return true;
  }

  // Load Interstitial Ad
  Future<void> loadInterstitialAd() async {
    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _setInterstitialFullScreenContentCallback(ad);
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('InterstitialAd failed to load: $error');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  // Show Interstitial Ad (rate-limited)
  Future<bool> showInterstitialAd() async {
    final now = DateTime.now();
    if (_lastInterstitialAdTime != null &&
        now.difference(_lastInterstitialAdTime!) < _interstitialAdCooldown) {
      return false; // Too soon to show another ad
    }

    if (!_isInterstitialAdReady || _interstitialAd == null) {
      await loadInterstitialAd();
      return false;
    }

    _interstitialAd!.show();
    _lastInterstitialAdTime = now;
    return true;
  }

  // Create Banner Ad Widget
  BannerAd? createBannerAd({
    required AdSize adSize,
    required Function(BannerAd) onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          onAdLoaded(ad as BannerAd);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (onAdFailedToLoad != null) {
            onAdFailedToLoad(error);
          }
        },
        onAdOpened: (Ad ad) {},
        onAdClosed: (Ad ad) {},
      ),
    );

    _bannerAd!.load();
    return _bannerAd;
  }

  void _setFullScreenContentCallback(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _isRewardedAdReady = false;
        _rewardedAd = null;
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _isRewardedAdReady = false;
        _rewardedAd = null;
        loadRewardedAd();
      },
    );
  }

  void _setInterstitialFullScreenContentCallback(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        _isInterstitialAdReady = false;
        _interstitialAd = null;
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        _isInterstitialAdReady = false;
        _interstitialAd = null;
        loadInterstitialAd();
      },
    );
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
  }
}
