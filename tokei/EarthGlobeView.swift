import CoreLocation
import RealityKit
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
    UIColor(white: 1.0, alpha: 1.0)
  }
}

// MARK: - Globe Controller
final class GlobeController {
  var orbitPivot: Entity?
  var earthEntity: ModelEntity?
  var sunEntity: Entity?
  var earthMaterial: CustomMaterial?
  var usesCustomShader = false

  var cameraAngleX: Float = 0
  var cameraAngleY: Float = 0.15
  var cameraDistance: Float = GlobeController.defaultDistance
  var pinchStartDistance: Float?
  var lastDragTranslation: CGSize = .zero
  var isDragging = false
  var selectedMarkerName: String?
  var loadedMarkerIDs: Set<UUID> = []
  var markerEntities: [UUID: Entity] = [:]

  var velocityX: Float = 0
  var velocityY: Float = 0
  var inertiaTimer: Timer?

  var rotationTimer: Timer?
  var resetAnimationTimer: Timer?
  var viewSize: CGSize = .zero
  var cachedGlowTexture: TextureResource?
  var lastSunDir: SIMD3<Float> = .zero
  var currentTimeAngle: Float = 0
  var isSceneReady = false
  var pendingTimeZones: [TimeZoneInfo]?
  var onSceneReady: (() -> Void)?

  static let defaultDistance: Float = 3.0
  let earthRadius: Float = 1.0
  let minDistance: Float = 2.4
  let maxDistance: Float = 3.6
  let maxVerticalAngle: Float = 1.2
  let friction: Float = 0.92
  let minVelocity: Float = 0.0001
  let sceneDepth: Float = -3.0

  // MARK: - Scene Setup
  @MainActor
  func setupScene() async -> Entity {
    let pivot = Entity()
    pivot.name = "orbitPivot"
    pivot.position = SIMD3<Float>(0, 0, sceneDepth)

    let earthMesh = MeshResource.generateSphere(radius: earthRadius)

    async let dayLoad = try? TextureResource(named: "EarthDay")
    async let nightLoad = try? TextureResource(named: "EarthNight")
    let dayTexture = await dayLoad
    let nightTexture = await nightLoad

    var earthMat: RealityKit.Material

    if let device = MTLCreateSystemDefaultDevice(),
       let library = device.makeDefaultLibrary()
    {
      do {
        var customMat = try CustomMaterial(
          surfaceShader: CustomMaterial.SurfaceShader(named: "dayNightSurface", in: library),
          lightingModel: .unlit
        )
        if let dayTexture { customMat.baseColor.texture = .init(dayTexture) }
        if let nightTexture { customMat.emissiveColor.texture = .init(nightTexture) }
        customMat.custom.value = SIMD4<Float>(0, 0, 1, 0)
        earthMaterial = customMat
        earthMat = customMat
        usesCustomShader = true
      } catch {
        print("CustomMaterial failed: \(error)")
        earthMat = makePBRFallback(day: dayTexture, night: nightTexture)
      }
    } else {
      print("Metal library unavailable, using PBR fallback")
      earthMat = makePBRFallback(day: dayTexture, night: nightTexture)
    }

    let earth = ModelEntity(mesh: earthMesh, materials: [earthMat])
    earth.name = "earth"

    let atmosphereMesh = MeshResource.generateSphere(radius: earthRadius * 1.015)
    var atmosphereMat = UnlitMaterial()
    atmosphereMat.color.tint = UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.08)
    atmosphereMat.blending = .transparent(opacity: .init(floatLiteral: 1.0))
    atmosphereMat.faceCulling = .front
    let atmosphereEntity = ModelEntity(mesh: atmosphereMesh, materials: [atmosphereMat])
    atmosphereEntity.name = "atmosphere"
    earth.addChild(atmosphereEntity)

    if !usesCustomShader {
      earth.components.set(
        EnvironmentLightingConfigurationComponent(environmentLightingWeight: 0)
      )
      let sun = DirectionalLight()
      sun.light.color = .white
      sun.light.intensity = 12000
      sun.light.isRealWorldProxy = false
      sun.name = "sunLight"
      earth.addChild(sun)
      sunEntity = sun
    }

