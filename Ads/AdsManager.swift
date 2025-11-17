import GoogleMobileAds
import UIKit

/// Handles loading and presenting Google AdMob interstitial and rewarded ads.
/// Respects the Store flag for removing ads and automatically reloads ads
/// after they are displayed or dismissed. Always call `showInterstitial` and
/// `showRewarded` on the main thread.
final class AdsManager: NSObject, GADFullScreenContentDelegate {
  private var interstitial: GADInterstitialAd?
  private var rewarded: GADRewardedAd?
  private let interstitialID = "ca-app-pub-xxxxxxxxxxxxxxxx/iiiiiiiiii"
  private let rewardedID     = "ca-app-pub-xxxxxxxxxxxxxxxx/rrrrrrrrrr"

  override init() {
    super.init()
    loadInterstitial()
    loadRewarded()
  }

  /// Requests a new interstitial ad.
  private func loadInterstitial() {
    GADInterstitialAd.load(withAdUnitID: interstitialID, request: GADRequest()) { [weak self] ad, error in
      self?.interstitial = ad
      self?.interstitial?.fullScreenContentDelegate = self
    }
  }

  /// Requests a new rewarded ad.
  private func loadRewarded() {
    GADRewardedAd.load(withAdUnitID: rewardedID, request: GADRequest()) { [weak self] ad, error in
      self?.rewarded = ad
      self?.rewarded?.fullScreenContentDelegate = self
    }
  }

  /// Presents an interstitial ad if ads haven’t been removed. If no ad is
  /// ready, it will attempt to load one for next time.
  func showInterstitial() {
    guard !Store.shared.removeAds else { return }
    guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController,
          let ad = interstitial else {
      loadInterstitial()
      return
    }
    ad.present(fromRootViewController: root)
    interstitial = nil
    loadInterstitial()
  }

  /// Presents a rewarded ad if ads haven’t been removed. Calls the
  /// completion handler with a boolean indicating whether the reward was
  /// granted. If no ad is ready, loads one and fails.
  func showRewarded(_ completion: @escaping (Bool) -> Void) {
    if Store.shared.removeAds {
      completion(true)
      return
    }
    guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController,
          let ad = rewarded else {
      loadRewarded()
      completion(false)
      return
    }
    ad.present(fromRootViewController: root) {
      completion(true)
    }
    rewarded = nil
    loadRewarded()
  }

  // MARK: - GADFullScreenContentDelegate
  func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    // Reload whichever ad was dismissed
    if ad === interstitial {
      loadInterstitial()
    } else if ad === rewarded {
      loadRewarded()
    }
  }
}

private extension UIWindowScene {
  var keyWindow: UIWindow? {
    return windows.first { $0.isKeyWindow }
  }
}
