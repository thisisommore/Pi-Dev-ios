//
//  ChatMessagesVC.swift
//  Pi Dev
//
//  Custom UICollectionView-based chat list — ported from Haven's
//  ChatMessages+Controller.swift (iOS 17.2) and adapted for ChatStore/ChatMessage.
//  Uses same scroll behaviour: interactive keyboard dismiss, bottom-anchored
//  content, preserveBottomOffset on keyboard/rotation, and scroll-to-bottom button.
//  Uses simple UICollectionViewDataSource to avoid Swift 6 Sendable issues with diffable.
//

import SwiftUI
import UIKit

final class ChatMessagesVC: UIViewController {
  var store: ChatStore
  private var observationTask: Task<Void, Never>?
  var items: [ChatCVItem] = []
  var itemsCountForLayout: Int { items.count }
  func itemForLayout(at index: Int) -> ChatCVItem { items[index] }

  private(set) var isNearBottom: Bool = true
  var tempButtonDisable = true
  private var previousViewSize: CGFloat = 0

  private lazy var scrollToBottomButton: UIButton = {
    let btn = UIButton(type: .system)
    let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .light)
    let image = UIImage(systemName: "chevron.down", withConfiguration: config)
    btn.setImage(image, for: .normal)
    btn.tintColor = .white
    btn.backgroundColor = UIColor(named: "AccentColor") ?? .systemBlue
    btn.layer.cornerRadius = 8
    btn.layer.shadowColor = UIColor.black.cgColor
    btn.layer.shadowOpacity = 0.2
    btn.layer.shadowOffset = CGSize(width: 0, height: 2)
    btn.layer.shadowRadius = 4
    btn.isHidden = true
    btn.addTarget(self, action: #selector(scrollToBottomTapped), for: .touchUpInside)
    return btn
  }()

  private(set) var cv: UICollectionView

  init(store: ChatStore) {
    self.store = store
    self.cv = UICollectionView(frame: .zero, collectionViewLayout: ChatMessagesCVLayout())
    self.cv.contentInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    cv.backgroundColor = UIColor.systemBackground
    cv.delegate = self
    cv.dataSource = self
    cv.register(HostingCell.self, forCellWithReuseIdentifier: HostingCell.reuseID)
    cv.alwaysBounceVertical = true
    cv.keyboardDismissMode = .interactive
    view.addSubview(cv)
    cv.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      cv.topAnchor.constraint(equalTo: view.topAnchor),
      cv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      cv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      cv.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
    ])

    let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    tap.cancelsTouchesInView = false
    cv.addGestureRecognizer(tap)

    view.addSubview(scrollToBottomButton)
    scrollToBottomButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scrollToBottomButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      scrollToBottomButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -20),
      scrollToBottomButton.widthAnchor.constraint(equalToConstant: 40),
      scrollToBottomButton.heightAnchor.constraint(equalToConstant: 40)
    ])

    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

    observationTask = Task { @MainActor [weak self] in
      guard let self else { return }
      var lastCount = self.store.messages.count
      var lastTyping = self.store.isResponding
      var lastText: String? = self.store.messages.last?.text
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(100))
        let count = self.store.messages.count
        let typing = self.store.isResponding
        let currentLastText = self.store.messages.last?.text
        if count != lastCount || typing != lastTyping || currentLastText != lastText {
          lastCount = count
          lastTyping = typing
          lastText = currentLastText
          self.applySnapshot(animated: true)
        }
      }
    }

    applySnapshot(animated: false)
  }

  deinit {
    observationTask?.cancel()
    NotificationCenter.default.removeObserver(self)
  }

  func applySnapshot(animated: Bool) {
    let newItems: [ChatCVItem] = store.messages.map { .message($0.id) } + (store.isResponding ? [.typing] : [])
    let wasNearBottom = isNearBottom
    let shouldAnimate = animated && !store.isStreaming
    if newItems != items {
      items = newItems
      cv.reloadData()
      cv.layoutIfNeeded()
    } else {
      // Still need to handle streaming text size changes — invalidate layout
      cv.collectionViewLayout.invalidateLayout()
    }
    if wasNearBottom, let last = newItems.last {
      DispatchQueue.main.async {
        self.scrollToItem(last, animated: shouldAnimate)
      }
    }
  }

  private func scrollToItem(_ item: ChatCVItem, animated: Bool) {
    guard let index = items.firstIndex(of: item) else { return }
    let indexPath = IndexPath(item: index, section: 0)
    guard indexPath.item < cv.numberOfItems(inSection: 0) else { return }
    cv.scrollToItem(at: indexPath, at: .bottom, animated: animated)
  }

  @objc private func scrollToBottomTapped() {
    let count = cv.numberOfItems(inSection: 0)
    guard count > 0 else { return }
    cv.scrollToItem(at: IndexPath(item: count - 1, section: 0), at: .bottom, animated: true)
  }

  func withScrollToBottomDisabled(_ block: (_ enable: @escaping () -> Void) -> Void) {
    scrollToBottomButton.isHidden = true
    tempButtonDisable = true
    block { self.tempButtonDisable = false }
  }

  @objc private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }

  @objc private func keyboardWillHide(_ notification: Notification) {
    guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
          let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
    UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve << 16)) {
      self.view.layoutIfNeeded()
    }
  }

  private func distanceFromBottom(minY: CGFloat, viewSize: CGFloat, contentSize: CGFloat) -> CGFloat {
    let insetBottom = cv.adjustedContentInset.bottom
    let maxY = minY + viewSize
    return (contentSize - maxY) + insetBottom
  }

  private func preserveBottomOffset() {
    let newViewSize = cv.bounds.height
    defer { previousViewSize = newViewSize }
    guard newViewSize > 0, newViewSize != previousViewSize else { return }
    guard !cv.isDragging && !cv.isTracking else { return }
    let contentSize = cv.contentSize.height
    let minY = cv.contentOffset.y
    let oldDistance = distanceFromBottom(minY: minY, viewSize: previousViewSize, contentSize: contentSize)
    let newDistance = distanceFromBottom(minY: minY, viewSize: newViewSize, contentSize: contentSize)
    if newDistance < 1 || oldDistance - newDistance == 0 { return }
    let newMinY = minY - (oldDistance - newDistance)
    cv.setContentOffset(CGPoint(x: cv.contentOffset.x, y: newMinY), animated: false)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    preserveBottomOffset()
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    coordinator.animate(alongsideTransition: { _ in self.cv.collectionViewLayout.invalidateLayout() })
  }
}