    pivot.addChild(earth)

    orbitPivot = pivot
    earthEntity = earth

    updateEarthRotation()
    positionCameraForLocalTimezone()
    applyOrbitTransform()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      guard let self else { return }
      self.isSceneReady = true
      if let pending = self.pendingTimeZones {
        self.pendingTimeZones = nil
        self.loadMarkers(for: pending)
      }
      self.onSceneReady?()
    }

    return pivot
  }

  private func makePBRFallback(
    day: TextureResource?, night: TextureResource?
  ) -> PhysicallyBasedMaterial {
    var mat = PhysicallyBasedMaterial()
    if let day { mat.baseColor.texture = .init(day) }
    if let night {
      mat.emissiveColor.texture = .init(night)
      mat.emissiveIntensity = 0.4
    }
    mat.roughness = .init(floatLiteral: 0.8)
    mat.metallic = .init(floatLiteral: 0.0)
    return mat
  }

  // MARK: - Earth Rotation & Sun
  func updateEarthRotation() {
    guard let earthEntity else { return }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let components = calendar.dateComponents([.hour, .minute, .second], from: Date())
    let totalSeconds = Double(components.hour ?? 0) * 3600.0
      + Double(components.minute ?? 0) * 60.0
      + Double(components.second ?? 0)
    let fractionOfDay = totalSeconds / 86400.0
    let angle = Float(fractionOfDay * 2.0 * Double.pi - Double.pi)
    currentTimeAngle = angle

    let tilt = simd_quatf(angle: -0.409, axis: SIMD3<Float>(1, 0, 0))
    let timeRot = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
    earthEntity.transform.rotation = timeRot * tilt

    updateSunDirection()
  }

  func updateSunDirection() {
    let offsetMinutes = UserDefaults.shared.integer(forKey: "time_offset_minutes")
    let adjustedDate = Date().addingTimeInterval(TimeInterval(offsetMinutes * 60))

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: adjustedDate) ?? 1
    let declination = -23.44 * cos((360.0 / 365.0) * (Double(dayOfYear) + 10) * Double.pi / 180.0)

    let comps = calendar.dateComponents([.hour, .minute, .second], from: adjustedDate)
    let totalMinutes = Double(comps.hour ?? 0) * 60.0
      + Double(comps.minute ?? 0)
      + Double(comps.second ?? 0) / 60.0
    let subSolarLon = (720.0 - totalMinutes) * 0.25

    let latRad = declination * Double.pi / 180.0
    let lonRad = subSolarLon * Double.pi / 180.0
    let sx = Float(cos(latRad) * sin(lonRad))
    let sy = Float(sin(latRad))
    let sz = Float(cos(latRad) * cos(lonRad))
    let sunDir = normalize(SIMD3<Float>(sx, sy, sz))

    let delta = simd_length(sunDir - lastSunDir)
    guard delta > 0.001 else { return }
    lastSunDir = sunDir

    if usesCustomShader, var material = earthMaterial {
      material.custom.value = SIMD4<Float>(sunDir.x, sunDir.y, sunDir.z, 0)
      earthMaterial = material
      earthEntity?.model?.materials = [material]
    } else if let sunEntity {
      let lightDir = -sunDir
      sunEntity.transform.rotation = simd_quatf(from: SIMD3<Float>(0, 0, -1), to: lightDir)
    }
  }

  // MARK: - Camera Orbit
  func applyOrbitTransform() {
    guard let orbitPivot else { return }

    let rotY = simd_quatf(angle: -cameraAngleX, axis: SIMD3<Float>(0, 1, 0))
    let rotX = simd_quatf(angle: -cameraAngleY, axis: SIMD3<Float>(1, 0, 0))
    orbitPivot.transform.rotation = rotX * rotY

    let scale = Self.defaultDistance / cameraDistance
    orbitPivot.transform.scale = SIMD3<Float>(repeating: scale)
    orbitPivot.position = SIMD3<Float>(0, 0, sceneDepth)
  }

  func positionCameraForLocalTimezone() {
    var angleX: Float = 0
    if let localCoord = TimeZoneCoordinates.coordinate(for: TimeZone.current.identifier) {
      let lonRad = Float(localCoord.longitude * .pi / 180.0)
      angleX = lonRad + currentTimeAngle
    }

    cameraAngleX = angleX
    cameraAngleY = 0.15
    cameraDistance = Self.defaultDistance
  }

  func resetCamera() {
    stopInertia()

    var targetAngleX: Float = 0
    if let localCoord = TimeZoneCoordinates.coordinate(for: TimeZone.current.identifier) {
      let lonRad = Float(localCoord.longitude * .pi / 180.0)
      targetAngleX = lonRad + currentTimeAngle
    }

    let startAngleX = cameraAngleX
    let startAngleY = cameraAngleY
    let startDistance = cameraDistance
    let endAngleY: Float = 0.15
    let endDistance = Self.defaultDistance
    let duration: Float = 0.8
    let startTime = CACurrentMediaTime()

    resetAnimationTimer?.invalidate()
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
      guard let self else { timer.invalidate(); return }
      let elapsed = Float(CACurrentMediaTime() - startTime)
      let t = min(elapsed / duration, 1.0)
      let eased = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2

      self.cameraAngleX = startAngleX + (targetAngleX - startAngleX) * eased
      self.cameraAngleY = startAngleY + (endAngleY - startAngleY) * eased
      self.cameraDistance = startDistance + (endDistance - startDistance) * eased
      self.applyOrbitTransform()

      if t >= 1.0 {
        timer.invalidate()
        self.resetAnimationTimer = nil
      }
    }
    resetAnimationTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  // MARK: - Drag Handling
  func handleDragChanged(_ translation: CGSize) {
    if lastDragTranslation == .zero && !isDragging {
      stopInertia()
    }

    let totalMovement = hypot(translation.width, translation.height)
    if totalMovement > 15 {
      isDragging = true
    }

    if isDragging {
      let dx = Float(translation.width - lastDragTranslation.width) * 0.005
      let dy = Float(translation.height - lastDragTranslation.height) * 0.005
      lastDragTranslation = translation

      cameraAngleX -= dx
      cameraAngleY += dy
      cameraAngleY = max(-maxVerticalAngle, min(maxVerticalAngle, cameraAngleY))
      applyOrbitTransform()
    }
  }

  func handleDragEnded(velocity: CGSize, tapLocation: CGPoint) {
    if !isDragging {
      handleTap(at: tapLocation)
    } else {
      velocityX = Float(velocity.width) * 0.00004
      velocityY = Float(velocity.height) * 0.00004
      if abs(velocityX) > minVelocity || abs(velocityY) > minVelocity {
        startInertia()
      }
    }
    lastDragTranslation = .zero
    isDragging = false
  }

  // MARK: - Pinch Handling
  let pinchOvershoot: Float = 0.3

  func handlePinchChanged(_ magnification: CGFloat) {
    stopInertia()
    if pinchStartDistance == nil {
      pinchStartDistance = cameraDistance
    }
    let start = pinchStartDistance ?? cameraDistance
    let raw = start / Float(magnification)
    cameraDistance = max(minDistance - pinchOvershoot, min(maxDistance + pinchOvershoot, raw))
    applyOrbitTransform()
  }

  func handlePinchEnded() {
    pinchStartDistance = nil

    let target: Float?
    if cameraDistance < minDistance {
      target = minDistance
    } else if cameraDistance > maxDistance {
      target = maxDistance
    } else {
      target = nil
    }

    guard let target else { return }

    let startDist = cameraDistance
    let duration: Float = 0.35
    let startTime = CACurrentMediaTime()

    resetAnimationTimer?.invalidate()
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
      guard let self else { timer.invalidate(); return }
      let elapsed = Float(CACurrentMediaTime() - startTime)
      let t = min(elapsed / duration, 1.0)
      let eased = 1 - pow(1 - t, 3)

      self.cameraDistance = startDist + (target - startDist) * eased
      self.applyOrbitTransform()

      if t >= 1.0 {
        timer.invalidate()
        self.resetAnimationTimer = nil
      }
    }
    resetAnimationTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  // MARK: - Inertia
  func startInertia() {
    stopInertia()
    inertiaTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) {
      [weak self] _ in
      self?.inertiaStep()
    }
  }

  func stopInertia() {
    inertiaTimer?.invalidate()
    inertiaTimer = nil
  }

  private func inertiaStep() {
    velocityX *= friction
    velocityY *= friction

    if abs(velocityX) < minVelocity && abs(velocityY) < minVelocity {
      stopInertia()
      return
    }

    cameraAngleX -= velocityX
    cameraAngleY += velocityY
    cameraAngleY = max(-maxVerticalAngle, min(maxVerticalAngle, cameraAngleY))
    applyOrbitTransform()
  }

  // MARK: - Tap Detection
  func handleTap(at location: CGPoint) {
    guard let earthEntity else { return }
    guard viewSize.width > 0 && viewSize.height > 0 else { return }

    let fov: Float = 60 * .pi / 180
    let aspect = Float(viewSize.width / viewSize.height)
    let tanHalfFov = tan(fov / 2)

    let globeCenter = earthEntity.position(relativeTo: nil)
    let cameraToGlobe = normalize(-globeCenter)

    var tappedMarkerName: String?
    var minDist: CGFloat = 120

    for (_, entity) in markerEntities {
      if let textEntity = entity.children.first(where: { $0.name == "markerText" }) {
        textEntity.isEnabled = false
      }

      let markerWorldPos = entity.position(relativeTo: nil)
      guard markerWorldPos.z < 0 else { continue }

      let ndcX = markerWorldPos.x / (-markerWorldPos.z * tanHalfFov * aspect)
      let ndcY = markerWorldPos.y / (-markerWorldPos.z * tanHalfFov)

      let screenX = CGFloat((ndcX + 1) / 2) * viewSize.width
      let screenY = CGFloat((1 - ndcY) / 2) * viewSize.height

      let dist = hypot(location.x - screenX, location.y - screenY)
      if dist < minDist {
        let markerDir = normalize(markerWorldPos - globeCenter)
        if dot(markerDir, cameraToGlobe) > 0 {
          minDist = dist
          tappedMarkerName = entity.name
        }
      }
    }

    if let tapped = tappedMarkerName, tapped != selectedMarkerName {
      selectedMarkerName = tapped
      if let markerEntity = markerEntities.values.first(where: { $0.name == tapped }),
         let textEntity = markerEntity.children.first(where: { $0.name == "markerText" })
      {
        textEntity.isEnabled = true
      }
    } else {
      selectedMarkerName = nil
    }
  }

  // MARK: - Markers
  func loadMarkers(for timeZones: [TimeZoneInfo]) {
    guard isSceneReady else {
      pendingTimeZones = timeZones
      return
    }
    let newIDs = Set(timeZones.map(\.id))
    guard newIDs != loadedMarkerIDs else { return }
    guard let earthEntity else { return }

    let removed = loadedMarkerIDs.subtracting(newIDs)
    for id in removed {
      markerEntities[id]?.removeFromParent()
      markerEntities[id] = nil
    }

    let added = newIDs.subtracting(loadedMarkerIDs)
    for info in timeZones where added.contains(info.id) {
      guard let coord = info.coordinate else { continue }
      let marker = CityMarker(info: info, coordinate: coord)
      let entity = createMarkerEntity(for: marker)
      earthEntity.addChild(entity)
      markerEntities[info.id] = entity
    }

    loadedMarkerIDs = newIDs
  }

  private func createMarkerEntity(for marker: CityMarker) -> Entity {
    let position = latLonToPosition(
      lat: marker.latitude, lon: marker.longitude, radiusOffset: 1.025
    )

    let markerMesh = MeshResource.generateSphere(radius: 0.02)
    let markerMat = UnlitMaterial(color: marker.color)
    let markerEntity = ModelEntity(mesh: markerMesh, materials: [markerMat])
    markerEntity.position = position
    markerEntity.name = "marker-\(marker.id.uuidString)"

    let glowEntity = createMarkerGlowEntity()
    markerEntity.addChild(glowEntity)

    let textEntity = createMarkerTextEntity(for: marker)
    textEntity.name = "markerText"
    let outward = normalize(position) * 0.18
    textEntity.position = outward
    textEntity.isEnabled = false
    markerEntity.addChild(textEntity)

    return markerEntity
  }

  private func createMarkerTextEntity(for marker: CityMarker) -> Entity {
    let cityLine = marker.name
    let timeLine = "\(marker.info.formattedTime)  \(marker.info.timeOffset)"

    let cityFont = UIFont.systemFont(ofSize: 64, weight: .semibold)
    let timeFont = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .medium)

    let cityAttrs: [NSAttributedString.Key: Any] = [
      .font: cityFont,
      .foregroundColor: UIColor(white: 1.0, alpha: 0.95),
    ]
    let timeAttrs: [NSAttributedString.Key: Any] = [
      .font: timeFont,
      .foregroundColor: UIColor(white: 0.7, alpha: 1.0),
    ]

    let citySize = (cityLine as NSString).size(withAttributes: cityAttrs)
    let timeSize = (timeLine as NSString).size(withAttributes: timeAttrs)

    let padding: CGFloat = 36
    let lineSpacing: CGFloat = 12
    let textWidth = ceil(max(citySize.width, timeSize.width) + padding * 2)
    let textHeight = ceil(padding + citySize.height + lineSpacing + timeSize.height + padding)

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: textWidth, height: textHeight))
    let textImage = renderer.image { context in
      let ctx = context.cgContext

      let bgRect = CGRect(x: 0, y: 0, width: textWidth, height: textHeight)
      ctx.setFillColor(UIColor(white: 0.1, alpha: 0.85).cgColor)
      let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 24)
      ctx.addPath(bgPath.cgPath)
      ctx.fillPath()

      (cityLine as NSString).draw(at: CGPoint(x: padding, y: padding), withAttributes: cityAttrs)
      (timeLine as NSString).draw(
        at: CGPoint(x: padding, y: padding + citySize.height + lineSpacing),
        withAttributes: timeAttrs
      )
    }

    let planeHeight: Float = 0.22
    let planeWidth = planeHeight * Float(textWidth / textHeight)

    let planeMesh = MeshResource.generatePlane(width: planeWidth, height: planeHeight)
    var planeMat = UnlitMaterial()
    if let cgImage = textImage.cgImage,
       let texture = try? TextureResource(
        image: cgImage, options: .init(semantic: .color)
       )
    {
      planeMat.color.texture = .init(texture)
    }
    planeMat.blending = .transparent(opacity: .init(floatLiteral: 1.0))

    let textEntity = ModelEntity(mesh: planeMesh, materials: [planeMat])
    textEntity.components.set(BillboardComponent())
    return textEntity
  }

  private func getOrCreateGlowTexture() -> TextureResource? {
    if let cached = cachedGlowTexture { return cached }
    let glowImage = EarthGlobeView.makeRadialGradientImage(
      size: CGSize(width: 256, height: 256),
      centerColor: UIColor(white: 1.0, alpha: 0.3),
      edgeColor: UIColor.clear
    )
    if let cgImage = glowImage.cgImage,
       let texture = try? TextureResource(image: cgImage, options: .init(semantic: .color))
    {
      cachedGlowTexture = texture
      return texture
    }
    return nil
  }

  private func createMarkerGlowEntity() -> Entity {
    let planeMesh = MeshResource.generatePlane(width: 0.12, height: 0.12)
    var planeMat = UnlitMaterial()
    if let texture = getOrCreateGlowTexture() {
      planeMat.color.texture = .init(texture)
    }
    planeMat.blending = .transparent(opacity: .init(floatLiteral: 0.3))

    let glowEntity = ModelEntity(mesh: planeMesh, materials: [planeMat])
    glowEntity.components.set(BillboardComponent())
    return glowEntity
  }

  // MARK: - Helpers
  func latLonToPosition(lat: Double, lon: Double, radiusOffset: Double) -> SIMD3<Float> {
    let latRad = lat * Double.pi / 180.0
    let lonRad = lon * Double.pi / 180.0
    let radius = Double(earthRadius) * radiusOffset
    let x = Float(radius * cos(latRad) * sin(lonRad))
    let y = Float(radius * sin(latRad))
    let z = Float(radius * cos(latRad) * cos(lonRad))
    return SIMD3<Float>(x, y, z)
  }

  // MARK: - Observation
  func observeDefaults() {
    if rotationTimer == nil {
      rotationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        self?.updateEarthRotation()
      }
    }
  }

  func forceUpdateSun() {
    lastSunDir = .zero
    updateEarthRotation()
  }

  func teardownObservers() {
    rotationTimer?.invalidate()
    rotationTimer = nil
    resetAnimationTimer?.invalidate()
    resetAnimationTimer = nil
    stopInertia()
  }
}

