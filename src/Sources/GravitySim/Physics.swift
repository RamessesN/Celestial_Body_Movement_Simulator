import Foundation
import simd

// MARK: - 固定轨道(行星)

struct Orbit {
    var radius: Float          // 场景单位
    var period: TimeInterval   // 秒/圈(演示周期)
    var phase: Float           // 初始角度(弧度)
}

// MARK: - 天体

struct Body {
    var position: SIMD3<Float>              // 场景单位,1 单位 = 1000 m
    var velocity: SIMD3<Float>              // 场景单位/秒(dt 积分)
    var mass: Double                        // kg
    var density: Double                     // kg/m³
    var color: (Float, Float, Float, Float) // RGBA
    var glow: Bool                          // 发光(恒星)
    var isInitializing: Bool = false
    var isLaunched: Bool = false
    var isFixed: Bool = false               // 太阳: 不移动,只提供引力
    var visualRadius: Float? = nil          // 显式视觉半径;nil 时用质量/密度公式
    var orbit: Orbit?                       // 非 nil = 行星: 固定轨迹绕原点旋转
    var orbitAngle: Float = 0               // 当前轨道角(弧度)
    var textureName: String? = nil          // 漫反射纹理文件名(不含扩展名)
    var normalName: String? = nil           // 法线贴图文件名(不含扩展名)

    init(position: SIMD3<Float>, velocity: SIMD3<Float>, mass: Double, density: Double,
         color: (Float, Float, Float, Float), glow: Bool = false,
         isInitializing: Bool = false, isLaunched: Bool = false,
         isFixed: Bool = false, visualRadius: Float? = nil, orbit: Orbit? = nil,
         textureName: String? = nil, normalName: String? = nil) {
        self.position = position
        self.velocity = velocity
        self.mass = mass
        self.density = density
        self.color = color
        self.glow = glow
        self.isInitializing = isInitializing
        self.isLaunched = isLaunched
        self.isFixed = isFixed
        self.visualRadius = visualRadius
        self.orbit = orbit
        self.orbitAngle = orbit?.phase ?? 0
        self.textureName = textureName
        self.normalName = normalName
    }
}

// MARK: - 物理引擎

@MainActor
final class SimulationEngine {
    static let G = 6.6743e-11                     // m³ kg⁻¹ s⁻²
    static let c = 299_792_458.0                  // m/s
    static let sizeRatio: Float = 30_000          // 质量/密度公式的半径缩放

    var bodies: [Body]
    var paused = false

    init(bodies: [Body]) {
        self.bodies = bodies
    }

    /// 半径: 优先显式 visualRadius;否则 r = (3m/(4πρ))^(1/3) / sizeRatio
    func radius(for body: Body) -> Float {
        if let vr = body.visualRadius { return vr }
        return Float(pow(3.0 * body.mass / body.density / (4.0 * .pi), 1.0 / 3.0)) / Self.sizeRatio
    }

    /// 推进一帧。
    /// - 行星(orbit != nil): 固定轨迹绕原点旋转,不参与引力
    /// - 太阳(isFixed): 不移动,但对普通天体提供引力
    /// - 普通天体: 受引力驱动(dt 积分,修正原版 /94 /96 帧率耦合)
    func step(dt: TimeInterval) {
        guard !paused, dt > 0 else { return }
        let dtf = Float(dt)

        // 受引力驱动的普通天体
        let movers = bodies.indices.filter {
            bodies[$0].isLaunched && !bodies[$0].isInitializing && !bodies[$0].isFixed && bodies[$0].orbit == nil
        }
        // 引力源: 太阳 + 普通天体;行星(orbit)质量相对太阳可忽略,忽略其引力
        let attractors = bodies.indices.filter {
            bodies[$0].isLaunched && !bodies[$0].isInitializing && bodies[$0].orbit == nil
        }

        // 1) 引力 → 速度
        for i in movers {
            var acc = SIMD3<Float>(0, 0, 0)
            for j in attractors where j != i {
                let d = bodies[j].position - bodies[i].position
                let dist = simd_length(d)
                if dist < 1e-6 { continue }
                let distM = Double(dist) * 1000.0        // 场景单位 → 米
                let force = Self.G * bodies[i].mass * bodies[j].mass / (distM * distM)
                acc += (d / dist) * Float(force / bodies[i].mass)
            }
            bodies[i].velocity += acc * dtf
        }

        // 2) 碰撞(普通天体之间,双方对称弹开)
        for a in movers {
            for b in movers where b > a {
                let dist = simd_length(bodies[a].position - bodies[b].position)
                if radius(for: bodies[a]) + radius(for: bodies[b]) > dist {
                    bodies[a].velocity *= -0.2
                    bodies[b].velocity *= -0.2
                }
            }
        }

        // 3) 位置: 普通天体积分;行星走固定轨道
        for i in movers {
            bodies[i].position += bodies[i].velocity * dtf
        }
        for i in bodies.indices {
            guard let orbit = bodies[i].orbit else { continue }
            bodies[i].orbitAngle += Float(2 * Double.pi / orbit.period) * dtf
            let a = bodies[i].orbitAngle
            bodies[i].position = SIMD3(cos(a) * orbit.radius, 0, sin(a) * orbit.radius)
        }
    }
}
