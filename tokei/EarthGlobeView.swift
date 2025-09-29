import SceneKit
import SwiftUI

// MARK: - City Data Model
struct City {
  let name: String
  let latitude: Double
  let longitude: Double
  let population: Int  // in millions

  var color: UIColor {
    // Color based on population size
    if population > 10 {
      return .systemRed
    } else if population > 5 {
      return .systemOrange
    } else {
      return .systemYellow
    }
  }
}

// MARK: - Main Earth Globe View
struct EarthGlobeView: View {
  @State private var scene: SCNScene?
  @State private var cameraNode: SCNNode?

  // Major world cities with coordinates
  let cities: [City] = [
    City(name: "Tokyo", latitude: 35.6762, longitude: 139.6503, population: 14),
    City(name: "Delhi", latitude: 28.7041, longitude: 77.1025, population: 32),
    City(name: "Shanghai", latitude: 31.2304, longitude: 121.4737, population: 24),
    City(name: "São Paulo", latitude: -23.5505, longitude: -46.6333, population: 22),
    City(name: "Mexico City", latitude: 19.4326, longitude: -99.1332, population: 22),
    City(name: "Cairo", latitude: 30.0444, longitude: 31.2357, population: 21),
    City(name: "Mumbai", latitude: 19.0760, longitude: 72.8777, population: 20),
    City(name: "Beijing", latitude: 39.9042, longitude: 116.4074, population: 21),
    City(name: "Dhaka", latitude: 23.8103, longitude: 90.4125, population: 21),
    City(name: "Osaka", latitude: 34.6937, longitude: 135.5023, population: 19),
    City(name: "New York", latitude: 40.7128, longitude: -74.0060, population: 8),
    City(name: "London", latitude: 51.5074, longitude: -0.1278, population: 9),
    City(name: "Paris", latitude: 48.8566, longitude: 2.3522, population: 11),
    City(name: "Moscow", latitude: 55.7558, longitude: 37.6173, population: 12),
    City(name: "Los Angeles", latitude: 34.0522, longitude: -118.2437, population: 4),
    City(name: "Buenos Aires", latitude: -34.6037, longitude: -58.3816, population: 15),
    City(name: "Istanbul", latitude: 41.0082, longitude: 28.9784, population: 15),
    City(name: "Lagos", latitude: 6.5244, longitude: 3.3792, population: 14),
    City(name: "Bangkok", latitude: 13.7563, longitude: 100.5018, population: 10),
    City(name: "Sydney", latitude: -33.8688, longitude: 151.2093, population: 5),
  ]

  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea()

