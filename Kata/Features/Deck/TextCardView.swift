import KataCore
import KataUI
import SwiftUI

struct TextCardView: View {
  let blocks: [Block]
  @Environment(AppSettings.self) private var settings

  var body: some View {
    BlocksView(blocks: blocks, codeFontSize: max(12, settings.codeFontPoints - 1))
  }
}
