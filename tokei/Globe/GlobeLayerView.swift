import QuartzCore
import UIKit

final class GlobeLayerView: UIView {
    override class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    var renderer: GlobeRenderer? {
        didSet {
            metalLayer.device = renderer?.device
        }
    }

    var frameModel: GlobeFrame? {
        didSet {
            if frameModel != oldValue {
                setNeedsLayout()
            }
        }
    }

    private var metalLayer: CAMetalLayer {
        layer as! CAMetalLayer
    }

    private var reveal: Float = 0
    private var revealStart: CFTimeInterval?
    private var revealLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        metalLayer.pixelFormat = GlobeRenderer.pixelFormat
        metalLayer.framebufferOnly = true
        metalLayer.presentsWithTransaction = true
        metalLayer.isOpaque = true
        metalLayer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        backgroundColor = .black
        isOpaque = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var hasStartedReveal: Bool {
        revealStart != nil
    }

    func startReveal() {
        guard revealStart == nil else { return }
        revealStart = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(stepReveal))
        link.add(to: .main, forMode: .common)
        revealLink = link
    }

    @objc private func stepReveal() {
        guard let revealStart else { return }
        let progress = min((CACurrentMediaTime() - revealStart) / 1.1, 1)
        reveal = Float(progress * progress * (3 - 2 * progress))
        render()
        if progress >= 1 {
            revealLink?.invalidate()
            revealLink = nil
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        render()
    }

    private func render() {
        guard
            let renderer,
            let frameModel,
            let window,
            bounds.width > 0,
            bounds.height > 0,
            UIApplication.shared.applicationState != .background
        else { return }
        let scale = window.screen.scale
        let drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        if metalLayer.drawableSize != drawableSize {
            metalLayer.drawableSize = drawableSize
            metalLayer.contentsScale = scale
        }
        renderer.draw(frameModel, reveal: reveal, scale: scale, to: metalLayer)
    }
}
