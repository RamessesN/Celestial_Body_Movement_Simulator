import SceneKit

/// 每帧胶水(SCNSceneRendererDelegate): 相机 / 物理 / 网格 / 天体节点。
/// 依赖 GravitySimApp.swift 里 `rendersContinuously = true` 保证每帧回调。
@MainActor
final class SimulationRenderer: NSObject, @preconcurrency SCNSceneRendererDelegate {
    private let engine: SimulationEngine
    private let input: InputController
    private let camera: CameraController
    private let grid = GridMesh()

    private let rootNode: SCNNode
    private let gridNode: SCNNode
    private let cameraNode: SCNNode
    private var bodyNodes: [SCNNode] = []
    private var lastTime: TimeInterval?

    init(engine: SimulationEngine, input: InputController, camera: CameraController,
         rootNode: SCNNode, gridNode: SCNNode, cameraNode: SCNNode) {
        self.engine = engine
        self.input = input
        self.camera = camera
        self.rootNode = rootNode
        self.gridNode = gridNode
        self.cameraNode = cameraNode
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt: TimeInterval
        if let lt = lastTime {
            dt = min(max(time - lt, 0), 0.1)          // 钳制暂停/恢复尖峰
        } else {
            dt = 0
        }
        lastTime = time
        let dtf = Float(dt)

        // 1) 相机: 左键旋转 / 中键平移 / 滚轮缩放 / WASD 平移
        if input.leftMouseDown {
            camera.rotate(dx: Float(input.mouseDeltaX), dy: Float(input.mouseDeltaY))
        } else if input.middleMouseDown {
            camera.pan(dx: Float(input.mouseDeltaX), dy: Float(input.mouseDeltaY))
        }
        input.mouseDeltaX = 0
        input.mouseDeltaY = 0
        if input.scrollDeltaY != 0 {
            camera.zoom(dy: input.scrollDeltaY)
            input.scrollDeltaY = 0
        }
        camera.apply(dt: dtf, input: input)
        camera.look(cameraNode: cameraNode)

        // 2) 物理(内部尊重 paused)
        engine.step(dt: dt)

        // 3) 网格每帧重建
        gridNode.geometry = grid.makeGeometry(bodies: engine.bodies)

        // 4) 天体节点: 数量不足时自动补建,每帧更新位置与半径
        while bodyNodes.count < engine.bodies.count {
            let idx = bodyNodes.count
            let node = SceneBuilder.makeBodyNode(for: engine.bodies[idx], engine: engine)
            rootNode.addChildNode(node)
            bodyNodes.append(node)
        }
        for (i, body) in engine.bodies.enumerated() {
            let node = bodyNodes[i]
            node.simdPosition = body.position
            if let sphere = node.geometry as? SCNSphere {
                sphere.radius = CGFloat(engine.radius(for: body))
            }
        }
    }
}
