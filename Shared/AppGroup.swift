import AppKit
import Foundation

/// 跨进程共享存储（替代 App Group 容器，避免非沙盒主 App 访问 App Group
/// 容器时触发 macOS Sequoia「想访问其他 App 的数据」TCC 弹窗）。
///
/// 底层使用命名剪贴板（Named NSPasteboard）作为载体：
/// · 沙盒扩展与非沙盒主 App 之间天然互通，无需 App Group 权限
/// · 不访问任何 App Group 容器目录，不触发 TCC 弹窗
///
/// 数据以单个 JSON 字典整体存放在剪贴板中，每次读写做全量序列化。
final class SharedStore {

    static let shared = SharedStore()

    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.snapclick.app.sharedstore"))
    private let lock = NSLock()

    private init() {}

    private func readAll() -> [String: Any] {
        guard let jsonStr = pasteboard.string(forType: .string),
              let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func writeAll(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let jsonStr = String(data: data, encoding: .utf8) else { return }
        pasteboard.clearContents()
        pasteboard.setString(jsonStr, forType: .string)
    }

    private func setValue(_ value: Any?, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        var dict = readAll()
        if let value {
            dict[key] = value
        } else {
            dict.removeValue(forKey: key)
        }
        writeAll(dict)
    }

    private func value(forKey key: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        return readAll()[key]
    }

    // MARK: - 兼容 UserDefaults 的读写接口

    func data(forKey key: String) -> Data? {
        guard let base64 = value(forKey: key) as? String else { return nil }
        return Data(base64Encoded: base64)
    }

    func set(_ data: Data, forKey key: String) {
        setValue(data.base64EncodedString(), forKey: key)
    }

    func stringArray(forKey key: String) -> [String]? {
        value(forKey: key) as? [String]
    }

    func array(forKey key: String) -> [Any]? {
        value(forKey: key) as? [Any]
    }

    func set(_ array: [String], forKey key: String) {
        setValue(array, forKey: key)
    }

    func set(_ array: [[String: String]], forKey key: String) {
        setValue(array, forKey: key)
    }

    func string(forKey key: String) -> String? {
        value(forKey: key) as? String
    }

    func set(_ string: String, forKey key: String) {
        setValue(string, forKey: key)
    }

    func removeObject(forKey key: String) {
        setValue(nil, forKey: key)
    }

    func synchronize() {}
}

enum AppGroup {
    static var defaults: SharedStore { SharedStore.shared }
}
