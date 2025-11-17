import Foundation

/// Generates a pseudo‑random seed based on the current calendar date.
/// Used to create slight daily variations in difficulty (e.g. catch zone
/// width or speed). Combines the year, month and day via XOR to avoid
/// repeating patterns within a short timeframe.
enum DailyChallenge {
  static func seedForToday() -> Int {
    let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    let y = (comps.year ?? 0) * 73856093
    let m = (comps.month ?? 0) * 19349663
    let d = (comps.day ?? 0) * 83492791
    return y ^ m ^ d
  }
}
