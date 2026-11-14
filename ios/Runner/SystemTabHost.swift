import Flutter
import UIKit

/// The system tab container sits above the permanent Flutter root controller.
/// Selecting a destination notifies Dart without detaching its rendering surface.
final class SystemTabHost: UITabBarController, UITabBarControllerDelegate {
  private weak var overlay: TabOverlayView?
  private weak var flutter: FlutterViewController?
  private weak var observingPage: SystemTabPage?
  private weak var restorationMask: CAShapeLayer?
  private var semanticsObservation: NSKeyValueObservation?
  private(set) var nativeTabRailFrame: CGRect?
  private(set) var nativeTabTopInset: CGFloat = 0
  var geometryChanged: (() -> Void)?
  private let didChoose: (Int) -> Void
  private var pages = [String: SystemTabPage]()
  private var orderedIDs: [String] = []

  init(didChoose: @escaping (Int) -> Void) {
    self.didChoose = didChoose
    super.init(nibName: nil, bundle: nil)
    delegate = self
    if #available(iOS 18.0, *) { mode = .tabBar }
    if #available(iOS 26.0, *) { tabBarMinimizeBehavior = .onScrollDown }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  /// The engine's controller stays the root throughout the scene lifetime.
  /// Its permanent child uses the same view hierarchy for system gestures,
  /// accessibility and native controller appearance forwarding.
  func install(in flutter: FlutterViewController) {
    let overlay = TabOverlayView(frame: flutter.view.bounds)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.controller = self
    overlay.layer.zPosition = 1
    flutter.addChild(self)
    overlay.addSubview(view)
    view.backgroundColor = .clear
    view.frame = overlay.bounds
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    flutter.view.addSubview(overlay)
    didMove(toParent: flutter)
    self.overlay = overlay
    self.flutter = flutter
    connectScrollGesture()
    // Flutter publishes its semantics container lazily and replaces it when
    // accessibility is enabled again. Preserve that container as element zero.
    semanticsObservation = flutter.view.observe(\.accessibilityElements, options: [.initial, .new]) {
      [weak self] _, _ in self?.includeSystemAccessibility()
    }
    view.setNeedsLayout()
  }

  private func includeSystemAccessibility() {
    guard let root = flutter?.viewIfLoaded, let overlay, var elements = root.accessibilityElements else { return }
    let listed = elements.contains { ($0 as? UIView) === overlay }
    if overlay.isHidden && listed {
      elements.removeAll { ($0 as? UIView) === overlay }
    } else if !overlay.isHidden && !listed {
      elements.append(overlay)
    } else {
      return
    }
    root.accessibilityElements = elements
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateBarGeometry()
  }

  private func updateBarGeometry() {
    guard let flutter, let overlay, let window = overlay.window else { return }
    var top: CGFloat = 0
    if !overlay.isHidden && traitCollection.userInterfaceIdiom == .pad {
      let rootTop = flutter.view.convert(flutter.view.bounds, to: window).minY
      let barFrame = tabBar.convert(tabBar.bounds, to: window)
      if !barFrame.isEmpty && barFrame.maxY < window.bounds.midY && barFrame.maxY > rootTop {
        top = barFrame.maxY - rootTop
      } else if #available(iOS 26.0, *), !contentLayoutGuide.layoutFrame.isEmpty {
        let guide = view.convert(contentLayoutGuide.layoutFrame, to: window)
        if guide.minY > window.safeAreaInsets.top && guide.minY < window.bounds.midY {
          top = max(0, guide.minY - rootTop)
        }
      }
    }
    var rail: CGRect?
    if #available(iOS 27.1, *), !overlay.isHidden, !isTabBarHidden,
       traitCollection.verticalBarEdge != .unspecified {
      rail = verticalRailFrame(in: window)
    }
    guard abs(top - nativeTabTopInset) > 0.5 || rail != nativeTabRailFrame else { return }
    nativeTabTopInset = top
    nativeTabRailFrame = rail
    geometryChanged?()
  }

