import SpriteKit
import UIKit

/// The primary SpriteKit scene which handles game logic. This scene
/// coordinates the falling knives, detects catches/misses, manages
/// scoring, and communicates with the SwiftUI overlay via callbacks.
final class GameScene: SKScene {
  // MARK: - Callbacks
  /// Called after a game over so that the controller can show ads or UI.
  var onGameOver: (() -> Void)?
  /// Called when a revive has been applied via ad and the game should resume.
  var onReviveApplied: (() -> Void)?

  // MARK: - Nodes and state
  private var catchZone = SKSpriteNode(color: .white.withAlphaComponent(0.08),
                                       size: .init(width: 140, height: 28))
  private var knife: KnifeNode?
  private var score: Int = 0
  private var best: Int = 0
  private var level: Int = 1
  private var nextShouldSpin: Bool = false

  private let scoreLbl = SKLabelNode(fontNamed: "Avenir-Heavy")
  private let bestLbl  = SKLabelNode(fontNamed: "Avenir-Heavy")
  private let feverLbl = SKLabelNode(fontNamed: "Avenir-Heavy")

  // Combo/fever state
  private var combo: Int = 0
  private var fever: Bool = false
  private var dailyMode: Bool = false
  private var slowMo: Bool = false

  // Base width used for catch zone scaling
  private var czBaseWidth: CGFloat = 140

  // MARK: - Scene lifecycle
  override func didMove(to view: SKView) {
    physicsWorld.gravity = .init(dx: 0, dy: -9.8)
    backgroundColor = .black

    // Setup catch zone and labels
    catchZone.position = CGPoint(x: frame.midX, y: 120)
    catchZone.physicsBody = SKPhysicsBody(rectangleOf: catchZone.size)
    catchZone.physicsBody?.isDynamic = false
    addChild(catchZone)

    scoreLbl.fontSize = 28
    scoreLbl.position = CGPoint(x: frame.midX, y: frame.maxY - 70)
    addChild(scoreLbl)

    bestLbl.fontSize = 16
    bestLbl.position = CGPoint(x: frame.midX, y: frame.maxY - 100)
    best = UserDefaults.standard.integer(forKey: "best")
    addChild(bestLbl)

    feverLbl.fontSize = 18
    feverLbl.position = CGPoint(x: frame.midX, y: frame.maxY - 130)
    feverLbl.text = ""
    addChild(feverLbl)

    czBaseWidth = catchZone.size.width

    spawnKnife()
    updateHUD()
  }

  /// Called by the controller to bind its state changes to the scene.
  func bindState(_ gc: GameController) {
    NotificationCenter.default.addObserver(forName: .pauseToggle, object: nil, queue: .main) { [weak self] _ in
      self?.isPaused.toggle()
    }
    NotificationCenter.default.addObserver(forName: .reviveRequest, object: nil, queue: .main) { [weak self] _ in
      self?.revive()
    }
    NotificationCenter.default.addObserver(forName: .restart, object: nil, queue: .main) { [weak self] _ in
      self?.hardRestart()
    }
    NotificationCenter.default.addObserver(forName: .themeChange, object: nil, queue: .main) { [weak self] notification in
      if let index = notification.object as? Int {
        self?.applyTheme(Themes[index])
      }
    }
    NotificationCenter.default.addObserver(forName: .slowMoOn, object: nil, queue: .main) { [weak self] _ in
      self?.enableSlowMo(true)
    }
    NotificationCenter.default.addObserver(forName: .slowMoOff, object: nil, queue: .main) { [weak self] _ in
      self?.enableSlowMo(false)
    }
    NotificationCenter.default.addObserver(forName: .dailyModeChanged, object: nil, queue: .main) { [weak self] notification in
      self?.dailyMode = (notification.object as? Bool) ?? false
      self?.applyDailyTuning()
    }
  }

  // MARK: - Theming
  /// Updates the background and label colors to match the selected theme.
  func applyTheme(_ t: Theme) {
    backgroundColor      = UIColor(t.bg)
    scoreLbl.fontColor   = UIColor(t.tint)
    bestLbl.fontColor    = UIColor(t.tint)
    feverLbl.fontColor   = UIColor(t.tint)
  }

  // MARK: - Gameplay
  /// Spawn a new knife at the top of the screen with random properties.
  private func spawnKnife() {
    knife?.removeFromParent()
    let type  = KnifeType.allCases.randomElement()!
    let scale = CGFloat.random(in: 0.85...1.25)
    let spin  = nextShouldSpin
    nextShouldSpin.toggle()
    let baseSpeed: CGFloat = min(2.0 + CGFloat(level) * 0.25, 6.0)
    let speed = slowMo ? baseSpeed * 0.5 : baseSpeed
    let node  = KnifeNode(type: type, scale: scale, spin: spin, fallSpeed: speed)
    node.position = CGPoint(x: CGFloat.random(in: frame.minX + 80...frame.maxX - 80),
                            y: frame.maxY + 80)
    addChild(node)
    knife = node
    // Auto-shrink catch zone width as level increases
    let shrink: CGFloat = max(0.6, 1.0 - CGFloat(level) * 0.03)
    catchZone.size.width = czBaseWidth * shrink
  }

