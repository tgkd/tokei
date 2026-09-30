import SwiftUI
import UIKit

struct PetalDrift: UIViewRepresentable {
    let look: PetalDriftLook
    let isEnabled: Bool

    func makeUIView(context: Context) -> PetalDriftView {
        PetalDriftView(look: look)
    }

    func updateUIView(_ view: PetalDriftView, context: Context) {
        view.isEnabled = isEnabled
    }
}

final class PetalDriftView: UIView {
    private let emitter = CAEmitterLayer()
    private let look: PetalDriftLook

    var isEnabled = true {
        didSet {
            refresh()
        }
    }

    init(look: PetalDriftLook) {
        self.look = look
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        emitter.emitterShape = .line
        emitter.emitterMode = .volume
        emitter.emitterCells = [cell(tip: look.light, base: look.deep, share: 0.6), cell(tip: look.deep, base: look.deep, share: 0.4)]
        layer.addSublayer(emitter)
        NotificationCenter.default.addObserver(self, selector: #selector(conditionsChanged), name: .NSProcessInfoPowerStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(conditionsChanged), name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -8)
        emitter.emitterSize = CGSize(width: bounds.width * 1.4, height: 1)
        CATransaction.commit()
    }

    @objc private func conditionsChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.refresh()
        }
    }

    private func refresh() {
        let info = ProcessInfo.processInfo
        let active = isEnabled && !info.isLowPowerModeEnabled && info.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue
        guard emitter.isHidden == active else { return }
        emitter.isHidden = !active
        emitter.birthRate = active ? 1 : 0
    }

    private func cell(tip: UInt32, base: UInt32, share: Float) -> CAEmitterCell {
        let cell = CAEmitterCell()
        let image = Self.petal(tip: Self.color(tip), base: Self.color(base))
        cell.contents = image.cgImage
        cell.contentsScale = image.scale
        cell.birthRate = look.rate * share
        cell.lifetime = look.lifetime
        cell.lifetimeRange = look.lifetime * 0.2
        cell.velocity = look.speed
        cell.velocityRange = look.speed * 0.3
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 9
        cell.xAcceleration = 1.2
        cell.yAcceleration = 0.6
        cell.spin = 0.5
        cell.spinRange = 3
        cell.scale = 0.75
        cell.scaleRange = 0.35
        cell.alphaRange = 0.3
        cell.alphaSpeed = -0.05
        return cell
    }

    private static func color(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    private static func petal(tip: UIColor, base: UIColor) -> UIImage {
        let size = CGSize(width: 14, height: 10)
        return UIGraphicsImageRenderer(size: size).image { context in
            let width = size.width
            let height = size.height
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0.5, y: height / 2))
            path.addQuadCurve(to: CGPoint(x: width * 0.94, y: height * 0.1), controlPoint: CGPoint(x: width * 0.3, y: -height * 0.15))
            path.addLine(to: CGPoint(x: width * 0.8, y: height / 2))
            path.addLine(to: CGPoint(x: width * 0.94, y: height * 0.9))
            path.addQuadCurve(to: CGPoint(x: 0.5, y: height / 2), controlPoint: CGPoint(x: width * 0.3, y: height * 1.15))
            path.close()
            let graphics = context.cgContext
            graphics.addPath(path.cgPath)
            graphics.clip()
            let colors = [base.cgColor, tip.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 0.8]) {
                graphics.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height / 2), end: CGPoint(x: width, y: height / 2), options: [.drawsAfterEndLocation])
            }
        }
    }
}
