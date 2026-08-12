import AppKit
import SceneKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct GravitySimApp {

    @MainActor
    static func main() {
        // ---- AppKit 引导 ----
        // 局部强引用即可: main() 阻塞在 app.run(),locals 全程存活。
        // NSApplication.delegate 与 SCNView.delegate 都是弱引用,靠这些局部强引用保持。
        let app = NSApplication.shared
        let appDelegate = AppDelegate()
        app.delegate = appDelegate
        app.setActivationPolicy(.regular)          // CLI 启动也能抢焦点 + Dock 图标

        // 窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Gravity Simulation"
        window.acceptsMouseMovedEvents = true      // 必须: 否则 mouseMoved 事件不触发
        window.makeKeyAndOrderFront(nil)

        // SCNView
        let sceneView = SCNView(frame: window.contentView!.bounds)
        sceneView.autoresizingMask = [.width, .height]
        sceneView.allowsCameraControl = false      // 手动相机
        sceneView.rendersContinuously = true       // 必须: 否则 delegate 不每帧回调
        sceneView.preferredFramesPerSecond = 60
        window.contentView?.addSubview(sceneView)

        // 场景 + 引擎 + 输入 + 渲染器
        let engine = SimulationEngine(bodies: SceneBuilder.initialBodies())
        let scene = SceneBuilder.makeScene(engine: engine)
        sceneView.scene = scene.scene
        sceneView.pointOfView = scene.cameraNode

        let input = InputController()
        input.engine = engine
        let camera = CameraController()
        let renderer = SimulationRenderer(engine: engine, input: input, camera: camera,
                                          rootNode: scene.scene.rootNode,
                                          gridNode: scene.gridNode,
                                          cameraNode: scene.cameraNode)
        sceneView.delegate = renderer
        input.install()

        app.activate(ignoringOtherApps: true)      // 把窗口提到终端之前
        app.run()                                  // 阻塞进入 run loop,窗口存活
    }
}
