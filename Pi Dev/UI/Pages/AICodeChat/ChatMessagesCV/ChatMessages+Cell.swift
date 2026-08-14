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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .margins(.all, 0)
  }

  override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes)
    -> UICollectionViewLayoutAttributes {
    layoutAttributes
  }
}