      SceneView(
        scene: scene,
        pointOfView: cameraNode,
        options: [.allowsCameraControl, .autoenablesDefaultLighting]
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black)
    }
    .onAppear {
      setupEarthScene()
    }
    .ignoresSafeArea()
  }

  // MARK: - Scene Setup
  private func setupEarthScene() {
    if scene != nil {
      return
    }

    let scene = SCNScene()
    scene.background.contents = createSpaceBackground()

    // Earth Node
    let earthGeometry = SCNSphere(radius: 1.0)
    earthGeometry.segmentCount = 100  // Higher quality sphere
    let earthNode = SCNNode(geometry: earthGeometry)

    // Earth Materials with realistic textures
    let earthMaterial = SCNMaterial()
    if let dayTexture = UIImage(named: "EarthDay") {
      earthMaterial.diffuse.contents = dayTexture
    } else {
      earthMaterial.diffuse.contents = UIColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1.0)
    }
    earthMaterial.specular.contents = UIColor.white.withAlphaComponent(0.5)
    earthMaterial.shininess = 0.1

    if let nightTexture = UIImage(named: "EarthNight") {
      earthMaterial.emission.contents = nightTexture
      earthMaterial.emission.intensity = 0.5
    } else {
      earthMaterial.emission.contents = UIColor.black
      earthMaterial.emission.intensity = 0.4
    }
    earthMaterial.lightingModel = .phong

    earthGeometry.materials = [earthMaterial]

    // Atmosphere Glow
    let atmosphereGeometry = SCNSphere(radius: 1.1)
    atmosphereGeometry.segmentCount = 100
    let atmosphereNode = SCNNode(geometry: atmosphereGeometry)

    let atmosphereMaterial = SCNMaterial()
    atmosphereMaterial.diffuse.contents = UIColor.clear
    atmosphereMaterial.emission.contents = UIColor.cyan.withAlphaComponent(0.1)
    atmosphereMaterial.emission.intensity = 0.5
    atmosphereMaterial.isDoubleSided = true
    atmosphereMaterial.cullMode = .front
    atmosphereMaterial.blendMode = .add
    atmosphereGeometry.materials = [atmosphereMaterial]

    // Camera Setup
    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.camera?.fieldOfView = 60
    cameraNode.camera?.zNear = 0.1
    cameraNode.camera?.zFar = 100
    cameraNode.position = SCNVector3(0, 0, 3)

    // Sun Light (Directional)
    let sunNode = SCNNode()
    sunNode.light = SCNLight()
    sunNode.light?.type = .directional
    sunNode.light?.intensity = 1200
    sunNode.light?.color = UIColor.white
    sunNode.light?.castsShadow = true
    sunNode.position = SCNVector3(5, 3, 2)
    sunNode.look(at: SCNVector3(0, 0, 0))

    // Ambient Light
    let ambientLightNode = SCNNode()
    ambientLightNode.light = SCNLight()
    ambientLightNode.light?.type = .ambient
    ambientLightNode.light?.intensity = 200
    ambientLightNode.light?.color = UIColor(white: 0.3, alpha: 1.0)

    // Add nodes to scene
    scene.rootNode.addChildNode(earthNode)
    scene.rootNode.addChildNode(atmosphereNode)
    scene.rootNode.addChildNode(cameraNode)
    scene.rootNode.addChildNode(sunNode)
    scene.rootNode.addChildNode(ambientLightNode)

    // Add city markers
    addCityMarkers(to: earthNode)

    // Animations
    let earthRotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 120)
    let repeatEarthRotation = SCNAction.repeatForever(earthRotation)
    earthNode.runAction(repeatEarthRotation)

    // Sun orbit for day/night cycle
    let sunOrbit = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 60)
    let repeatSunOrbit = SCNAction.repeatForever(sunOrbit)
    sunNode.runAction(repeatSunOrbit, forKey: "sunOrbit")

    // Store references
    self.scene = scene
    self.cameraNode = cameraNode
  }

  // MARK: - City Markers
  private func addCityMarkers(to earthNode: SCNNode) {
    for city in cities {
      let markerNode = createCityMarker(for: city)
      earthNode.addChildNode(markerNode)
    }
  }

  private func createCityMarker(for city: City) -> SCNNode {
    // Convert lat/lon to 3D coordinates
    let position = latLonToPosition(lat: city.latitude, lon: city.longitude, radius: 1.01)

    // Create marker sphere
    let markerGeometry = SCNSphere(radius: 0.01)
    let markerNode = SCNNode(geometry: markerGeometry)
    markerNode.position = position
    markerNode.name = city.name

    // Marker material with glow effect
    let material = SCNMaterial()
    material.diffuse.contents = city.color
    material.emission.contents = city.color
    material.emission.intensity = 2.0
    markerGeometry.materials = [material]

    // Add pulse animation
    let scaleUp = SCNAction.scale(to: 1.5, duration: 0.5)
    let scaleDown = SCNAction.scale(to: 1.0, duration: 0.5)
    let pulse = SCNAction.sequence([scaleUp, scaleDown])
    let repeatPulse = SCNAction.repeatForever(pulse)
    markerNode.runAction(repeatPulse)

    // Add label
    let textGeometry = SCNText(string: city.name, extrusionDepth: 0.01)
    textGeometry.font = UIFont.systemFont(ofSize: 0.05)
    textGeometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue
    textGeometry.firstMaterial?.diffuse.contents = UIColor.white
    textGeometry.firstMaterial?.emission.contents = UIColor.white
    textGeometry.firstMaterial?.emission.intensity = 0.5

    let textNode = SCNNode(geometry: textGeometry)
    textNode.position = SCNVector3(0, 0.02, 0)
    textNode.scale = SCNVector3(0.003, 0.003, 0.003)

    // Billboard constraint to always face camera
    let billboardConstraint = SCNBillboardConstraint()
    billboardConstraint.freeAxes = .all
    textNode.constraints = [billboardConstraint]

    markerNode.addChildNode(textNode)

    return markerNode
  }

  // MARK: - Coordinate Conversion
  private func latLonToPosition(lat: Double, lon: Double, radius: Double) -> SCNVector3 {
    let latRad = lat * Double.pi / 180.0
    let lonRad = lon * Double.pi / 180.0

    let x = Float(radius * cos(latRad) * cos(lonRad))
    let y = Float(radius * sin(latRad))
    let z = Float(radius * cos(latRad) * sin(lonRad))

    return SCNVector3(x, y, z)
  }

  // MARK: - Texture Generation (Fallbacks)
  private func createSpaceBackground() -> UIImage {
    let size = CGSize(width: 1024, height: 1024)
    let renderer = UIGraphicsImageRenderer(size: size)

    return renderer.image { context in
      // Black space background
      context.cgContext.setFillColor(UIColor.black.cgColor)
      context.cgContext.fill(CGRect(origin: .zero, size: size))

      // Add stars
      for _ in 0..<500 {
        let x = CGFloat.random(in: 0..<size.width)
        let y = CGFloat.random(in: 0..<size.height)
        let starSize = CGFloat.random(in: 0.5..<2.0)
        let brightness = CGFloat.random(in: 0.3..<1.0)

        context.cgContext.setFillColor(UIColor(white: brightness, alpha: 1.0).cgColor)
        context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: starSize, height: starSize))
      }
    }
  }
}

// MARK: - Preview
#Preview {
  EarthGlobeView()
    .ignoresSafeArea()
}
