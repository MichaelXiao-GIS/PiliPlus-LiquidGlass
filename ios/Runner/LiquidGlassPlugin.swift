import Flutter
import UIKit

/// Small, local bridge: Flutter owns routing; UIKit owns the glass material.
final class LiquidGlassPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private let geometry = GlassGeometryView()
  private let hostProvider: () -> UIView?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "piliplus/liquid_glass", binaryMessenger: registrar.messenger()
    )
    // The implicit engine registers plugins before its view controller exists.
    let plugin = LiquidGlassPlugin(channel: channel) { [weak registrar] in
      registrar?.viewController?.view
    }
    registrar.addMethodCallDelegate(plugin, channel: channel)
    registrar.register(
      GlassViewFactory(messenger: registrar.messenger(), navigation: false,
                       onCreate: { plugin.attachGeometry() }),
      withId: "piliplus/glass_surface"
    )
    registrar.register(
      GlassViewFactory(messenger: registrar.messenger(), navigation: true,
                       onCreate: { plugin.attachGeometry() }),
      withId: "piliplus/glass_navigation"
    )
  }

  private init(channel: FlutterMethodChannel, hostProvider: @escaping () -> UIView?) {
    self.channel = channel
    self.hostProvider = hostProvider
    super.init()
    geometry.isUserInteractionEnabled = false
    geometry.accessibilityElementsHidden = true
    geometry.backgroundColor = .clear
    geometry.onChange = { [weak self] snapshot in
      self?.channel.invokeMethod("layoutChanged", arguments: snapshot)
    }
    attachGeometry()
    NotificationCenter.default.addObserver(
      self, selector: #selector(attachGeometry),
      name: UIApplication.didBecomeActiveNotification, object: nil
    )
    for name in [
      UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      UIAccessibility.reduceMotionStatusDidChangeNotification,
      UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
    ] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(accessibilityChanged), name: name, object: nil
      )
    }
  }

  deinit { NotificationCenter.default.removeObserver(self) }

  @objc private func attachGeometry() {
    guard let host = hostProvider() else { return }
    if geometry.superview !== host {
      geometry.frame = host.bounds
      geometry.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      host.addSubview(geometry)
    }
  }

  @objc private func accessibilityChanged() {
    channel.invokeMethod("accessibilityChanged", arguments: nil)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "capabilities" else {
      result(FlutterMethodNotImplemented)
      return
    }
    attachGeometry()
    let nativeGlass: Bool
    if #available(iOS 26.0, *) { nativeGlass = true } else { nativeGlass = false }
    result([
      "nativeGlass": nativeGlass,
      "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
      "reduceMotion": UIAccessibility.isReduceMotionEnabled,
      "window": geometry.snapshot(),
    ])
  }
}

/// Uses the Flutter view's window, never a global screen or device model name.
private final class GlassGeometryView: UIView {
  var onChange: (([String: Any]) -> Void)?
  private var previous: NSDictionary?

  override init(frame: CGRect) {
    super.init(frame: frame)
    if #available(iOS 17.0, *) {
      registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) {
        (view: GlassGeometryView, _: UITraitCollection) in view.publish()
      }
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func didMoveToWindow() { super.didMoveToWindow(); publish() }
  override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); publish() }
  override func layoutSubviews() { super.layoutSubviews(); publish() }

  @available(iOS 26.0, *)
  override func updateProperties() { super.updateProperties(); publish() }

  func snapshot() -> [String: Any] {
    var regions: [[String: Any]] = []
    if #available(iOS 27.1, *) {
      for (kind, name) in [(UIView.ReservedRegion.Kind.division, "division"), (.occlusion, "occlusion")] {
        for region in reservedRegions(kind: kind) where !region.frame.isEmpty {
          regions.append([
            "kind": name, "x": region.frame.minX, "y": region.frame.minY,
            "width": region.frame.width, "height": region.frame.height,
          ])
        }
      }
    }
    return [
      "width": bounds.width, "height": bounds.height,
      "scale": traitCollection.displayScale,
      "horizontalSizeClass": traitCollection.horizontalSizeClass.rawValue,
      "verticalSizeClass": traitCollection.verticalSizeClass.rawValue,
      "safeArea": ["left": safeAreaInsets.left, "top": safeAreaInsets.top,
                   "right": safeAreaInsets.right, "bottom": safeAreaInsets.bottom],
      "regions": regions,
    ]
  }

  private func publish() {
    guard window != nil else { return }
    let data = snapshot()
    let dictionary = data as NSDictionary
    guard previous != dictionary else { return }
    previous = dictionary
    DispatchQueue.main.async { [weak self] in self?.onChange?(data) }
  }
}