// MARK: - Main Globe View
struct EarthGlobeView: View {
  let timeZones: [TimeZoneInfo]
  @Binding var cameraResetTrigger: Bool
  @Binding var sunUpdateTrigger: Bool

  @State private var controller = GlobeController()
  @State private var viewSize: CGSize = .zero
  @State private var isGlobeVisible = false

  private static let starfieldImage = makeStarfieldImage(size: CGSize(width: 2048, height: 2048))

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Image(uiImage: Self.starfieldImage)
          .resizable()
          .ignoresSafeArea()

        RealityView { content in
          let root = await controller.setupScene()
          content.add(root)
        } update: { _ in
          controller.loadMarkers(for: timeZones)
        }
        .opacity(isGlobeVisible ? 1 : 0)
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              controller.handleDragChanged(value.translation)
            }
            .onEnded { value in
              controller.handleDragEnded(
                velocity: value.velocity,
                tapLocation: value.location
              )
            }
            .simultaneously(with:
              MagnifyGesture()
                .onChanged { value in
                  controller.handlePinchChanged(value.magnification)
                }
                .onEnded { _ in
                  controller.handlePinchEnded()
                }
            )
        )
      }
      .onAppear {
        let fullSize = CGSize(
          width: geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing,
          height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
        )
        viewSize = fullSize
        controller.viewSize = fullSize
        controller.observeDefaults()
        controller.onSceneReady = {
          withAnimation(.easeIn(duration: 0.8)) {
            isGlobeVisible = true
          }
        }
      }
      .onChange(of: geometry.size) { _, newSize in
        let fullSize = CGSize(
          width: newSize.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing,
          height: newSize.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
        )
        viewSize = fullSize
        controller.viewSize = fullSize
      }
      .onChange(of: cameraResetTrigger) {
        controller.resetCamera()
      }
      .onChange(of: sunUpdateTrigger) {
        controller.forceUpdateSun()
      }
      .onDisappear {
        controller.teardownObservers()
      }
    }
  }

  // MARK: - Static Image Generators
  static func makeStarfieldImage(size: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      let ctx = context.cgContext
      ctx.setFillColor(UIColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1.0).cgColor)
      ctx.fill(CGRect(origin: .zero, size: size))

      var rng = SystemRandomNumberGenerator()
      for _ in 0..<600 {
        let x = CGFloat.random(in: 0..<size.width, using: &rng)
        let y = CGFloat.random(in: 0..<size.height, using: &rng)
        let brightness = CGFloat.random(in: 0.3...1.0, using: &rng)
        let radius = CGFloat.random(in: 0.4...1.2, using: &rng)
        ctx.setFillColor(UIColor(white: brightness, alpha: brightness).cgColor)
        ctx.fillEllipse(
          in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        )
      }
    }
  }

  static func makeRadialGradientImage(
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
      else { return }

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

// MARK: - Preview
#Preview {
  EarthGlobeView(
    timeZones: Array(TimeZoneInfo.defaultTimeZones.prefix(3)),
    cameraResetTrigger: .constant(false),
    sunUpdateTrigger: .constant(false)
  )
  .ignoresSafeArea()
}