  @available(iOS 27.1, *)
  private func verticalRailFrame(in window: UIWindow) -> CGRect? {
    // The public tabBar can span the entire reserved side lane. Find the
    // nearest common container of the visible destination buttons instead.
    // This uses UIView geometry and semantics without depending on UIKit's
    // internal view classes or the thickness of its material border.
    let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
    let left = (traitCollection.verticalBarEdge == .leading) != rtl
    let count = orderedIDs.count
    guard count > 1 else { return nil }
    var rail: CGRect?
    func inspect(_ node: UIView) -> Set<CGFloat> {
      guard !node.isHidden, node.alpha > 0.01 else { return [] }
      let frame = node.convert(node.bounds, to: window)
      let onSide = (frame.midX < window.bounds.midX) == left
      var centers = Set<CGFloat>()
      for child in node.subviews { centers.formUnion(inspect(child)) }
      if centers.isEmpty, !frame.isEmpty, onSide,
         node is UIControl || node.accessibilityTraits.contains(.button) {
        centers.insert(frame.midY)
      }
      if centers.count == count, onSide, frame.height > frame.width,
         !frame.isEmpty, window.bounds.contains(frame),
         frame.width < (rail?.width ?? .greatestFiniteMagnitude) {
        rail = frame
      }
      return centers
    }
    _ = inspect(view)
    return rail
  }

  private func prepare(_ args: [String: Any]) -> Bool {
    guard let items = args["destinations"] as? [[String: Any]], !items.isEmpty else { return false }
    let ids = items.compactMap { $0["id"] as? String }
    guard ids.count == items.count, Set(ids).count == ids.count,
          let index = args["selectedIndex"] as? Int, ids.indices.contains(index) else { return false }
    var next = [String: SystemTabPage]()
    for (id, item) in zip(ids, items) {
      let page = pages[id] ?? SystemTabPage()
      let name = item["symbol"] as? String ?? "circle"
      let button: UITabBarItem = page.tabBarItem
      button.title = item["title"] as? String
      let data = (item["avatar"] as? FlutterStandardTypedData)?.data
      if let avatar = page.avatar.image(for: data) {
        button.image = avatar
        button.selectedImage = avatar
      } else {
        button.image = UIImage(systemName: name)
        button.selectedImage = UIImage(systemName: item["selectedSymbol"] as? String ?? name)
      }
      button.badgeValue = item["badge"] as? String
      next[id] = page
    }
    if ids != orderedIDs {
      finishRestoration()
      orderedIDs = ids
      pages = next
      setViewControllers(ids.compactMap { next[$0] }, animated: false)
      customizableViewControllers = nil
    }
    return true
  }

