//
//  ChatMessagesVC.swift
//  Pi Dev
//
//  Custom UICollectionView-based chat list — ported from Haven's
//  ChatMessages+Controller.swift (iOS 17.2) and adapted for ChatStore/ChatMessage.
//  Uses Haven's ChatMessagesCVLayout (per-item align + vertical stack) and
//  measures SwiftUI rows at the collection width so text wraps instead of
//  overflowing. Composer/keyboard insets are owned by SwiftUI.
//

import SwiftUI
import UIKit

/// Collection view is a full-screen UIKit representable. Hit-test the SwiftUI
/// header (and other non-list subviews) first; pass the header band through
/// so an overlay header can still receive taps.
private final class HeaderPassthroughView: UIView {
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

private final class StatusBarScrimView: UIView {
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

final class ChatMessagesVC: UIViewController {
  var store: ChatStore
  private var observationTask: Task<Void, Never>?
  var items: [ChatCVItem] = []
  var itemsCountForLayout: Int { items.count }
  func itemForLayout(at index: Int) -> ChatCVItem { items[index] }

  private(set) var isNearBottom: Bool = true
  var tempButtonDisable = true
  private var previousViewSize: CGFloat = 0
  private var lastMeasuredWidth: CGFloat = 0
  private var heightCache: [UUID: (signature: Int, height: CGFloat)] = [:]
  private var headerHost: UIHostingController<Header>?
  private var headerTopConstraint: NSLayoutConstraint?
  private var statusBarBlurHeight: NSLayoutConstraint?
  private let headerBand: CGFloat = 72
  private let statusBarFadeExtra: CGFloat = 100

  private let statusBarBlur: StatusBarScrimView = {
    let scrim = StatusBarScrimView()
    scrim.layer.zPosition = 1000
    return scrim
  }()

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
    self.cv.contentInset = UIEdgeInsets(top: 72, left: 16, bottom: 40, right: 16)
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) { fatalError() }

  override func loadView() {
    let root = HeaderPassthroughView()
    root.backgroundColor = .clear
    view = root
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    cv.backgroundColor = .clear
    view.backgroundColor = .clear
    cv.delegate = self
    cv.dataSource = self
    cv.register(HostingCell.self, forCellWithReuseIdentifier: HostingCell.reuseID)
    cv.alwaysBounceVertical = true
    cv.keyboardDismissMode = .interactive
    cv.clipsToBounds = true
    view.clipsToBounds = true
    cv.alwaysBounceHorizontal = false
    view.addSubview(cv)
    cv.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      cv.topAnchor.constraint(equalTo: view.topAnchor),
      cv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      cv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      cv.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    view.addSubview(statusBarBlur)
    statusBarBlur.translatesAutoresizingMaskIntoConstraints = false
    let blurHeight = statusBarBlur.heightAnchor.constraint(equalToConstant: 0)
    statusBarBlurHeight = blurHeight
    NSLayoutConstraint.activate([
      statusBarBlur.topAnchor.constraint(equalTo: view.topAnchor),
      statusBarBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      statusBarBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      blurHeight
    ])

    let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    tap.cancelsTouchesInView = false
    cv.addGestureRecognizer(tap)

    view.addSubview(scrollToBottomButton)
    scrollToBottomButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scrollToBottomButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      scrollToBottomButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
      scrollToBottomButton.widthAnchor.constraint(equalToConstant: 40),
      scrollToBottomButton.heightAnchor.constraint(equalToConstant: 40)
    ])

    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