private final class GlassViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let navigation: Bool
  private let onCreate: () -> Void

  init(messenger: FlutterBinaryMessenger, navigation: Bool, onCreate: @escaping () -> Void) {
    self.messenger = messenger
    self.navigation = navigation
    self.onCreate = onCreate
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    onCreate()
    return GlassPlatformView(
      frame: frame, id: viewId, args: args as? [String: Any] ?? [:],
      messenger: messenger, navigation: navigation
    )
  }
}

private final class GlassPlatformView: NSObject, FlutterPlatformView {
  private let root = GlassControlView()
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect, id: Int64, args: [String: Any],
    messenger: FlutterBinaryMessenger, navigation: Bool
  ) {
    channel = FlutterMethodChannel(
      name: "piliplus/\(navigation ? "glass_navigation" : "glass_surface")/\(id)",
      binaryMessenger: messenger
    )
    super.init()
    root.frame = frame
    root.isNavigation = navigation
    root.onSelect = { [weak self] index in
      self?.channel.invokeMethod("select", arguments: index)
    }
    root.update(args)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update", let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.root.update(args)
      result(nil)
    }
  }

  deinit { channel.setMethodCallHandler(nil) }

  func view() -> UIView { root }
}

private final class GlassControlView: UIView {
  var isNavigation = false
  var onSelect: ((Int) -> Void)?
  private let material = UIVisualEffectView()
  private let stack = UIStackView()
  private var buttons: [GlassTabButton] = []
  private var arguments: [String: Any] = [:]
  private var radius: CGFloat = 28
  private var materialStyle: String?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    addSubview(material)
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 4
    material.contentView.addSubview(stack)
    NotificationCenter.default.addObserver(
      self, selector: #selector(refreshAccessibility),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil
    )
    NotificationCenter.default.addObserver(
      self, selector: #selector(refreshAccessibility),
      name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification, object: nil
    )
    NotificationCenter.default.addObserver(
      self, selector: #selector(refreshAccessibility),
      name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil
    )
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  deinit { NotificationCenter.default.removeObserver(self) }

  @objc private func refreshAccessibility() { update(arguments) }

  func update(_ args: [String: Any]) {
    arguments = args
    overrideUserInterfaceStyle = args["dark"] as? Bool == true ? .dark : .light
    radius = (args["radius"] as? NSNumber)?.doubleValue ?? 32
    let opaque = UIAccessibility.isReduceTransparencyEnabled ||
      UIAccessibility.isDarkerSystemColorsEnabled
    let interactive = isNavigation && !UIAccessibility.isReduceMotionEnabled
    let style = "\(opaque)-\(interactive)"
    if materialStyle != style {
      materialStyle = style
      if opaque {
        material.effect = nil
        material.backgroundColor = .secondarySystemBackground
        material.layer.borderWidth = 1
        material.layer.borderColor = UIColor.separator.cgColor
      } else {
        material.backgroundColor = .clear
        material.layer.borderWidth = 0
        if #available(iOS 26.0, *) {
          let glass = UIGlassEffect(style: .regular)
          glass.isInteractive = interactive
          material.effect = glass
        } else {
          material.effect = UIBlurEffect(style: .systemMaterial)
        }
      }
    }
    guard isNavigation, let items = args["destinations"] as? [[String: Any]] else {
      setNeedsLayout()
      return
    }
    if buttons.count != items.count {
      for button in buttons { stack.removeArrangedSubview(button); button.removeFromSuperview() }
      buttons = items.indices.map { index in
        let button = GlassTabButton()
        button.tag = index
        button.addTarget(self, action: #selector(selectTab(_:)), for: .touchUpInside)
        stack.addArrangedSubview(button)
        return button
      }
    }
    let selected = args["selectedIndex"] as? Int ?? 0
    let tint = UIColor(argb: (args["tint"] as? NSNumber)?.uint32Value ?? 0xFFFB7299)
    let scale = (args["textScale"] as? NSNumber)?.doubleValue ?? 1
    let compact = (args["compactProgress"] as? NSNumber)?.doubleValue ?? 0
    for (index, item) in items.enumerated() {
      buttons[index].configure(
        title: item["label"] as? String ?? "",
        symbol: item["symbol"] as? String ?? "circle",
        badge: item["badge"] as? String,
        selected: index == selected, tint: tint, textScale: scale,
        compactProgress: compact
      )
    }
    setNeedsLayout()
  }

