import Foundation

enum ChatCVItem: Hashable, Sendable {
  case message(UUID)
  case typing
}