    observationTask = Task { @MainActor [weak self] in
      guard let self else { return }
      var lastCount = self.store.messages.count
      var lastTyping = self.store.isResponding
      var lastText: String? = self.store.messages.last?.text
      var lastStreaming = self.store.messages.last?.isStreaming
      var lastGenerating = self.store.generatingMessageId
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(100))
        let count = self.store.messages.count
        let typing = self.store.isResponding
        let currentLastText = self.store.messages.last?.text
        let streaming = self.store.messages.last?.isStreaming
        let generating = self.store.generatingMessageId
        if count != lastCount || typing != lastTyping || currentLastText != lastText
          || streaming != lastStreaming || generating != lastGenerating {
          lastCount = count
          lastTyping = typing
          lastText = currentLastText
          lastStreaming = streaming
          lastGenerating = generating
          self.applySnapshot(animated: true)
        }
      }
    }

    applySnapshot(animated: false)
  }

  func installHeader(_ header: Header) {
    if let headerHost {
      headerHost.rootView = header
      view.bringSubviewToFront(headerHost.view)
      return
    }
    let host = UIHostingController(rootView: header)
    host.view.backgroundColor = .clear
    host.safeAreaRegions = []
    addChild(host)
    view.addSubview(host.view)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    let top = host.view.topAnchor.constraint(equalTo: view.topAnchor, constant: view.safeAreaInsets.top)
    headerTopConstraint = top
    NSLayoutConstraint.activate([
      top,
      host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])
    host.view.layer.zPosition = 1001
    host.didMove(toParent: self)
    headerHost = host
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
    store.cancelEditIfUnchanged()
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
    updateTopChrome()
    let width = cv.cvAvailableWidth()
    if width > 0, abs(width - lastMeasuredWidth) > 0.5 {
      lastMeasuredWidth = width
      heightCache.removeAll()
      cv.collectionViewLayout.invalidateLayout()
    }
    preserveBottomOffset()
  }

  private var statusBarOverlap: CGFloat {
    guard let window = view.window else { return 0 }
    let viewTopInWindow = view.convert(CGPoint.zero, to: window).y
    return max(0, window.safeAreaInsets.top - viewTopInWindow)
  }

  private func updateTopChrome() {
    let overlap = statusBarOverlap
    let topInset = overlap + headerBand
    headerTopConstraint?.constant = overlap
    statusBarBlurHeight?.constant = overlap + statusBarFadeExtra
    statusBarBlur.setHoldThenFade(holdHeight: overlap, fadeHeight: statusBarFadeExtra)
    if abs(cv.contentInset.top - topInset) > 0.5 {
      var inset = cv.contentInset
      inset.top = topInset
      cv.contentInset = inset
      cv.verticalScrollIndicatorInsets.top = topInset
    }
    if let root = view as? HeaderPassthroughView {
      root.passthroughHeight = topInset
    }
    view.bringSubviewToFront(statusBarBlur)
    if let headerView = headerHost?.view {
      view.bringSubviewToFront(headerView)
    }
    view.bringSubviewToFront(scrollToBottomButton)
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    coordinator.animate(alongsideTransition: { _ in
      self.heightCache.removeAll()
      self.cv.collectionViewLayout.invalidateLayout()
    })
  }

  private func contentSignature(for message: ChatMessage) -> Int {
    var hasher = Hasher()
    hasher.combine(message.text.count)
    hasher.combine(message.thinking?.full.count ?? 0)
    hasher.combine(message.thinking?.summary.count ?? 0)
    hasher.combine(message.tools.count)
    hasher.combine(message.segments.count)
    hasher.combine(message.error != nil)
    hasher.combine(message.isStreaming)
    hasher.combine(message.id == store.messages.last?.id)
    hasher.combine(store.generatingMessageId == nil)
    return hasher.finalize()
  }

  private func measureHeight<V: View>(of view: V, width: CGFloat) -> CGFloat {
    let config = UIHostingConfiguration {
      view
        .frame(width: width, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }
    .margins(.all, 0)
    let content = config.makeContentView()
    let size = content.systemLayoutSizeFitting(
      CGSize(width: width, height: 0),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )
    return max(1, ceil(size.height))
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
    let width = collectionView.cvAvailableWidth()
    let item = items[indexPath.item]
    switch item {
    case .message(let id):
      if store.messages.contains(where: { $0.id == id }) {
        cell.hostSwiftUI(MessageRow(messageId: id, store: store), width: width)
      } else {
        cell.hostSwiftUI(EmptyView(), width: width)
      }
    case .typing:
      cell.hostSwiftUI(TypingIndicator(tint: appColor), width: width)
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
      let height = measureHeight(of: MessageRow(messageId: id, store: store), width: width)
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

// MARK: - Self-sizing hosting cell

private final class HostingCell: UICollectionViewCell {
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
