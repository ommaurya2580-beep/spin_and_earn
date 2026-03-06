import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import '../config/ad_config.dart';

class AdService {
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  
  // Test ID for Rewarded Ad
  final String _adUnitId = AdConfig.rewardedAdUnitId; 

  /// Loads a Rewarded Ad. Call this in initState or well before showing the ad.
  void loadRewardedAd({Function()? onLoaded, Function(LoadAdError)? onFailed}) {
    if (_isAdLoading) return;
    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
          if (onLoaded != null) onLoaded();
          
          // Pre-setup callbacks for when the ad is actually shown later
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              // Reload for next time
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isAdLoading = false;
          if (onFailed != null) onFailed(error);
        },
      ),
    );
  }

  /// Shows the Rewarded Ad if ready.
  /// [onUserEarnedReward] is called ONLY if the user completes the ad.
  /// [onAdDismissed] is called if the user closes it (cancelled or completed).
  /// [onAdFailedToLoad] (optional) called if ad wasn't ready.
  void showRewardedAd({
    required Function() onUserEarnedReward,
    Function()? onAdNotReady,
    Function()? onAdDismissed,
  }) {
    if (_rewardedAd != null) {
      // We must wrap callbacks to handle our specific logic
      // But fullScreenContentCallback is already set in load. 
      // We can override it here OR rely on the show() callback for the reward.
      
      // IMPORTANT: Adjust callback here to capture specific 'dismissed' event for this show call
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          if (onAdDismissed != null) onAdDismissed();
          loadRewardedAd(); // Reload for next time
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedAd = null;
          if (onAdNotReady != null) onAdNotReady();
          loadRewardedAd();
        },
      );

      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        onUserEarnedReward();
      });
      
    } else {
      if (onAdNotReady != null) onAdNotReady();
      // Try loading again
      loadRewardedAd();
    }
  }

  bool get isAdReady => _rewardedAd != null;
  bool get isAdLoading => _isAdLoading;

  void dispose() {
    _rewardedAd?.dispose();
  }
}