  /// Called whenever the player taps on the screen. Determines whether the
  /// tap is a catch or a miss based on the positions of the handle and blade.
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let knife = knife, let touch = touches.first else { return }
    let location = touch.location(in: self)
    // Only allow taps near the catch zone to discourage random tapping
    guard abs(location.y - catchZone.position.y) < 120 else { return }
    let handlePos = knife.convert(knife.handle.position, to: self)
    let bladePos  = knife.convert(knife.blade.position,  to: self)
    let handleOK  = catchZone.frame.contains(handlePos)
    let bladeHit  = catchZone.frame.contains(bladePos)
    if handleOK && !bladeHit {
      let perfect = isPerfectCatch(handlePoint: handlePos)
      onSuccess(perfect: perfect)
    } else {
      gameOver()
    }
  }

  /// Determines whether the catch was within the tighter perfect window.
  private func isPerfectCatch(handlePoint: CGPoint) -> Bool {
    let pad = catchZone.size.width * 0.18
    let perfectRect = CGRect(x: catchZone.frame.midX - pad / 2,
                             y: catchZone.frame.minY,
                             width: pad,
                             height: catchZone.frame.height)
    return perfectRect.contains(handlePoint)
  }

  /// Handles a successful catch. Increments the score, triggers combos,
  /// fever mode, plays sounds/haptics, and respawns the next knife.
  private func onSuccess(perfect: Bool) {
    score += fever ? 2 : 1
    combo = perfect ? combo + 1 : 0
    if perfect {
      glowPerfect()
      Haptics.impact(.light)
    } else {
      Haptics.selection()
    }
    if combo >= 3 && !fever {
      fever = true
      feverFlash()
      run(.wait(forDuration: 5)) { [weak self] in
        self?.fever = false
        self?.updateHUD()
      }
    }
    level = 1 + score / 5
    updateHUD()
    knife?.removeFromParent()
    spawnKnife()
    run(.playSoundFileNamed("ding.wav", waitForCompletion: false))
  }

  /// Updates the HUD labels. Called whenever score or fever state changes.
  private func updateHUD() {
    scoreLbl.text = "\(score)"
    bestLbl.text  = "BEST \(max(best, score))"
    feverLbl.text = fever ? "FEVER ×2" : ""
  }

  /// Periodically called each frame. Checks if the current knife has fallen
  /// below the screen bounds and triggers a game over if so.
  override func update(_ currentTime: TimeInterval) {
    if let y = knife?.position.y, y < -120 {
      gameOver()
    }
  }

  /// Applies daily tuning when daily mode is toggled. Adjusts the initial
  /// catch zone width based on a pseudo‑random seed derived from the date.
  private func applyDailyTuning() {
    let seed = DailyChallenge.seedForToday()
    let mod  = seed % 3
    let widthFactor: CGFloat
    switch mod {
    case 0: widthFactor = 0.80
    case 1: widthFactor = 0.90
    default: widthFactor = 1.0
    }
    catchZone.size.width = czBaseWidth * widthFactor
  }

  /// Enables or disables slow motion. Adjusts the scene’s speed property
  /// and triggers a haptic feedback when turning on.
  private func enableSlowMo(_ on: Bool) {
    slowMo = on
    self.speed = on ? 0.5 : 1.0
    if on {
      Haptics.impact(.medium)
    }
  }

  /// Creates a yellow flash when entering fever mode.
  private func feverFlash() {
    let overlay = SKShapeNode(rectOf: CGSize(width: frame.width, height: frame.height))
    overlay.fillColor = .yellow
    overlay.alpha = 0.12
    overlay.zPosition = 999
    addChild(overlay)
    overlay.run(.sequence([
      .fadeOut(withDuration: 0.3),
      .removeFromParent()
    ]))
  }

  /// Creates a white glowing ring around the knife for perfect catches.
  private func glowPerfect() {
    guard let k = knife else { return }
    let radius = max(k.frame.width, k.frame.height) * 0.4
    let ring = SKShapeNode(circleOfRadius: radius)
    ring.strokeColor = .white
    ring.lineWidth = 3
    ring.alpha = 0.9
    ring.position = k.position
    ring.zPosition = 500
    addChild(ring)
    ring.run(.sequence([
      .group([
        .scale(to: 1.6, duration: 0.25),
        .fadeOut(withDuration: 0.25)
      ]),
      .removeFromParent()
    ]))
  }

  /// Handles a miss or fall off the bottom of the screen. Resets the score,
  /// combo, fever state, plays feedback, saves best score, and respawns.
  private func gameOver() {
    best = max(best, score)
    UserDefaults.standard.set(best, forKey: "best")
    onGameOver?()
    score = 0
    combo = 0
    fever = false
    level = 1
    updateHUD()
    playFailFX()
    spawnKnife()
  }

  /// Creates a red flash and plays a fail sound. Triggers haptic feedback.
  private func playFailFX() {
    Haptics.impact(.heavy)
    let flash = SKShapeNode(rectOf: CGSize(width: frame.width, height: frame.height))
    flash.fillColor = .red
    flash.alpha = 0.25
    flash.zPosition = 999
    addChild(flash)
    flash.run(.sequence([
      .fadeOut(withDuration: 0.2),
      .removeFromParent()
    ]))
    run(.playSoundFileNamed("fail.wav", waitForCompletion: false))
  }

  /// Restarts the game after a revive. Does not reset the score or level.
  private func revive() {
    spawnKnife()
    onReviveApplied?()
  }

  /// Hard resets the game state when starting fresh without a revive.
  private func hardRestart() {
    score = 0
    combo = 0
    fever = false
    level = 1
    updateHUD()
    spawnKnife()
  }
}
