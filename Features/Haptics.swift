import UIKit

/// Utility for triggering haptic feedback throughout the game. Using static
/// methods avoids the need to allocate new generators repeatedly.
enum Haptics {
  /// Triggers an impact of the specified style.
  static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
  }

  /// Triggers a selection feedback, used for less important interactions.
  static func selection() {
    UISelectionFeedbackGenerator().selectionChanged()
  }
}
