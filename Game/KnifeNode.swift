import SpriteKit

/// Enum representing the different knife variants that can be thrown in the game.
/// Each case defines a texture name and a base size from which scaled sprites
/// are derived. You can add more cases to support additional weapons.
enum KnifeType: CaseIterable {
  case dagger
  case sword
  case scythe

  /// The name of the image in Assets.xcassets corresponding to this knife.
  var textureName: String {
    switch self {
    case .dagger: return "knife_dagger"
    case .sword:  return "knife_sword"
    case .scythe: return "knife_scythe"
    }
  }

  /// The unscaled size of the sprite. This is multiplied by a random
  /// scale factor when spawning the knife.
  var baseSize: CGSize {
    switch self {
    case .dagger: return .init(width: 60, height: 180)
    case .sword:  return .init(width: 70, height: 220)
    case .scythe: return .init(width: 90, height: 260)
    }
  }
}

/// Bit masks used for collision categories. These are used on the handle and
/// blade nodes so that the scene can quickly determine whether the handle or
/// blade intersects the catch zone.
struct PC {
  static let none:     UInt32 = 0
  static let handle:   UInt32 = 1 << 1
  static let blade:    UInt32 = 1 << 2
  static let catchZone: UInt32 = 1 << 3
}

/// Represents a single falling knife. Comprises a sprite and two invisible
/// child nodes marking the handle and blade. Physics bodies are attached to
/// these children solely for intersection testing.
final class KnifeNode: SKNode {
  let sprite      = SKSpriteNode()
  let handle      = SKSpriteNode(color: .clear, size: .zero)
  let blade       = SKSpriteNode(color: .clear, size: .zero)

  /// Create a new knife of the given type and properties.
  ///
  /// - Parameters:
  ///   - type: Which variant to spawn.
  ///   - scale: A multiplier applied to `baseSize`.
  ///   - spin: Whether the sprite should rotate while falling.
  ///   - fallSpeed: Multiplier controlling how fast the knife drops.
  init(type: KnifeType, scale: CGFloat, spin: Bool, fallSpeed: CGFloat) {
    super.init()

    // Configure the sprite using the texture name and scaled size
    let texture = SKTexture(imageNamed: type.textureName)
    sprite.texture = texture
    sprite.size = CGSize(width: type.baseSize.width * scale,
                         height: type.baseSize.height * scale)
    addChild(sprite)

    // Define hit zones on the sprite relative to its size
    let handleHeight = sprite.size.height * 0.28
    let bladeHeight  = sprite.size.height * 0.58
    handle.size = CGSize(width: sprite.size.width * 0.55, height: handleHeight)
    blade.size  = CGSize(width: sprite.size.width * 0.65, height: bladeHeight)
    handle.position = CGPoint(x: 0, y: -sprite.size.height * 0.32)
    blade.position  = CGPoint(x: 0, y:  sprite.size.height * 0.10)
    sprite.addChild(handle)
    sprite.addChild(blade)

    // Assign static physics bodies to handle/blade for hit testing
    [handle, blade].forEach { node in
      node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
      node.physicsBody?.isDynamic = false
    }
    handle.physicsBody?.categoryBitMask = PC.handle
    blade.physicsBody?.categoryBitMask  = PC.blade

    // Attach a dynamic physics body to the sprite so it falls
    let body = SKPhysicsBody(texture: texture, size: sprite.size)
    body.affectedByGravity = true
    body.allowsRotation   = true
    sprite.physicsBody = body

    // Control rotation based on `spin`
    if !spin {
      sprite.zRotation = 0
      sprite.physicsBody?.angularVelocity = 0
    } else {
      // Randomize rotation direction for variety
      sprite.physicsBody?.angularVelocity = CGFloat.random(in: -4...4)
    }

    // Give the sprite an initial downward velocity proportional to fallSpeed
    sprite.physicsBody?.velocity = CGVector(dx: 0, dy: -fallSpeed * 100)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
