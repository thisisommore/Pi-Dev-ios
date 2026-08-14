//
//  ChatMessages+CVDelegate.swift
//  Pi Dev
//

import SwiftUI
import UIKit

extension ChatMessagesVC: UICollectionViewDataSource {
  func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    items.count
  }
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HostingCell.reuseID, for: indexPath) as! HostingCell
    let width = collectionView.cvAvailableWidth()
    let item = items[indexPath.item]
    switch item {
    case .message(let id):
      if store.messages.contains(where: { $0.id == id }) {
        cell.hostSwiftUI(MessageRow(store: store, messageId: id), width: width)
      } else {
        cell.hostSwiftUI(EmptyView(), width: width)
      }
    case .typing:
      cell.hostSwiftUI(TypingIndicator(tint: appColor), width: width)
    }
    return cell
  }
}

extension ChatMessagesVC: UICollectionViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let distFromBottom = distanceFromBottom(minY: scrollView.contentOffset.y, viewSize: scrollView.bounds.height, contentSize: scrollView.contentSize.height)
    isNearBottom = distFromBottom < 80
    let shouldShowButton = distFromBottom > 60
    let shouldHideButton = !shouldShowButton || tempButtonDisable
    if scrollToBottomButton.isHidden != shouldHideButton {
      UIView.animate(withDuration: 0.2) {
        self.scrollToBottomButton.isHidden = shouldHideButton
        self.scrollToBottomButton.alpha = shouldHideButton ? 0 : 1
      }
    }
  }
}

extension ChatMessagesVC: ChatMessagesCVLayoutDelegate {
  func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let width = collectionView.cvAvailableWidth()
    guard width > 0 else { return CGSize(width: 1, height: 1) }
    guard indexPath.item < items.count else { return CGSize(width: width, height: 80) }
    switch items[indexPath.item] {
    case .message(let id):
      guard let message = store.messages.first(where: { $0.id == id }) else {
        return CGSize(width: width, height: 1)
      }
      let signature = contentSignature(for: message)
      if let cached = heightCache[id], cached.signature == signature {
        return CGSize(width: width, height: cached.height)
      }
      let height = measureHeight(of: MessageRow(store: store, messageId: id), width: width)
      heightCache[id] = (signature, height)
      return CGSize(width: width, height: height)
    case .typing:
      return CGSize(width: width, height: 40)
    }
  }

  func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, alignForItemAt _: IndexPath) -> ChatCVAlign {
    // Full-width rows: UserBubble Spacer right-aligns; assistant text wraps.
    .left
  }

  func prepareDone() {}
}
