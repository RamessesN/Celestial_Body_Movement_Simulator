import AppKit

/// 输入收集: NSEvent 本地监听 → 按键集合 / 鼠标按钮 / 拖拽增量 / 滚轮。
/// 渲染循环每帧消费状态,将输入事件率与渲染帧率解耦。
@MainActor
final class InputController {
    enum KeyCode {
        // Carbon virtual key codes (稳定)
        static let a: UInt16 = 0
        static let s: UInt16 = 1
        static let d: UInt16 = 2
        static let q: UInt16 = 12
        static let w: UInt16 = 13
        static let k: UInt16 = 40
        static let space: UInt16 = 49
        static let shift: UInt16 = 56        // 左 Shift
    }

    var engine: SimulationEngine?

    var leftMouseDown = false
    var middleMouseDown = false
    var rightMouseDown = false
    var mouseDeltaX: CGFloat = 0
    var mouseDeltaY: CGFloat = 0
    var scrollDeltaY: CGFloat = 0

    private var keys: Set<UInt16> = []
    private var monitors: [Any?] = []

    func isDown(_ code: UInt16) -> Bool { keys.contains(code) }

    func install() {
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.keyDown(e)
            return e
        })
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] e in
            self?.keys.remove(e.keyCode)
            return e
        })
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp,
                                                                    .rightMouseDown, .rightMouseUp,
                                                                    .otherMouseDown, .otherMouseUp]) { [weak self] e in
            self?.mouseButton(e)
            return e
        })
        // 按住拖动时系统发的是 *.Dragged 事件(非 mouseMoved),必须一并监听
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved,
                                                                    .leftMouseDragged,
                                                                    .rightMouseDragged,
                                                                    .otherMouseDragged]) { [weak self] e in
            self?.mouseMoved(e)
            return e
        })
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
            self?.scrollDeltaY += e.scrollingDeltaY
            return e
        })
    }

    private func keyDown(_ e: NSEvent) {
        if !e.isARepeat { keys.insert(e.keyCode) }

        switch e.keyCode {
        case KeyCode.k:
            engine?.paused.toggle()          // 暂停 / 恢复
        case KeyCode.q:
            NSApplication.shared.terminate(nil)
        default:
            break
        }
    }

    private func mouseButton(_ e: NSEvent) {
        switch e.type {
        case .leftMouseDown:  leftMouseDown = true
        case .leftMouseUp:    leftMouseDown = false
        case .rightMouseDown: rightMouseDown = true
        case .rightMouseUp:   rightMouseDown = false
        case .otherMouseDown: if e.buttonNumber == 2 { middleMouseDown = true }
        case .otherMouseUp:   if e.buttonNumber == 2 { middleMouseDown = false }
        default: break
        }
    }

    /// 拖拽时累积鼠标增量,渲染循环每帧消费后清零
    private func mouseMoved(_ e: NSEvent) {
        if leftMouseDown || middleMouseDown {
            mouseDeltaX += e.deltaX
            mouseDeltaY += e.deltaY
        }
    }
}
