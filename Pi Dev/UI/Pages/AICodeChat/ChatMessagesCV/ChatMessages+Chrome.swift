//
//  ChatMessages+Chrome.swift
//  Pi Dev
//

import UIKit

/// Collection view is a full-screen UIKit representable. Hit-test the SwiftUI
/// header (and other non-list subviews) first; pass the header band through
/// so an overlay header can still receive taps.
final class HeaderPassthroughView: UIView {
  var passthroughHeight: CGFloat = 68
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
    for subview in subviews.reversed() where !(subview is UICollectionView) {
      let converted = subview.convert(point, from: self)
      if let hit = subview.hitTest(converted, with: event) {
        return hit
      }
    }
    if point.y < passthroughHeight { return nil }
    return super.hitTest(point, with: event)
  }
}

final class StatusBarScrimView: UIView {
  private let gradient = CAGradientLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .clear
    gradient.colors = Self.colors
    gradient.startPoint = CGPoint(x: 0.5, y: 0)
    gradient.endPoint = CGPoint(x: 0.5, y: 1)
    layer.addSublayer(gradient)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func layoutSubviews() {
    super.layoutSubviews()
    gradient.frame = bounds
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    gradient.colors = Self.colors
  }

  func setHoldThenFade(holdHeight: CGFloat, fadeHeight: CGFloat) {
    let total = holdHeight + fadeHeight
    guard total > 0 else { return }
    let holdEnd = holdHeight / total
    gradient.locations = [0, NSNumber(value: holdEnd), 1]
  }

  private static var colors: [CGColor] {
    let solid = UIColor.systemBackground.withAlphaComponent(0.8).cgColor
    return [
      solid,
      solid,
      UIColor.systemBackground.withAlphaComponent(0).cgColor
    ]
  }
}
