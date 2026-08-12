//
//  ChatMessages+Cell.swift
//  Pi Dev
//

import SwiftUI
import UIKit

final class HostingCell: UICollectionViewCell {
  static let reuseID = "HostingCell"

  func hostSwiftUI<V: View>(_ view: V, width: CGFloat) {
    contentConfiguration = UIHostingConfiguration {
      view
        .frame(width: width, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }
    .margins(.all, 0)
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    contentConfiguration = nil
  }
}