// MARK: - UICollectionViewDataSource & Delegate (Haven parity)

extension ChatMessagesVC: UICollectionViewDataSource {
  func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    items.count
  }
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HostingCell.reuseID, for: indexPath) as! HostingCell
    let item = items[indexPath.item]
    switch item {
    case .message(let id):
      if let _ = store.messages.first(where: { $0.id == id }) {
        cell.hostSwiftUI(MessageRow(messageId: id, store: store))
      } else {
        cell.hostSwiftUI(EmptyView())
      }
    case .typing:
      cell.hostSwiftUI(TypingIndicator(tint: appColor))
    }
    return cell
  }
}

extension ChatMessagesVC: ChatMessagesCVLayoutDelegate, UICollectionViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let distFromBottom = distanceFromBottom(minY: scrollView.contentOffset.y, viewSize: scrollView.bounds.height, contentSize: scrollView.contentSize.height)
    isNearBottom = distFromBottom < 1
    let shouldShowButton = distFromBottom > 60
    let shouldHideButton = !shouldShowButton || tempButtonDisable
    if scrollToBottomButton.isHidden != shouldHideButton {
      UIView.animate(withDuration: 0.2) {
        self.scrollToBottomButton.isHidden = shouldHideButton
        self.scrollToBottomButton.alpha = shouldHideButton ? 0 : 1
      }
    }
  }

  func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let width = collectionView.cvAvailableWidth()
    guard indexPath.item < items.count else { return CGSize(width: width, height: 80) }
    let item = items[indexPath.item]
    let targetWidth = width
    switch item {
    case .message(let id):
      guard store.messages.first(where: { $0.id == id }) != nil else { return CGSize(width: width, height: 60) }
      let view = MessageRow(messageId: id, store: store).frame(width: targetWidth)
      let hosting = UIHostingController(rootView: view)
      hosting.view.translatesAutoresizingMaskIntoConstraints = false
      let size = hosting.sizeThatFits(in: CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height))
      return CGSize(width: width, height: max(60, size.height))
    case .typing:
      return CGSize(width: width, height: 40)
    }
  }

  func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, alignForItemAt indexPath: IndexPath) -> ChatCVAlign {
    guard indexPath.item < items.count else { return .center }
    let item = items[indexPath.item]
    switch item {
    case .message(let id):
      guard let msg = store.messages.first(where: { $0.id == id }) else { return .center }
      return msg.role == .user ? .right : .left
    case .typing:
      return .left
    }
  }

  func prepareDone() {}
}

// MARK: - Hosting cell

private final class HostingCell: UICollectionViewCell {
  static let reuseID = "HostingCell"
  private var hosting: UIView?
  func host(_ view: UIView) {
    hosting?.removeFromSuperview()
    hosting = view
    contentView.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: contentView.topAnchor),
      view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    ])
  }
  func hostSwiftUI<V: View>(_ view: V) {
    let controller = UIHostingController(rootView: view)
    controller.view.backgroundColor = .clear
    host(controller.view)
  }
  override func prepareForReuse() {
    super.prepareForReuse()
    hosting?.removeFromSuperview()
    hosting = nil
  }
}
