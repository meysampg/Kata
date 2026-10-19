import KataCore
import SwiftUI

public struct TextCardView: View {
  let blocks: [Block]
  let codeFontSize: CGFloat

  /// - Parameter codeFontSize: the code font for embedded snippets (apps pass `max(12, settings - 1)`).
  public init(blocks: [Block], codeFontSize: CGFloat) {
    self.blocks = blocks; self.codeFontSize = codeFontSize
  }

  public var body: some View {
    BlocksView(blocks: blocks, codeFontSize: codeFontSize)
  }
}
