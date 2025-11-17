import SwiftUI
import SpriteKit

struct MainView: View {
    @StateObject var gc = GameController()

    var scene: GameScene {
        let s = GameScene(size: UIScreen.main.bounds.size)
        s.scaleMode = .resizeFill
        s.onGameOver = { gc.gameOver() }
        s.onReviveApplied = { gc.showRevive = false }
        s.applyTheme(Themes[gc.themeIndex])
        s.bindState(gc)
        return s
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene).ignoresSafeArea()
            HUD(gc: gc, theme: $gc.themeIndex)
        }
        .onAppear { gc.start() }
    }
}
