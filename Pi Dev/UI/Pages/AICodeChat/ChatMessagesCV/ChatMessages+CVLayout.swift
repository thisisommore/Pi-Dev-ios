//
//  ChatMessages+CVLayout.swift
//  Pi Dev
//

import UIKit

enum ChatCVAlign {
  case left, right, center
}

extension UICollectionView {
  func cvAvailableWidth() -> CGFloat {
    bounds.width - (contentInset.left + contentInset.right)
  }
}

protocol ChatMessagesCVLayoutDelegate: AnyObject {
  func collectionView(
    _ collectionView: UICollectionView, layout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize

  func collectionView(
    _ collectionView: UICollectionView, layout: UICollectionViewLayout,
    alignForItemAt indexPath: IndexPath
  ) -> ChatCVAlign

  func prepareDone()
}

final class ChatMessagesCVLayout: UICollectionViewLayout {
  static let defaultSpaceBetween: CGFloat = 10
  static let groupedSenderSpaceBetween: CGFloat = 4
  private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
  private var firstPrepare = true
  private var height: CGFloat = 0
  var newIndexForBackUpPoint = 0
  private(set) var prevIndexForBackUpPoint = 0

  var backupPoint: CGPoint = .zero
  /// Set only when loading older messages so the visible row stays put.
  var usesBackupPoint = false
  override var collectionViewContentSize: CGSize {
    CGSize(width: collectionView!.cvAvailableWidth(), height: height)
  }

  override func prepare() {
    height = 0
    cachedAttributes.removeAll(keepingCapacity: true)
    guard let collectionView else { return }
    let delegate = collectionView.delegate as! ChatMessagesCVLayoutDelegate
    if collectionView.numberOfSections < 1 { return }
    let noOfItems = collectionView.numberOfItems(inSection: 0)
    if noOfItems == 0 { return }
    cachedAttributes.reserveCapacity(noOfItems)
    for index in 0 ..< noOfItems {
      let indexPath = IndexPath(item: index, section: 0)
      let spacing = spacingBeforeItem(at: indexPath)
      let size = delegate.collectionView(collectionView, layout: self, sizeForItemAt: indexPath)
      let alignment = delegate.collectionView(collectionView, layout: self, alignForItemAt: indexPath)
      let available = collectionView.cvAvailableWidth()
      let cellWidth = min(size.width, available)
      let cellSize = CGSize(width: cellWidth, height: size.height)
      let x: CGFloat = switch alignment {
      case .left: 0
      case .right: available - cellWidth
      case .center: (available - cellWidth) / 2
      }
      let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
      attributes.frame = CGRect(origin: CGPoint(x: x, y: height + spacing), size: cellSize)
      height += (cellSize.height + spacing)
      cachedAttributes.append(attributes)

      if attributes.frame.intersects(collectionView.bounds) {
        prevIndexForBackUpPoint = index
      }
    }
    if firstPrepare {
      firstPrepare = false
      let last = IndexPath(item: noOfItems - 1, section: 0)
      collectionView.scrollToItem(at: last, at: .bottom, animated: false)
    }
    delegate.prepareDone()
  }

  private func spacingBeforeItem(at indexPath: IndexPath) -> CGFloat {
    // Group consecutive same-role messages tighter (Haven parity)
    guard let vc = collectionView?.delegate as? ChatMessagesVC,
          indexPath.item < vc.itemsCountForLayout else {
      return Self.defaultSpaceBetween
    }
    let item = vc.itemForLayout(at: indexPath.item)
    guard case .message(let id) = item,
          let msg = vc.store.messages.first(where: { $0.id == id }) else {
      return Self.defaultSpaceBetween
    }
    if indexPath.item > 0,
       case .message(let prevId) = vc.itemForLayout(at: indexPath.item - 1),
       let prev = vc.store.messages.first(where: { $0.id == prevId }),
       prev.role == msg.role {
      return Self.groupedSenderSpaceBetween
    }
    return Self.defaultSpaceBetween
  }

  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    var attributesArray = [UICollectionViewLayoutAttributes]()
    guard let lastIndex = cachedAttributes.indices.last,
          let firstMatchIndex = binSearch(rect, start: 0, end: lastIndex) else { return attributesArray }
    for attributes in cachedAttributes[..<firstMatchIndex].reversed() {
      guard attributes.frame.maxY >= rect.minY else { break }
      attributesArray.append(attributes.copy() as! UICollectionViewLayoutAttributes)
    }
    for attributes in cachedAttributes[firstMatchIndex...] {
      guard attributes.frame.minY <= rect.maxY else { break }
      attributesArray.append(attributes.copy() as! UICollectionViewLayoutAttributes)
    }
    return attributesArray
  }

  private func binSearch(_ rect: CGRect, start: Int, end: Int) -> Int? {
    if end < start { return nil }
    let mid = (start + end) / 2
    let attr = cachedAttributes[mid]
    if attr.frame.intersects(rect) { return mid }
    else if attr.frame.maxY <= rect.minY { return binSearch(rect, start: mid + 1, end: end) }
    else { return binSearch(rect, start: start, end: mid - 1) }
  }

  override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    guard indexPath.item < cachedAttributes.count else { return nil }
    return cachedAttributes[indexPath.item].copy() as? UICollectionViewLayoutAttributes
  }

  override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    guard let collectionView else { return false }
    return abs(newBounds.width - collectionView.bounds.width) > 0.5
  }

  override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
    guard self.usesBackupPoint else {
      return proposedContentOffset
    }
    let relocatedElementAttrs: UICollectionViewLayoutAttributes? = layoutAttributesForItem(at: IndexPath(item: newIndexForBackUpPoint, section: 0))
    guard let relocatedElementAttrs else {
      return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
    }
    let newY = relocatedElementAttrs.frame.origin.y
    let oldY = backupPoint.y
    let change = newY - oldY
    let correctedY = proposedContentOffset.y + change
    let minX = -collectionView!.adjustedContentInset.left
    let minY = -collectionView!.adjustedContentInset.top
    guard correctedY >= minY && proposedContentOffset.x >= minX else {
      return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
    }
    return CGPoint(x: proposedContentOffset.x, y: correctedY)
  }
}

private extension IndexPath {
  init(item: Int) { self.init(item: item, section: 0) }
}
