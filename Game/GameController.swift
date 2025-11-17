import Foundation
import Combine

/// Acts as the glue between the SpriteKit scene and the SwiftUI overlay.
///
/// Maintains game state that needs to be shared across the game and UI,
/// such as whether the game is paused, whether a revive modal is showing,
/// the current theme index, slow‑motion activation, etc. It also routes
/// user actions (pause toggles, theme changes, ads, etc.) to the scene via
/// NotificationCenter.
final class GameController: ObservableObject {
  // Published properties drive updates in the SwiftUI overlay
  @Published var paused: Bool = false
  @Published var showRevive: Bool = false
  @Published var dailyMode: Bool = false
  @Published var themeIndex: Int = 0
  @Published var slowMoActive: Bool = false

  /// Counts how many times the player has failed. Used for interstitial cadence.
  private(set) var deaths: Int = 0

  /// Handles ad loading and presentation. See Ads/AdsManager.swift
  let ads = AdsManager()

  /// Invoked when the view appears. Subclasses can override.
  func start() { }

  /// Toggle between paused and playing states.
  func togglePause() {
    paused.toggle()
    post(.pauseToggle)
  }

  /// Called when the player dies. Shows an interstitial every 3rd death.
  func gameOver() {
    deaths += 1
    if !Store.shared.removeAds && deaths % 3 == 0 {
      ads.showInterstitial()
    }
    showRevive = true
  }

  /// Attempts to revive the player via a rewarded ad. If ads have been
  /// removed, the revive is automatically granted.
  func revive() {
    ads.showRewarded { ok in
      if ok || Store.shared.removeAds {
        self.post(.reviveRequest)
        self.showRevive = false
      }
    }
  }

  /// Dismisses the revive prompt and signals the game to restart.
  func cancelReviveAndRestart() {
    showRevive = false
    post(.restart)
  }

  /// Requests a new theme index. Notifies the scene to update its theme.
  func requestTheme(_ idx: Int) {
    themeIndex = idx
    post(.themeChange, idx)
  }

  /// Activates a temporary slow‑motion power‑up via rewarded ad. If ads
  /// have been removed, the power‑up is granted immediately. Slow motion
  /// ends after 6 seconds.
  func requestSlowMo() {
    ads.showRewarded { ok in
      if ok || Store.shared.removeAds {
        self.slowMoActive = true
        self.post(.slowMoOn)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
          self.slowMoActive = false
          self.post(.slowMoOff)
        }
      }
    }
  }

  /// Applies the daily challenge mode. Notifies the scene to tune difficulty.
  func applyDailyMode() {
    post(.dailyModeChanged, dailyMode)
  }

  /// Helper to post notifications on NotificationCenter.
  private func post(_ name: Notification.Name, _ object: Any? = nil) {
    NotificationCenter.default.post(name: name, object: object)
  }
}

/// Notification names used to communicate between the GameController and
/// GameScene. These are referenced by name in the scene’s bindState method.
extension Notification.Name {
  static let pauseToggle       = Notification.Name("pauseToggle")
  static let themeChange       = Notification.Name("themeChange")
  static let reviveRequest     = Notification.Name("reviveRequest")
  static let restart           = Notification.Name("restart")
  static let slowMoOn          = Notification.Name("slowMoOn")
  static let slowMoOff         = Notification.Name("slowMoOff")
  static let dailyModeChanged  = Notification.Name("dailyModeChanged")
}
