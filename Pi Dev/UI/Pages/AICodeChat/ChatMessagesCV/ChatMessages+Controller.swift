//
//  ChatMessages+Controller.swift
//  Pi Dev
//

import Observation
import SwiftUI
import UIKit

final class ChatMessagesVC: UIViewController {
  var store: ChatStore
  var items: [ChatCVItem] = []
  var itemsCountForLayout: Int { self.items.count }

  var isNearBottom: Bool = true
  var tempButtonDisable = true
  private var previousViewSize: CGFloat = 0
  private var lastEditingMessageId: UUID?
  private var pendingKeepEditVisible = false
  private var lastMeasuredWidth: CGFloat = 0
  var heightCache: [UUID: (signature: Int, height: CGFloat)] = [:]
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

  lazy var scrollToBottomButton: UIButton = {
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

  func itemForLayout(at index: Int) -> ChatCVItem { self.items[index] }

  override func loadView() {
    let root = HeaderPassthroughView()
    root.backgroundColor = .clear
    view = root
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.makeUI()
    self.startObservation()
    self.applySnapshot(animated: false)
  }

  func makeUI() {
    self.cv.backgroundColor = .clear
    self.view.backgroundColor = .clear
    self.cv.delegate = self
    self.cv.dataSource = self
    self.cv.register(HostingCell.self, forCellWithReuseIdentifier: HostingCell.reuseID)
    self.cv.alwaysBounceVertical = true
    self.cv.keyboardDismissMode = .interactive
    self.cv.clipsToBounds = true
    self.view.clipsToBounds = true
    self.cv.alwaysBounceHorizontal = false
    if #available(iOS 16.0, *) {
      self.cv.selfSizingInvalidation = .disabled
    }
    self.view.addSubview(self.cv)
    self.cv.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      self.cv.topAnchor.constraint(equalTo: self.view.topAnchor),
      self.cv.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      self.cv.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      self.cv.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
    ])

    self.view.addSubview(self.statusBarBlur)
    self.statusBarBlur.translatesAutoresizingMaskIntoConstraints = false
    let blurHeight = self.statusBarBlur.heightAnchor.constraint(equalToConstant: 0)
    self.statusBarBlurHeight = blurHeight
    NSLayoutConstraint.activate([
      self.statusBarBlur.topAnchor.constraint(equalTo: self.view.topAnchor),
      self.statusBarBlur.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      self.statusBarBlur.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      blurHeight
    ])

    let tap = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
    tap.cancelsTouchesInView = false
    self.cv.addGestureRecognizer(tap)

    self.view.addSubview(self.scrollToBottomButton)
    self.scrollToBottomButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      self.scrollToBottomButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20),
      self.scrollToBottomButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -20),
      self.scrollToBottomButton.widthAnchor.constraint(equalToConstant: 40),
      self.scrollToBottomButton.heightAnchor.constraint(equalToConstant: 40)
    ])

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.keyboardWillHide),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )
  }

  func startObservation() {
    self.registerStoreObservation()
  }

  private func registerStoreObservation() {
    withObservationTracking {
      _ = self.store.messages
      _ = self.store.isResponding
      _ = self.store.generatingMessageId
      _ = self.store.expandedToolGroups
      _ = self.store.editingMessageId
    } onChange: { [weak self] in
      DispatchQueue.main.async {
        guard let self else { return }
        self.syncList()
        self.registerStoreObservation()
      }
    }
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
    NotificationCenter.default.removeObserver(self)
  }

  func syncList() {
    self.markEditingMessageIfNeeded()
    self.applySnapshot(animated: true)
  }

  private var lastStreamStructure = 0

  func applySnapshot(animated _: Bool, pinToBottom: Bool = true) {
    let newItems: [ChatCVItem] = store.messages.map { .message($0.id) } + (store.isResponding ? [.typing] : [])
    let wasNearBottom = isNearBottom && !cv.isDragging && !cv.isTracking
    let relayout = {
      if newItems != self.items {
        self.items = newItems
        self.cv.reloadData()
        self.cv.layoutIfNeeded()
      } else {
        self.cv.collectionViewLayout.invalidateLayout()
        self.reconfigureStreamingCellIfNeeded()
        self.cv.layoutIfNeeded()
      }
    }
    UIView.performWithoutAnimation {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      relayout()
      if pinToBottom, wasNearBottom, !newItems.isEmpty {
        self.pinContentToBottom()
      }
      CATransaction.commit()
    }
  }

  private func reconfigureStreamingCellIfNeeded() {
    guard let last = store.messages.last else { return }
    var hasher = Hasher()
    hasher.combine(last.id)
    hasher.combine(last.tools.count)
    hasher.combine(last.segments.count)
    hasher.combine(last.terminal.count)
    hasher.combine(last.thinking != nil)
    hasher.combine(last.error != nil)
    hasher.combine(last.isStreaming)
    let signature = hasher.finalize()
    guard signature != lastStreamStructure else { return }
    lastStreamStructure = signature
    guard let index = items.firstIndex(of: .message(last.id)) else { return }
    let indexPath = IndexPath(item: index, section: 0)
    guard let cell = cv.cellForItem(at: indexPath) as? HostingCell else { return }
    cell.hostSwiftUI(MessageRow(store: store, messageId: last.id), width: cv.cvAvailableWidth())
  }

  private func pinContentToBottom() {
    let inset = cv.adjustedContentInset
    let maxY = max(-inset.top, cv.contentSize.height + inset.bottom - cv.bounds.height)
    cv.setContentOffset(CGPoint(x: cv.contentOffset.x, y: maxY), animated: false)
    isNearBottom = true
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

  func distanceFromBottom(minY: CGFloat, viewSize: CGFloat, contentSize: CGFloat) -> CGFloat {
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

  private func markEditingMessageIfNeeded() {
    let id = store.editingMessageId
    guard id != lastEditingMessageId else { return }
    lastEditingMessageId = id
    cv.isScrollEnabled = id == nil
    pendingKeepEditVisible = id != nil
    if pendingKeepEditVisible {
      view.setNeedsLayout()
    }
  }

  private func keepEditingMessageVisible() {
    guard let id = store.editingMessageId,
          let index = items.firstIndex(of: .message(id)) else { return }
    guard !cv.isDragging && !cv.isTracking else { return }
    let indexPath = IndexPath(item: index, section: 0)
    guard indexPath.item < cv.numberOfItems(inSection: 0),
          let frame = cv.layoutAttributesForItem(at: indexPath)?.frame else { return }

    let inset = cv.adjustedContentInset
    let visibleMinY = cv.contentOffset.y + inset.top
    let visibleMaxY = cv.contentOffset.y + cv.bounds.height - inset.bottom
    let visibleHeight = visibleMaxY - visibleMinY
    guard visibleHeight > 0 else { return }

    var newOffsetY = cv.contentOffset.y
    if frame.height >= visibleHeight - 1 || frame.minY < visibleMinY {
      newOffsetY = frame.minY - inset.top
    } else if frame.maxY > visibleMaxY {
      newOffsetY = frame.maxY + inset.bottom - cv.bounds.height
    } else {
      return
    }

    let minOffset = -inset.top
    let maxOffset = max(minOffset, cv.contentSize.height + inset.bottom - cv.bounds.height)
    newOffsetY = min(max(newOffsetY, minOffset), maxOffset)
    if abs(newOffsetY - cv.contentOffset.y) < 0.5 { return }
    cv.setContentOffset(CGPoint(x: cv.contentOffset.x, y: newOffsetY), animated: false)
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
    let newViewSize = cv.bounds.height
    let sizeChanged = newViewSize > 0 && newViewSize != previousViewSize
    if store.editingMessageId != nil, pendingKeepEditVisible || sizeChanged {
      pendingKeepEditVisible = false
      keepEditingMessageVisible()
      previousViewSize = newViewSize
    } else {
      preserveBottomOffset()
    }
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

  func contentSignature(for message: ChatMessage) -> Int {
    var hasher = Hasher()
    hasher.combine(message.text.count)
    hasher.combine(message.thinking?.full.count ?? 0)
    hasher.combine(message.thinking?.summary.count ?? 0)
    hasher.combine(message.tools.count)
    hasher.combine(message.terminal.count)
    hasher.combine(message.segments.count)
    hasher.combine(message.error != nil)
    hasher.combine(message.isStreaming)
    hasher.combine(message.id == store.messages.last?.id)
    hasher.combine(store.generatingMessageId == nil)
    hasher.combine(self.expandedToolGroups(in: message))
    return hasher.finalize()
  }

  private func expandedToolGroups(in message: ChatMessage) -> Set<UUID> {
    var ids: Set<UUID> = [message.id]
    for tool in message.tools { ids.insert(tool.id) }
    for run in message.terminal { ids.insert(run.id) }
    for segment in message.segments { ids.insert(segment.id) }
    return self.store.expandedToolGroups.intersection(ids)
  }

  func measureHeight<V: View>(of view: V, width: CGFloat) -> CGFloat {
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
