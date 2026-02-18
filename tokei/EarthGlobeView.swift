import CoreLocation
import SceneKit
import SwiftUI
import UIKit

// MARK: - City Marker Model
struct CityMarker: Identifiable {
  let id: UUID
  let info: TimeZoneInfo
  let latitude: Double
  let longitude: Double

  init(info: TimeZoneInfo, coordinate: CLLocationCoordinate2D) {
    self.id = info.id
    self.info = info
    latitude = coordinate.latitude
    longitude = coordinate.longitude
  }

  var name: String { info.cityName }

  var color: UIColor {
    UIColor(white: 0.85, alpha: 1.0)
  }
}

// MARK: - Main Globe View
struct EarthGlobeView: View {
  let timeZones: [TimeZoneInfo]
  @Binding var cameraResetTrigger: Bool

  @State private var scene: SCNScene?
  @State private var cameraNode: SCNNode?
  @State private var earthNode: SCNNode?
  @State private var sunNode: SCNNode?
  @State private var rotationTimer: Timer?
  @State private var userDefaultsObserver: NSObjectProtocol?
  private let earthRadius: CGFloat = 0.8

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      OrbitingSceneView(
        scene: scene,
        cameraNode: cameraNode,
        earthNode: earthNode,
        cameraResetTrigger: cameraResetTrigger
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black)
    }
    .onAppear {
      setupEarthScene()
      observeDefaults()
      loadMarkers(for: timeZones)
      updateEarthRotation()
    }
    .onChange(of: timeZones) { newValue in
      loadMarkers(for: newValue)
    }
    .onDisappear {
      teardownObservers()
    }
  }

  // MARK: - Scene Setup
  private func setupEarthScene() {
    if scene != nil { return }

    let scene = SCNScene()
    scene.background.contents = Self.makeStarfieldImage(size: CGSize(width: 2048, height: 2048))
    scene.fogColor = UIColor.black
    scene.fogStartDistance = 14
    scene.fogEndDistance = 28
    scene.fogDensityExponent = 0.25
    scene.lightingEnvironment.intensity = 1.0

    let earthGeometry = SCNSphere(radius: earthRadius)
    earthGeometry.segmentCount = 220
    let earthNode = SCNNode(geometry: earthGeometry)
    earthNode.eulerAngles.x = -0.35
    earthNode.name = "earth"

    let earthMaterial = SCNMaterial()
    if let dayTexture = UIImage(named: "EarthDay") {
      earthMaterial.diffuse.contents = dayTexture
    } else {
      earthMaterial.diffuse.contents = UIColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 1.0)
    }
    earthMaterial.specular.contents = UIColor.white.withAlphaComponent(0.15)
    earthMaterial.specular.intensity = 0.3
    earthMaterial.shininess = 0.05

    if let nightTexture = UIImage(named: "EarthNight") {
      earthMaterial.emission.contents = nightTexture
      earthMaterial.emission.intensity = 0.5
    } else {
      earthMaterial.emission.contents = UIColor.black
      earthMaterial.emission.intensity = 0.12
    }
    earthMaterial.lightingModel = .physicallyBased
    earthMaterial.roughness.contents = 0.45
    earthMaterial.metalness.contents = 0.04
    earthMaterial.multiply.contents = UIColor(white: 0.85, alpha: 1.0)
    earthGeometry.materials = [earthMaterial]

    let haloNode = createEarthHaloNode(radius: earthRadius * 2.1)
    earthNode.addChildNode(haloNode)

    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.camera?.fieldOfView = 60
    cameraNode.camera?.zNear = 0.1
    cameraNode.camera?.zFar = 120
    cameraNode.camera?.wantsHDR = false
    positionCameraForLocalTimezone(cameraNode: cameraNode, earthNode: earthNode)

    let sunNode = SCNNode()
    sunNode.light = SCNLight()
    sunNode.light?.type = .directional
    sunNode.light?.intensity = 520
    sunNode.light?.color = UIColor(red: 0.95, green: 0.93, blue: 0.9, alpha: 1.0)
    sunNode.light?.castsShadow = true
    sunNode.light?.shadowMode = .deferred
    sunNode.light?.shadowSampleCount = 16
    sunNode.light?.shadowRadius = 14
    sunNode.light?.shadowColor = UIColor.black.withAlphaComponent(0.4)
    sunNode.light?.temperature = 5400
    updateSunPosition(sunNode: sunNode)
    sunNode.addChildNode(createSunHaloNode())

    let ambientLightNode = SCNNode()
    ambientLightNode.light = SCNLight()
    ambientLightNode.light?.type = .ambient
    ambientLightNode.light?.intensity = 140
    ambientLightNode.light?.color = UIColor(red: 0.08, green: 0.14, blue: 0.23, alpha: 1.0)

    let bounceLightNode = SCNNode()
    bounceLightNode.light = SCNLight()
    bounceLightNode.light?.type = .omni
    bounceLightNode.light?.intensity = 30
    bounceLightNode.light?.color = UIColor(red: 0.3, green: 0.4, blue: 0.7, alpha: 1.0)
    bounceLightNode.position = SCNVector3(-4, -1, -3)

    scene.rootNode.addChildNode(earthNode)
    scene.rootNode.addChildNode(cameraNode)
    scene.rootNode.addChildNode(sunNode)
    scene.rootNode.addChildNode(ambientLightNode)
    scene.rootNode.addChildNode(bounceLightNode)

    self.scene = scene
    self.cameraNode = cameraNode
    self.earthNode = earthNode
    self.sunNode = sunNode
  }

  // MARK: - Rotation Sync
  private func updateEarthRotation() {
    guard let earthNode else { return }

    earthNode.removeAction(forKey: "earthRotation")

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let components = calendar.dateComponents([.hour, .minute, .second], from: Date())
    let hours = Double(components.hour ?? 0) * 3600.0
    let minutes = Double(components.minute ?? 0) * 60.0
    let seconds = Double(components.second ?? 0)
    let totalSeconds = hours + minutes + seconds
    let fractionOfDay = totalSeconds / 86400.0

    let angle = Float(fractionOfDay * 2 * Double.pi - Double.pi)

    SCNTransaction.begin()
    SCNTransaction.animationDuration = 0.25
    earthNode.eulerAngles.y = angle
    SCNTransaction.commit()

    if let sunNode {
      updateSunPosition(sunNode: sunNode)
    }

    let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 86400)
    rotation.timingMode = .linear
    earthNode.runAction(.repeatForever(rotation), forKey: "earthRotation")
  }

  private func updateSunPosition(sunNode: SCNNode) {
    let offsetMinutes = UserDefaults.shared.integer(forKey: "time_offset_minutes")
    let adjustedDate = Date().addingTimeInterval(TimeInterval(offsetMinutes * 60))

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: adjustedDate) ?? 1

    let declination = -23.44 * cos((360.0 / 365.0) * (Double(dayOfYear) + 10) * Double.pi / 180.0)
    let declinationRad = declination * Double.pi / 180.0

    let sunAngle = Double(offsetMinutes) / 1440.0 * 2.0 * Double.pi

    let distance: Double = 10.0
    let baseZ = distance * cos(declinationRad)
    let y = Float(distance * sin(declinationRad))
    let x = Float(baseZ * sin(sunAngle))
    let z = Float(baseZ * cos(sunAngle))

    sunNode.position = SCNVector3(x, y, z)
    sunNode.look(at: SCNVector3Zero)
  }

  private func observeDefaults() {
    if rotationTimer == nil {
      rotationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
        updateEarthRotation()
      }
    }

    if userDefaultsObserver == nil {
      userDefaultsObserver = NotificationCenter.default.addObserver(
        forName: UserDefaults.didChangeNotification,
        object: UserDefaults.shared,
        queue: .main
      ) { _ in
        updateEarthRotation()
      }
    }
  }

  private func teardownObservers() {
    rotationTimer?.invalidate()
    rotationTimer = nil

    if let observer = userDefaultsObserver {
      NotificationCenter.default.removeObserver(observer)
      userDefaultsObserver = nil
    }
  }

  private func positionCameraForLocalTimezone(cameraNode: SCNNode, earthNode: SCNNode) {
    let distance: Float = 3.6
    let angleY: Float = 0.15
    var angleX: Float = 0

    if let localCoord = TimeZoneCoordinates.coordinate(for: TimeZone.current.identifier) {
      let lonRad = Float(localCoord.longitude * .pi / 180.0)
      angleX = lonRad + earthNode.eulerAngles.y
    }

    let x = distance * sin(angleX) * cos(angleY)
    let y = distance * sin(angleY)
    let z = distance * cos(angleX) * cos(angleY)
    cameraNode.position = SCNVector3(x, y, z)
    cameraNode.look(at: SCNVector3Zero, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
  }

  // MARK: - Markers
  private func loadMarkers(for timeZones: [TimeZoneInfo]) {
    let markers = timeZones.compactMap { info -> CityMarker? in
      guard let coord = info.coordinate else { return nil }
      return CityMarker(info: info, coordinate: coord)
    }
    updateCityMarkers(with: markers)
  }

  @MainActor
  private func updateCityMarkers(with markers: [CityMarker]) {
    guard let earthNode else { return }

    for node in earthNode.childNodes where node.name?.hasPrefix("marker-") == true {
      node.removeFromParentNode()
    }

    for marker in markers {
      let node = createCityMarker(for: marker)
      earthNode.addChildNode(node)
    }
  }

  private func createCityMarker(for marker: CityMarker) -> SCNNode {
    let position = latLonToPosition(lat: marker.latitude, lon: marker.longitude, radiusOffset: 1.012)

    let markerGeometry = SCNSphere(radius: 0.014)
    markerGeometry.segmentCount = 48
    let markerNode = SCNNode(geometry: markerGeometry)
    markerNode.position = position
    markerNode.name = "marker-\(marker.id.uuidString)"

    let material = SCNMaterial()
    material.diffuse.contents = marker.color
    material.emission.contents = marker.color
    material.emission.intensity = 0.4
    material.lightingModel = .physicallyBased
    markerGeometry.materials = [material]

    markerNode.addChildNode(createMarkerGlowNode(color: marker.color))

    let containerNode = SCNNode()
    containerNode.name = "markerText"
    containerNode.position = SCNVector3(0, 0.04, 0)
    containerNode.scale = SCNVector3(0.015, 0.015, 0.015)
    containerNode.renderingOrder = 100
    containerNode.isHidden = true

    let cityLine = marker.name
    let cityGeometry = SCNText(string: cityLine, extrusionDepth: 0.0)
    cityGeometry.font = UIFont.systemFont(ofSize: 3.0, weight: .semibold)
    cityGeometry.firstMaterial?.diffuse.contents = UIColor(white: 0.15, alpha: 1.0)
    cityGeometry.firstMaterial?.emission.contents = UIColor(white: 0.15, alpha: 1.0)
    cityGeometry.firstMaterial?.emission.intensity = 0.5
    cityGeometry.firstMaterial?.writesToDepthBuffer = false
    cityGeometry.firstMaterial?.readsFromDepthBuffer = false
    cityGeometry.flatness = 0.2
    let cityNode = SCNNode(geometry: cityGeometry)
    cityNode.renderingOrder = 102

    let timeLine = "\(marker.info.formattedTime)  \(marker.info.timeOffset)"
    let timeGeometry = SCNText(string: timeLine, extrusionDepth: 0.0)
    timeGeometry.font = UIFont.monospacedDigitSystemFont(ofSize: 2.2, weight: .medium)
    timeGeometry.firstMaterial?.diffuse.contents = UIColor(white: 0.35, alpha: 1.0)
    timeGeometry.firstMaterial?.emission.contents = UIColor(white: 0.35, alpha: 1.0)
    timeGeometry.firstMaterial?.emission.intensity = 0.4
    timeGeometry.firstMaterial?.writesToDepthBuffer = false
    timeGeometry.firstMaterial?.readsFromDepthBuffer = false
    timeGeometry.flatness = 0.2
    let timeNode = SCNNode(geometry: timeGeometry)
    timeNode.position = SCNVector3(0, -3.2, 0)
    timeNode.renderingOrder = 102

    let cityBounds = cityGeometry.boundingBox
    let timeBounds = timeGeometry.boundingBox
    let contentWidth = max(
      CGFloat(cityBounds.max.x - cityBounds.min.x),
      CGFloat(timeBounds.max.x - timeBounds.min.x)
    )
    let contentTop = CGFloat(cityBounds.max.y)
    let contentBottom = CGFloat(timeBounds.min.y) - 3.2

    let padH: Float = 1.5
    let padV: Float = 1.2
    let bgWidth = contentWidth + CGFloat(padH * 2)
    let bgHeight = CGFloat(contentTop - contentBottom) + CGFloat(padV * 2)
    let bgPlane = SCNPlane(width: bgWidth, height: bgHeight)
    let bgMaterial = SCNMaterial()
    bgMaterial.diffuse.contents = UIColor(white: 1.0, alpha: 0.95)
    bgMaterial.emission.contents = UIColor(white: 0.95, alpha: 0.95)
    bgMaterial.isDoubleSided = true
    bgMaterial.writesToDepthBuffer = false
    bgMaterial.readsFromDepthBuffer = false
    bgPlane.materials = [bgMaterial]
    bgPlane.cornerRadius = 1.5
    let bgNode = SCNNode(geometry: bgPlane)
    let bgCenterX = Float(contentWidth) / 2
    let bgCenterY = Float(contentTop + contentBottom) / 2
    bgNode.position = SCNVector3(bgCenterX, bgCenterY, -0.01)
    bgNode.renderingOrder = 101

    containerNode.addChildNode(bgNode)
    containerNode.addChildNode(cityNode)
    containerNode.addChildNode(timeNode)

    let centerX = Float(contentWidth) / 2
    let centerY = Float(contentTop + contentBottom) / 2
    containerNode.pivot = SCNMatrix4MakeTranslation(centerX, centerY, 0)

    let billboardConstraint = SCNBillboardConstraint()
    billboardConstraint.freeAxes = .all
    containerNode.constraints = [billboardConstraint]

    markerNode.addChildNode(containerNode)

    return markerNode
  }

  // MARK: - Helpers
  private func createEarthHaloNode(radius: CGFloat) -> SCNNode {
    let plane = SCNPlane(width: radius, height: radius)
    let material = SCNMaterial()
    let glowImage = Self.makeRadialGradientImage(
      size: CGSize(width: 512, height: 512),
      centerColor: UIColor(red: 0.15, green: 0.35, blue: 0.7, alpha: 0.1),
      edgeColor: UIColor.clear
    )
    material.diffuse.contents = glowImage
    material.emission.contents = glowImage
    material.isDoubleSided = true
    material.blendMode = .add
    material.writesToDepthBuffer = false
    material.readsFromDepthBuffer = false
    plane.materials = [material]

    let node = SCNNode(geometry: plane)
    let billboard = SCNBillboardConstraint()
    billboard.freeAxes = .all
    node.constraints = [billboard]
    node.opacity = 0.06
    node.renderingOrder = -5
    return node
  }

  private func createSunHaloNode() -> SCNNode {
    let plane = SCNPlane(width: 1.5, height: 1.5)
    let material = SCNMaterial()
    let haloImage = Self.makeRadialGradientImage(
      size: CGSize(width: 400, height: 400),
      centerColor: UIColor(red: 0.9, green: 0.9, blue: 0.85, alpha: 0.3),
      edgeColor: UIColor.clear
    )
    material.diffuse.contents = haloImage
    material.emission.contents = haloImage
    material.isDoubleSided = true
    material.blendMode = .add
    material.writesToDepthBuffer = false
    plane.materials = [material]

    let node = SCNNode(geometry: plane)
    let billboard = SCNBillboardConstraint()
    billboard.freeAxes = .all
    node.constraints = [billboard]
    node.opacity = 0.1
    return node
  }

  private func createMarkerGlowNode(color: UIColor) -> SCNNode {
    let plane = SCNPlane(width: 0.05, height: 0.05)
    let material = SCNMaterial()
    let glowImage = Self.makeRadialGradientImage(
      size: CGSize(width: 256, height: 256),
      centerColor: color.withAlphaComponent(0.3),
      edgeColor: UIColor.clear
    )
    material.diffuse.contents = glowImage
    material.emission.contents = glowImage
    material.isDoubleSided = true
    material.blendMode = .add
    material.writesToDepthBuffer = false
    plane.materials = [material]

    let node = SCNNode(geometry: plane)
    let constraint = SCNBillboardConstraint()
    constraint.freeAxes = .all
    node.constraints = [constraint]
    node.opacity = 0.2
    return node
  }

  private func latLonToPosition(lat: Double, lon: Double, radiusOffset: Double) -> SCNVector3 {
    let latRad = lat * Double.pi / 180.0
    let lonRad = lon * Double.pi / 180.0

    let radius = Double(earthRadius) * radiusOffset
    let x = Float(radius * cos(latRad) * sin(lonRad))
    let y = Float(radius * sin(latRad))
    let z = Float(radius * cos(latRad) * cos(lonRad))

    return SCNVector3(x, y, z)
  }

  private static func makeStarfieldImage(size: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      let ctx = context.cgContext
      ctx.setFillColor(UIColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1.0).cgColor)
      ctx.fill(CGRect(origin: .zero, size: size))

      var rng = SystemRandomNumberGenerator()
      let starCount = 600
      for _ in 0..<starCount {
        let x = CGFloat.random(in: 0..<size.width, using: &rng)
        let y = CGFloat.random(in: 0..<size.height, using: &rng)
        let brightness = CGFloat.random(in: 0.3...1.0, using: &rng)
        let radius = CGFloat.random(in: 0.4...1.2, using: &rng)
        ctx.setFillColor(UIColor(white: brightness, alpha: brightness).cgColor)
        ctx.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
      }
    }
  }

  private static func makeRadialGradientImage(
    size: CGSize,
    centerColor: UIColor,
    edgeColor: UIColor,
    center: CGPoint = CGPoint(x: 0.5, y: 0.5),
    endRadiusMultiplier: CGFloat = 0.6
  ) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      guard
        let gradient = CGGradient(
          colorsSpace: CGColorSpaceCreateDeviceRGB(),
          colors: [centerColor.cgColor, edgeColor.cgColor] as CFArray,
          locations: [0, 1]
        )
      else {
        return
      }

      let centerPoint = CGPoint(x: size.width * center.x, y: size.height * center.y)
      let radius = min(size.width, size.height) * endRadiusMultiplier
      context.cgContext.drawRadialGradient(
        gradient,
        startCenter: centerPoint,
        startRadius: 0,
        endCenter: centerPoint,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
      )
    }
  }

}