  @objc private func selectTab(_ sender: UIControl) { onSelect?(sender.tag) }

  override func layoutSubviews() {
    super.layoutSubviews()
    material.frame = bounds
    if #available(iOS 26.0, *) {
      // Describe the shape to the glass renderer instead of masking the final
      // effect. Its refraction and highlight must follow the same contour.
      material.cornerConfiguration = isNavigation ? .capsule() : .capsule(maximumRadius: radius)
      material.clipsToBounds = false
    } else {
      material.layer.cornerRadius = min(radius, bounds.height / 2)
      material.layer.cornerCurve = .circular
      material.clipsToBounds = true
    }
    stack.frame = bounds.insetBy(dx: 5, dy: 5)
  }
}

private final class GlassTabButton: UIControl {
  private let imageView = UIImageView()
  private let label = UILabel()
  private let badgeLabel = UILabel()
  private var compactProgress: CGFloat = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    isAccessibilityElement = true
    imageView.contentMode = .scaleAspectFit
    label.textAlignment = .center
    label.numberOfLines = 1
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.8
    badgeLabel.textAlignment = .center
    badgeLabel.textColor = .white
    badgeLabel.backgroundColor = .systemRed
    badgeLabel.font = .systemFont(ofSize: 10, weight: .semibold)
    badgeLabel.clipsToBounds = true
    addSubview(imageView)
    addSubview(label)
    addSubview(badgeLabel)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func configure(
    title: String, symbol: String, badge: String?, selected: Bool,
    tint: UIColor, textScale: Double, compactProgress: Double
  ) {
    isSelected = selected
    accessibilityLabel = title
    accessibilityTraits = selected ? [.button, .selected] : [.button]
    accessibilityValue = badge.map { $0.isEmpty ? "有未读动态" : "\($0) 条未读动态" }
    label.text = title
    label.font = .systemFont(ofSize: 11 * textScale, weight: .semibold)
    label.textColor = selected ? tint : .label
    self.compactProgress = min(1, max(0, compactProgress))
    label.alpha = 1 - self.compactProgress
    label.isHidden = self.compactProgress >= 1
    imageView.tintColor = selected ? tint : .label
    let selectedSymbol = "\(symbol).fill"
    imageView.image = (selected ? UIImage(systemName: selectedSymbol) : nil) ??
      UIImage(systemName: symbol)
    backgroundColor = selected ? .tertiarySystemFill : .clear
    badgeLabel.isHidden = badge == nil
    badgeLabel.text = badge
    setNeedsLayout()
  }

  override var isHighlighted: Bool {
    didSet {
      alpha = isHighlighted ? 0.65 : 1
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2
    let labelHeight = ceil(label.font.lineHeight)
    let total = 23 + (2 + labelHeight) * (1 - compactProgress)
    let top = max(2, (bounds.height - total) / 2)
    imageView.frame = CGRect(x: (bounds.width - 25) / 2, y: top, width: 25, height: 23)
    label.frame = CGRect(x: 4, y: top + 25, width: max(0, bounds.width - 8), height: labelHeight)
    let dot = badgeLabel.text?.isEmpty != false
    let badgeWidth: CGFloat = dot ? 7 : max(17, badgeLabel.intrinsicContentSize.width + 8)
    let badgeHeight: CGFloat = dot ? 7 : 16
    badgeLabel.frame = CGRect(
      x: bounds.midX + 8, y: max(0, top - 3), width: badgeWidth, height: badgeHeight
    )
    badgeLabel.layer.cornerRadius = badgeHeight / 2
  }
}

private extension UIColor {
  convenience init(argb: UInt32) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }
}
