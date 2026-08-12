import SceneKit
import AppKit
import simd

/// 时空弯曲网格: 平面线框 + 每帧按史瓦西半径弯曲 + 质心垂直位移。
/// 顶点按弯曲高度做热力渐变着色(阱底暖 / 平坦冷),让弯曲形态和行星波动凸显。
@MainActor
final class GridMesh {
    let gridSize: Float = 20_000
    let divisions = 25
    let bendExaggeration: Float = 1.5      // 弯曲放大,让时空阱更明显

    private var baseVertices: [SCNVector3] = []
    private let element: SCNGeometryElement
    private let material: SCNMaterial

    init() {
        let step = gridSize / Float(divisions)    // 800
        let half = gridSize / 2                   // 10000
        // 原版: y = -halfSize*0.3 + 3*step = -600
        let y = -half * 0.3 + 3 * step

        var v: [SCNVector3] = []
        // X 向线段: 26 行(z) × 25 段(x)
        for zStep in 0...divisions {
            let z = -half + Float(zStep) * step
            for xStep in 0..<divisions {
                let x = -half + Float(xStep) * step
                v.append(SCNVector3(x, y, z))
                v.append(SCNVector3(x + step, y, z))
            }
        }
        // Z 向线段: 26 行(x) × 25 段(z)
        for xStep in 0...divisions {
            let x = -half + Float(xStep) * step
            for zStep in 0..<divisions {
                let z = -half + Float(zStep) * step
                v.append(SCNVector3(x, y, z))
                v.append(SCNVector3(x, y, z + step))
            }
        }
        baseVertices = v

        element = SCNGeometryElement(indices: Array(0..<Int32(v.count)), primitiveType: .line)

        material = SCNMaterial()
        material.diffuse.contents = NSColor.white   // 顶点色控制最终颜色
        material.lightingModel = .constant          // 线框不受光照
        material.isDoubleSided = true
        material.transparencyMode = .aOne
        material.writesToDepthBuffer = false
    }

    /// 热力渐变: 冷(蓝)→ 青 → 黄 → 红(阱底)
    private func gradientColor(t: Float) -> SIMD4<Float> {
        let stops: [SIMD4<Float>] = [
            SIMD4(0.15, 0.30, 0.70, 0.35),   // 深蓝
            SIMD4(0.30, 0.75, 1.00, 0.50),   // 亮青
            SIMD4(0.95, 0.85, 0.30, 0.80),   // 金黄
            SIMD4(1.00, 0.35, 0.15, 1.00),   // 红
        ]
        let x = min(max(t, 0), 1) * Float(stops.count - 1)
        let i = min(Int(x), stops.count - 2)
        let f = x - Float(i)
        return stops[i] + (stops[i + 1] - stops[i]) * f
    }

    /// 每帧重建 SCNGeometry(顶点 + 顶点色)。
    /// 颜色按弯曲高度归一化: 越深(越靠近大质量天体)越暖。
    func makeGeometry(bodies: [Body]) -> SCNGeometry {
        // 质心(跳过 initializing),整体垂直位移
        let launched = bodies.filter { !$0.isInitializing }
        let totalMass = launched.reduce(0.0) { $0 + $1.mass }
        let comY: Double = totalMass > 0
            ? launched.reduce(0.0) { $0 + $1.mass * Double($1.position.y) } / totalMass
            : 0
        let originalMaxY = baseVertices.map { Double($0.y) }.max() ?? -600
        let shift = comY - originalMaxY

        var bent = baseVertices
        var heights: [Float] = []
        heights.reserveCapacity(bent.count)

        for i in bent.indices {
            let p = bent[i]
            let px = Float(p.x), py = Float(p.y), pz = Float(p.z)
            var dy: Double = 0
            for b in bodies {
                let dx = Double(b.position.x - px)
                let dyy = Double(b.position.y - py)
                let dz = Double(b.position.z - pz)
                let dist = (dx * dx + dyy * dyy + dz * dz).squareRoot()
                let distM = dist * 1000.0
                let rs = 2.0 * SimulationEngine.G * b.mass / (SimulationEngine.c * SimulationEngine.c)
                let dClamped = max(distM, rs)     // 修正: 防 sqrt 负数 → NaN
                let dzBend = 2.0 * (rs * (dClamped - rs)).squareRoot()
                dy += dzBend * 2.0
            }
            let h = Float(dy) * bendExaggeration - Float(abs(shift))
            bent[i].y = CGFloat(h)
            heights.append(h)
        }

        // 按高度范围归一化: 阱底(最低)→ 1 热,边缘(最高)→ 0 冷
        let minH = heights.min() ?? 0
        let maxH = heights.max() ?? 1
        let range = max(maxH - minH, 1e-6)

        var colors: [SIMD4<Float>] = []
        colors.reserveCapacity(bent.count)
        for h in heights {
            let t = (maxH - h) / range
            colors.append(gradientColor(t: t))
        }

        let posSource = SCNGeometrySource(vertices: bent)
        let colorSource = makeColorSource(colors)
        let geometry = SCNGeometry(sources: [posSource, colorSource], elements: [element])
        geometry.materials = [material]
        return geometry
    }

    private func makeColorSource(_ colors: [SIMD4<Float>]) -> SCNGeometrySource {
        let data = colors.withUnsafeBytes { Data(bytes: $0.baseAddress!, count: $0.count) }
        return SCNGeometrySource(data: data, semantic: .color,
                                 vectorCount: colors.count,
                                 usesFloatComponents: true,
                                 componentsPerVector: 4,
                                 bytesPerComponent: MemoryLayout<Float>.size,
                                 dataOffset: 0,
                                 dataStride: MemoryLayout<SIMD4<Float>>.size)
    }
}