  func configure(_ args: [String: Any]) -> Bool {
    let visible = args["visible"] as? Bool == true
    if let items = args["destinations"] as? [[String: Any]], !items.isEmpty {
      guard prepare(args), let index = args["selectedIndex"] as? Int,
            orderedIDs.indices.contains(index), pages[orderedIDs[index]] != nil else { return false }
      if selectedIndex != index {
        finishRestoration()
        selectedIndex = index
      }
    } else if visible {
      return false
    }
    if let argb = (args["tint"] as? NSNumber)?.uint32Value {
      view.tintColor = UIColor(red: CGFloat((argb >> 16) & 255) / 255,
        green: CGFloat((argb >> 8) & 255) / 255, blue: CGFloat(argb & 255) / 255,
        alpha: CGFloat((argb >> 24) & 255) / 255)
    }
    if let dark = args["dark"] as? Bool { tabBar.overrideUserInterfaceStyle = dark ? .dark : .light }
    if #available(iOS 18.0, *) {
      if isTabBarHidden == visible { setTabBarHidden(!visible, animated: false) }
    } else {
      tabBar.isHidden = !visible
      view.setNeedsLayout()
    }
    if !visible { finishRestoration() }
    overlay?.isHidden = !visible
    connectScrollGesture()
    includeSystemAccessibility()
    updateBarGeometry()
    return true
  }

  func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
    guard let page = viewController as? SystemTabPage,
          let index = viewControllers?.firstIndex(of: page) else { return }
    finishRestoration()
    connectScrollGesture()
    didChoose(index)
  }

  /// Give UIKit a physical pan for its minimize/expand interaction. The
  /// recognizer observes Flutter touches without cancelling their delivery.
  private func connectScrollGesture() {
    guard #available(iOS 26.0, *), let flutter, let overlay else { return }
    let next = overlay.isHidden ? nil : selectedViewController as? SystemTabPage
    guard next !== observingPage else { return }
    observingPage?.observeGestures(in: nil)
    next?.observeGestures(in: flutter.view)
    observingPage = next
  }

  func scrollMetrics(_ args: [String: Any]) {
    guard #available(iOS 26.0, *), !isTabBarHidden, let page = selectedViewController as? SystemTabPage,
          orderedIDs.indices.contains(selectedIndex), args["destinationId"] as? String == orderedIDs[selectedIndex],
          let offset = args["offset"] as? Double, let maximum = args["max"] as? Double,
          offset.isFinite, maximum.isFinite else { return }
    // A finger can reverse again while the bar is still unfolding. Keep
    // presenting that animation until it finishes; UIKit owns the next collapse.
    guard page.scrollMetrics(offset: offset, maximum: maximum) else { return }
    guard restorationMask == nil else { return }
    // Changing the policy immediately expands UIKit's bar. Keep its live
    // controls and reveal them from the button the user was looking at.
    let compact = UIAccessibility.isReduceMotionEnabled ? [] : bottomButtons()
    tabBarMinimizeBehavior = .never
    view.layoutIfNeeded()
    if compact.count == 1, let start = compact.first {
      animateRestoration(from: start)
    }
    DispatchQueue.main.async { [weak self] in self?.tabBarMinimizeBehavior = .onScrollDown }
  }

  private func bottomButtons() -> [CGRect] {
    guard traitCollection.userInterfaceIdiom == .phone else { return [] }
    if #available(iOS 27.1, *), traitCollection.verticalBarEdge != .unspecified { return [] }
    let barFrame = tabBar.convert(tabBar.bounds, to: view)
    var buttons = [CGRect]()
    func collect(_ node: UIView) {
      guard !node.isHidden, node.alpha > 0.01 else { return }
      if node is UIControl || node.accessibilityTraits.contains(.button) {
        let rect = node.convert(node.bounds, to: view)
        if !rect.isEmpty, rect.midY > view.bounds.midY, view.bounds.contains(rect),
           barFrame.contains(CGPoint(x: rect.midX, y: rect.midY)), rect.width < barFrame.width,
           rect.height <= barFrame.height {
          if !buttons.contains(where: { abs($0.midX - rect.midX) < 1 }) { buttons.append(rect) }
          return
        }
      }
      node.subviews.forEach(collect)
    }
    collect(view)
    return buttons.sorted { $0.midX < $1.midX }
  }

  private func animateRestoration(from compact: CGRect) {
    let buttons = bottomButtons()
    guard buttons.count == orderedIDs.count, buttons.count > 1,
          buttons.indices.contains(selectedIndex) else { return }
    let index = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
      ? buttons.count - 1 - selectedIndex : selectedIndex
    let selected = buttons[index]
    let dx = compact.midX - selected.midX
    let dy = compact.midY - selected.midY
    let start = compact.offsetBy(dx: -dx, dy: -dy)
    // Include the material rim outside the tappable bounds.
    let end = buttons.reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -10, dy: -10)
    let mask = CAShapeLayer()
    mask.path = UIBezierPath(roundedRect: end, cornerRadius: end.height / 2).cgPath
    let reveal = CABasicAnimation(keyPath: "path")
    reveal.fromValue = UIBezierPath(roundedRect: start, cornerRadius: start.height / 2).cgPath
    reveal.toValue = mask.path
    let slide = CABasicAnimation(keyPath: "position")
    let position = view.layer.position
    slide.fromValue = CGPoint(x: position.x + dx, y: position.y + dy)
    slide.toValue = position
    let duration = 0.25
    let timing = CAMediaTimingFunction(name: .easeOut)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    CATransaction.setCompletionBlock { [weak self] in
      if self?.view.layer.mask === mask { self?.view.layer.mask = nil }
    }
    restorationMask = mask
    view.layer.mask = mask
    reveal.duration = duration
    reveal.timingFunction = timing
    slide.duration = duration
    slide.timingFunction = timing
    mask.add(reveal, forKey: "expand")
    view.layer.add(slide, forKey: "restoreTabPosition")
    CATransaction.commit()
  }

  private func finishRestoration() {
    guard let mask = restorationMask, view.layer.mask === mask else { return }
    view.layer.removeAnimation(forKey: "restoreTabPosition")
    view.layer.mask = nil
    restorationMask = nil
  }

  /// The presentation layer follows the moving controls between display
  /// frames. Route touches only to the visible portion of the live tab bar.
  func hitPointDuringRestoration(_ point: CGPoint, in overlay: UIView) -> CGPoint? {
    guard let mask = restorationMask, view.layer.mask === mask,
          let visible = view.layer.presentation() else { return point }
    let local = overlay.layer.convert(point, to: view.layer)
    let displayed = CGPoint(x: local.x + view.layer.position.x - visible.position.x,
                            y: local.y + view.layer.position.y - visible.position.y)
    if let path = mask.presentation()?.path, !path.contains(displayed) { return nil }
    return view.convert(displayed, to: overlay)
  }
}

