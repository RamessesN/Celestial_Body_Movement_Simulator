import SceneKit
import simd

/// Orbit 相机: 围绕目标点(默认太阳)旋转 / 缩放 / 平移。
/// 交互: 左键拖拽 = 上下左右旋转视角,滚轮 = 缩放,中键拖拽 = 平移,
///       WASD / Space / Shift = 平移。
@MainActor
final class CameraController {
    var target = SIMD3<Float>(0, 0, 0)      // 围绕的目标点
    var distance: Float = 9000
    var yaw: Float = 45                     // 方位角(度)
    var pitch: Float = 35                   // 俯仰角(度)

    private let up = SIMD3<Float>(0, 1, 0)
    private let rotateSpeed: Float = 0.15   // 度/像素
    private let minDistance: Float = 300
    private let maxDistance: Float = 80_000

    /// 相机方向向量(目标 → 相机),球坐标
    private func direction() -> SIMD3<Float> {
        let y = yaw * .pi / 180
        let p = pitch * .pi / 180
        return SIMD3(cos(p) * sin(y), sin(p), cos(p) * cos(y))
    }

    /// 左键拖拽: 上下左右旋转
    func rotate(dx: Float, dy: Float) {
        yaw -= dx * rotateSpeed
        pitch += dy * rotateSpeed
        pitch = min(max(pitch, -89), 89)
    }

    /// 中键拖拽: 沿屏幕平面平移
    func pan(dx: Float, dy: Float) {
        let dir = direction()
        let right = simd_normalize(simd_cross(dir, up))
        let camUp = simd_normalize(simd_cross(right, dir))
        let scale = distance * 0.0015
        target -= right * dx * scale
        target += camUp * dy * scale
    }

    /// 滚轮: 缩放
    func zoom(dy: CGFloat) {
        let factor: Float = dy > 0 ? 0.9 : 1.1
        distance = min(max(distance * factor, minDistance), maxDistance)
    }

    /// WASD / Space / Shift 平移,速度随距离缩放
    func apply(dt: Float, input: InputController) {
        let dir = direction()
        let right = simd_normalize(simd_cross(dir, up))
        let forwardH = simd_normalize(SIMD3(dir.x, 0, dir.z))   // 水平前向
        let speed = distance * 0.4

        if input.isDown(InputController.KeyCode.w)     { target += forwardH * speed * dt }
        if input.isDown(InputController.KeyCode.s)     { target -= forwardH * speed * dt }
        if input.isDown(InputController.KeyCode.a)     { target -= right * speed * dt }
        if input.isDown(InputController.KeyCode.d)     { target += right * speed * dt }
        if input.isDown(InputController.KeyCode.space) { target += up * speed * dt }
        if input.isDown(InputController.KeyCode.shift) { target -= up * speed * dt }
    }

    func look(cameraNode: SCNNode) {
        let dir = direction()
        cameraNode.position = SCNVector3(target + dir * distance)
        cameraNode.look(at: SCNVector3(target),
                        up: SCNVector3(up),
                        localFront: SCNVector3(0, 0, -1))
    }
}
