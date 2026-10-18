import Foundation

/// SplitMix64: small, deterministic, platform independent.
public struct SeededRandom: RandomNumberGenerator, Sendable {
  private var state: UInt64

  public init(seed: UInt64) { state = seed }

  /// Stable (unlike `hashValue`) 64-bit FNV-1a hash of a string.
  public static func hash(_ string: String) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for b in string.utf8 { h = (h ^ UInt64(b)) &* 0x100_0000_01b3 }
    return h
  }

  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  /// A permutation of `0..<count`, e.g. option order for an exercise seeded by `(key, reps)`.
  public static func permutation(count: Int, seed: UInt64) -> [Int] {
    var rng = SeededRandom(seed: seed)
    return Array(0..<count).shuffled(using: &rng)
  }

  public static func seed(key: ExerciseKey, reps: Int) -> UInt64 {
    hash("\(key.rawValue)@\(reps)")
  }
}
