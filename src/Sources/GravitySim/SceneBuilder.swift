import SceneKit
import AppKit

/// 场景搭建: 黑色背景 / 灯光 / 相机 / 网格 / 天体节点。
/// 天体节点由 SimulationRenderer 统一按 bodies 数量创建。
@MainActor
enum SceneBuilder {

    /// 太阳系演示: 居中太阳(发光、固定) + 八大行星(固定轨道绕太阳转)
    static func initialBodies() -> [Body] {
        let sun = Body(position: .zero, velocity: .zero,
                       mass: 5e24, density: 1408,
                       color: (1.0, 0.85, 0.25, 1.0), glow: true,
                       isLaunched: true, isFixed: true, visualRadius: 130,
                       textureName: "sun")

        // (名称, 轨道半径, 演示周期s, 初始相位, 视觉半径, 颜色, 质量kg)
        let planets: [(String, Float, TimeInterval, Float, Float, (Float, Float, Float, Float), Double)] = [
            ("Mercury",  800,  6,  0.0, 12, (0.62, 0.58, 0.50, 1), 3.30e21),
            ("Venus",   1100,  9,  1.2, 20, (0.90, 0.83, 0.55, 1), 4.80e22),
            ("Earth",   1500, 12,  2.5, 22, (0.30, 0.52, 0.95, 1), 5.97e22),
            ("Mars",    1900, 16,  3.9, 15, (0.87, 0.38, 0.23, 1), 6.42e21),
            ("Jupiter", 2600, 26,  1.8, 55, (0.91, 0.67, 0.42, 1), 1.00e24),
            ("Saturn",  3300, 38,  0.6, 46, (0.86, 0.76, 0.57, 1), 3.00e23),
            ("Uranus",  4200, 55,  4.2, 28, (0.55, 0.85, 0.90, 1), 5.00e22),
            ("Neptune", 5000, 72,  3.0, 27, (0.25, 0.35, 0.90, 1), 6.00e22),
        ]

        let bodies = planets.map { p in
            Body(position: SIMD3(cos(p.3) * p.1, 0, sin(p.3) * p.1), velocity: .zero,
                 mass: p.6, density: 5515, color: p.5,
                 isLaunched: true, visualRadius: p.4,
                 orbit: Orbit(radius: p.1, period: p.2, phase: p.3),
                 textureName: p.0.lowercased(),
                 normalName: p.0 == "Earth" ? "earth_normal" : nil)
        }
        return [sun] + bodies
    }

    /// 从资源 bundle 加载图片
    private static func loadImage(_ name: String, extensions: [String]) -> NSImage? {
        for ext in extensions {
            guard let url = Bundle.module.url(forResource: name, withExtension: ext) else { continue }
            if let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }

    static func makeBodyNode(for body: Body, engine: SimulationEngine) -> SCNNode {
        let sphere = SCNSphere(radius: CGFloat(engine.radius(for: body)))
        sphere.segmentCount = 96          // 纹理细节需要更高分段

        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: CGFloat(body.color.0),
                                       green: CGFloat(body.color.1),
                                       blue: CGFloat(body.color.2),
                                       alpha: CGFloat(body.color.3))
        // 应用真实纹理(加载失败则退回纯色)
        if let textureName = body.textureName,
           let img = loadImage(textureName, extensions: ["jpg", "png"]) {
            mat.diffuse.contents = img
        }
        if let normalName = body.normalName,
           let img = loadImage(normalName, extensions: ["tif", "tiff", "jpg", "png"]) {
            mat.normal.contents = img
        }
        if body.glow {
            // 太阳: 纹理自发光
            mat.emission.contents = mat.diffuse.contents
            mat.emission.intensity = 1.0
            mat.lightingModel = .blinn
        }
        sphere.materials = [mat]

        let node = SCNNode(geometry: sphere)
        node.simdPosition = body.position
        return node
    }

    static func makeScene(engine: SimulationEngine) -> (scene: SCNScene, cameraNode: SCNNode, gridNode: SCNNode) {
        let scene = SCNScene()

        // 黑色背景
        scene.background.contents = NSColor.black

        // 相机(orbit: 由 CameraController 每帧设置位置/朝向)
        let camera = SCNCamera()
        camera.fieldOfView = 45
        camera.zNear = 1
        camera.zFar = 400_000
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 4000, 8000)
        scene.rootNode.addChildNode(cameraNode)

        // 环境光(微弱,SceneKit 无光默认全黑)
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(white: 0.25, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // 太阳处点光源,照亮行星
        let sun = SCNLight()
        sun.type = .omni
        sun.color = NSColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)
        sun.attenuationStartDistance = 500
        sun.attenuationEndDistance = 12_000
        sun.attenuationFalloffExponent = 1
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(sunNode)

        // 网格
        let grid = GridMesh()
        let gridNode = SCNNode(geometry: grid.makeGeometry(bodies: engine.bodies))
        scene.rootNode.addChildNode(gridNode)

        return (scene, cameraNode, gridNode)
    }
}
