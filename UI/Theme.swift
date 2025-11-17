import SwiftUI

struct Theme: Identifiable {
  let id = UUID()
  let name: String
  let bg: Color
  let tint: Color
}

/// A list of built‑in color themes for the game.
let Themes: [Theme] = [
  .init(name: "Neon",  bg: .black,                                       tint: .mint),
  .init(name: "Solar", bg: Color(red: 0.06, green: 0.03, blue: 0.08),     tint: .yellow),
  .init(name: "Ocean", bg: Color.blue.opacity(0.12),                      tint: .cyan)
]
