import UIKit

/// Draws a soft circle wherever a finger touches the screen, for screen recordings and demos.
/// It is off unless the app is launched with `-ShowTouches YES`, so normal use never shows it.
///
/// The circles are drawn by the app itself, so they land in a recording at exactly the right
/// time and place. A gesture recogniser on the window watches touches without claiming them,
/// so every button, board square and map gesture works exactly as before.
enum TouchIndicator {
    static var isRequested: Bool { UserDefaults.standard.bool(forKey: "ShowTouches") }

    private static var installed = false

    /// Adds the indicator to the app's window, once. Call it after the window exists (for example from onAppear).
    static func installIfRequested() {
        guard isRequested, !installed else { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard let window else { return }
        installed = true

        let overlay = TouchOverlayView(frame: window.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)

        let watcher = TouchWatcher(overlay: overlay)
        window.addGestureRecognizer(watcher)
    }
}

/// Watches every touch in the window without recognising anything, so it never gets in the way.
private final class TouchWatcher: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private let overlay: TouchOverlayView

    init(overlay: TouchOverlayView) {
        self.overlay = overlay
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        touches.forEach { overlay.began($0) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        touches.forEach { overlay.moved($0) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        touches.forEach { overlay.ended($0) }
        finishIfAllUp(event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        touches.forEach { overlay.ended($0) }
        finishIfAllUp(event)
    }

    /// Never recognises: once every finger is up it fails quietly and resets for the next touch.
    private func finishIfAllUp(_ event: UIEvent) {
        let stillDown = event.allTouches?.contains { $0.phase != .ended && $0.phase != .cancelled } ?? false
        if !stillDown { state = .failed }
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

/// The layer the circles are drawn in. It sits above the app and lets every touch through.
private final class TouchOverlayView: UIView {
    private struct Spot {
        let layer: CALayer
        let start: CFTimeInterval
    }

    private var spots: [ObjectIdentifier: Spot] = [:]
    private let size: CGFloat = 50

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        superview?.bringSubviewToFront(self)
    }

    func began(_ touch: UITouch) {
        superview?.bringSubviewToFront(self)
        let circle = CALayer()
        circle.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        circle.cornerRadius = size / 2
        // A dark translucent fill and shadow show on the light theme; the white rim shows on the dark one.
        circle.backgroundColor = UIColor(white: 0.12, alpha: 0.30).cgColor
        circle.borderColor = UIColor(white: 1, alpha: 0.95).cgColor
        circle.borderWidth = 3
        circle.shadowColor = UIColor.black.cgColor
        circle.shadowOpacity = 0.4
        circle.shadowRadius = 5
        circle.shadowOffset = CGSize(width: 0, height: 2)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        circle.position = touch.location(in: self)
        layer.addSublayer(circle)
        CATransaction.commit()

        // Press in: grows from a smaller circle, like a finger landing.
        let pop = CABasicAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.55
        pop.toValue = 1
        pop.duration = 0.14
        pop.timingFunction = CAMediaTimingFunction(name: .easeOut)
        circle.add(pop, forKey: "pop")

        spots[ObjectIdentifier(touch)] = Spot(layer: circle, start: CACurrentMediaTime())
    }

    func moved(_ touch: UITouch) {
        guard let spot = spots[ObjectIdentifier(touch)] else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spot.layer.position = touch.location(in: self)
        CATransaction.commit()
    }

    func ended(_ touch: UITouch) {
        guard let spot = spots.removeValue(forKey: ObjectIdentifier(touch)) else { return }
        // Quick taps stay on screen long enough to be seen, then grow slightly and fade away.
        let held = CACurrentMediaTime() - spot.start
        let wait = max(0, 0.22 - held)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.35)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            CATransaction.setCompletionBlock { spot.layer.removeFromSuperlayer() }
            spot.layer.opacity = 0
            spot.layer.transform = CATransform3DMakeScale(1.35, 1.35, 1)
            CATransaction.commit()
        }
    }
}