// MARK: - Scene View Wrapper
private struct OrbitingSceneView: UIViewRepresentable {
  var scene: SCNScene?
  var cameraNode: SCNNode?
  var earthNode: SCNNode?
  var cameraResetTrigger: Bool

  func makeUIView(context: Context) -> SCNView {
    let view = SCNView()
    view.allowsCameraControl = false
    view.autoenablesDefaultLighting = false
    view.backgroundColor = .clear
    view.antialiasingMode = .multisampling4X

    let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
    view.addGestureRecognizer(pan)

    let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
    view.addGestureRecognizer(pinch)

    let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
    singleTap.numberOfTapsRequired = 1
    view.addGestureRecognizer(singleTap)

    return view
  }

  func updateUIView(_ uiView: SCNView, context: Context) {
    if uiView.scene !== scene {
      uiView.scene = scene
    }
    uiView.pointOfView = cameraNode
    context.coordinator.cameraNode = cameraNode
    context.coordinator.earthNode = earthNode

    if cameraResetTrigger != context.coordinator.lastResetTrigger {
      context.coordinator.lastResetTrigger = cameraResetTrigger
      context.coordinator.resetCamera()
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(cameraNode: cameraNode, earthNode: earthNode)
  }

  final class Coordinator: NSObject {
    var cameraNode: SCNNode?
    var earthNode: SCNNode?
    private var lastPanPoint: CGPoint = .zero
    private var cameraDistance: Float = defaultDistance
    private var cameraAngleX: Float = 0
    private var cameraAngleY: Float = 0

    static let defaultDistance: Float = 3.6
    private let minDistance: Float = 2.7
    private let maxDistance: Float = defaultDistance
    private let maxVerticalAngle: Float = 1.2
    private var selectedMarkerName: String?
    var lastResetTrigger = false

    private var inertiaTimer: CADisplayLink?
    private var velocityX: Float = 0
    private var velocityY: Float = 0
    private let friction: Float = 0.92
    private let minVelocity: Float = 0.0001

    init(cameraNode: SCNNode?, earthNode: SCNNode?) {
      self.cameraNode = cameraNode
      self.earthNode = earthNode
      super.init()
    }

    private func applyCamera() {
      guard let cameraNode else { return }
      let x = cameraDistance * sin(cameraAngleX) * cos(cameraAngleY)
      let y = cameraDistance * sin(cameraAngleY)
      let z = cameraDistance * cos(cameraAngleX) * cos(cameraAngleY)
      cameraNode.position = SCNVector3(x, y, z)
      cameraNode.look(at: SCNVector3Zero, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    }

    private func applyCameraAnimated(duration: TimeInterval = 0.3) {
      guard let cameraNode else { return }
      SCNTransaction.begin()
      SCNTransaction.animationDuration = duration
      SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
      let x = cameraDistance * sin(cameraAngleX) * cos(cameraAngleY)
      let y = cameraDistance * sin(cameraAngleY)
      let z = cameraDistance * cos(cameraAngleX) * cos(cameraAngleY)
      cameraNode.position = SCNVector3(x, y, z)
      cameraNode.look(at: SCNVector3Zero, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
      SCNTransaction.commit()
    }

    private func stopInertia() {
      inertiaTimer?.invalidate()
      inertiaTimer = nil
    }

    @objc private func inertiaStep() {
      velocityX *= friction
      velocityY *= friction

      if abs(velocityX) < minVelocity && abs(velocityY) < minVelocity {
        stopInertia()
        return
      }

      cameraAngleX -= velocityX
      cameraAngleY += velocityY
      cameraAngleY = max(-maxVerticalAngle, min(maxVerticalAngle, cameraAngleY))
      applyCamera()
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
      guard cameraNode != nil else { return }
      let translation = gesture.translation(in: gesture.view)

      if gesture.state == .began {
        stopInertia()
        lastPanPoint = .zero
      }

      let dx = Float(translation.x - lastPanPoint.x) * 0.005
      let dy = Float(translation.y - lastPanPoint.y) * 0.005
      lastPanPoint = CGPoint(x: translation.x, y: translation.y)

      cameraAngleX -= dx
      cameraAngleY += dy
      cameraAngleY = max(-maxVerticalAngle, min(maxVerticalAngle, cameraAngleY))
      applyCamera()

      if gesture.state == .ended {
        let v = gesture.velocity(in: gesture.view)
        velocityX = Float(v.x) * 0.00004
        velocityY = Float(v.y) * 0.00004

        if abs(velocityX) > minVelocity || abs(velocityY) > minVelocity {
          let link = CADisplayLink(target: self, selector: #selector(inertiaStep))
          link.add(to: .main, forMode: .common)
          inertiaTimer = link
        }
      }
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
      guard cameraNode != nil else { return }

      if gesture.state == .changed {
        stopInertia()
        cameraDistance /= Float(gesture.scale)
        cameraDistance = max(minDistance, min(maxDistance, cameraDistance))
        gesture.scale = 1.0
        applyCamera()
      }

      if gesture.state == .ended {
        cameraDistance = max(minDistance, min(maxDistance, cameraDistance))
        applyCameraAnimated(duration: 0.35)
      }
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
      guard let scnView = gesture.view as? SCNView, let earthNode, let cameraNode else { return }
      let location = gesture.location(in: scnView)

      let camPos = cameraNode.presentation.worldPosition
      var tappedMarkerNode: SCNNode?
      var minDist: CGFloat = 44

      for child in earthNode.childNodes where child.name?.hasPrefix("marker-") == true {
        let markerPos = child.presentation.worldPosition
        let dot = camPos.x * markerPos.x + camPos.y * markerPos.y + camPos.z * markerPos.z
        if dot <= 0 { continue }

        let projected = scnView.projectPoint(markerPos)
        let screenPt = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
        let dist = hypot(location.x - screenPt.x, location.y - screenPt.y)
        if dist < minDist {
          minDist = dist
          tappedMarkerNode = child
        }
      }

      for child in earthNode.childNodes where child.name?.hasPrefix("marker-") == true {
        child.childNode(withName: "markerText", recursively: false)?.isHidden = true
      }

      if let tapped = tappedMarkerNode, tapped.name != selectedMarkerName {
        selectedMarkerName = tapped.name
        tapped.childNode(withName: "markerText", recursively: false)?.isHidden = false
      } else {
        selectedMarkerName = nil
      }
    }

    func resetCamera() {
      guard let cameraNode else { return }
      stopInertia()

      var targetAngleX: Float = 0
      if let localCoord = TimeZoneCoordinates.coordinate(for: TimeZone.current.identifier),
         let earthNode {
        let lonRad = Float(localCoord.longitude * .pi / 180.0)
        targetAngleX = lonRad + earthNode.eulerAngles.y
      }

      cameraAngleX = targetAngleX
      cameraAngleY = 0.15
      cameraDistance = Self.defaultDistance

      SCNTransaction.begin()
      SCNTransaction.animationDuration = 0.8
      SCNTransaction.animationTimingFunction = CAMediaTimingFunction(
        controlPoints: 0.25, 1.0, 0.25, 1.0
      )

      let x = cameraDistance * sin(cameraAngleX) * cos(cameraAngleY)
      let y = cameraDistance * sin(cameraAngleY)
      let z = cameraDistance * cos(cameraAngleX) * cos(cameraAngleY)
      cameraNode.position = SCNVector3(x, y, z)
      cameraNode.look(at: SCNVector3Zero, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))

      SCNTransaction.commit()
    }
  }
}


// MARK: - Preview
#Preview {
  EarthGlobeView(timeZones: Array(TimeZoneInfo.defaultTimeZones.prefix(3)), cameraResetTrigger: .constant(false))
    .ignoresSafeArea()
}