/// Only the system tab controls intercept touches. All other touches continue
/// to Flutter, including its platform views and the status-bar tap target.
private final class TabOverlayView: UIView {
  weak var controller: SystemTabHost?

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let controller, !isHidden,
          let location = controller.hitPointDuringRestoration(point, in: self),
          let hit = super.hitTest(location, with: event) else { return nil }
    let bar = controller.tabBar
    if hit.isDescendant(of: bar) { return hit }
    // iPad hosts top tab controls in a separate container. Its destination
    // pages contain no interactive content, so any control hit here belongs
    // to UIKit's navigation chrome. Empty space passes through to Flutter.
    if controller.nativeTabTopInset > 0 && point.y >= safeAreaInsets.top &&
       point.y <= controller.nativeTabTopInset {
      return hit
    }
    var candidate: UIView? = hit
    while let view = candidate, view !== self {
      if view is UIControl || view.accessibilityTraits.contains(.button) { return hit }
      candidate = view.superview
    }
    return nil
  }
}

private final class SystemTabPage: UIViewController {
  private let scroll = UIScrollView()
  private var maximum: CGFloat = 0

  private var directionAnchor: CGFloat = 0
  private var prefersExpanded = true
  let avatar = TabAvatar()

  override func loadView() {
    view = scroll
    scroll.backgroundColor = .clear
    scroll.isOpaque = false
    scroll.isUserInteractionEnabled = false
    scroll.accessibilityElementsHidden = true
    scroll.contentInsetAdjustmentBehavior = .never
    scroll.showsVerticalScrollIndicator = false
    scroll.showsHorizontalScrollIndicator = false
    scroll.scrollsToTop = false
    scroll.bounces = true
    setContentScrollView(scroll, for: .bottom)
  }

  func observeGestures(in target: UIView?) {
    loadViewIfNeeded()
    let pan = scroll.panGestureRecognizer
    pan.cancelsTouchesInView = false
    pan.delaysTouchesBegan = false
    pan.delaysTouchesEnded = false
    (target ?? scroll).addGestureRecognizer(pan)
    pan.isEnabled = target != nil && maximum > 0
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateContentSize()
  }

  private func updateContentSize() {
    let size = CGSize(width: scroll.bounds.width, height: scroll.bounds.height + maximum)
    if scroll.contentSize != size { scroll.contentSize = size }
  }

  func scrollMetrics(offset: CGFloat, maximum: CGFloat) -> Bool {
    // Require deliberate travel between reversals. Ignore subpixel corrections
    // from changing feed height or final settling as a drag slows to a stop.
    let wasExpanded = prefersExpanded
    if offset <= 1 || offset < directionAnchor - 8 {
      prefersExpanded = true
      directionAnchor = offset
    } else if offset > directionAnchor + 8 {
      prefersExpanded = false
      directionAnchor = offset
    }
    self.maximum = max(0, maximum)
    updateContentSize()
    let pan = scroll.panGestureRecognizer
    let enabled = pan.view !== scroll && self.maximum > 0
    if pan.isEnabled != enabled { pan.isEnabled = enabled }
    // The recognizer lives on Flutter's view, so inspect its state as well as
    // UIScrollView's flags. Preserve native tracking and deceleration while
    // the Flutter feed reports its own independent scroll position.
    if pan.state != .began && pan.state != .changed &&
       !scroll.isTracking && !scroll.isDragging && !scroll.isDecelerating {
      let target = min(self.maximum, max(0, offset))
      if scroll.contentOffset.y != target { scroll.contentOffset.y = target }
    }
    return !wasExpanded && prefersExpanded
  }
}

/// Retains the small decoded icon while its account image remains current.
final class TabAvatar {
  private var avatarBytes: Data?
  private var avatar: UIImage?

  func image(for data: Data?) -> UIImage? {
    guard avatarBytes != data else { return avatar }
    avatarBytes = data
    avatar = nil
    guard let data, let source = UIImage(data: data), source.size.width > 0, source.size.height > 0 else { return nil }
    let diameter: CGFloat = 26
    let size = CGSize(width: diameter, height: diameter)
    let zoom = diameter / min(source.size.width, source.size.height)
    let crop = CGRect(x: (diameter - source.size.width * zoom) / 2,
                      y: (diameter - source.size.height * zoom) / 2,
                      width: source.size.width * zoom, height: source.size.height * zoom)
    avatar = UIGraphicsImageRenderer(size: size).image { _ in
      UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
      source.draw(in: crop)
    }.withRenderingMode(.alwaysOriginal)
    return avatar
  }
}
