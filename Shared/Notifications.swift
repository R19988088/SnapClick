import Foundation

/// FinderExtension / 主 App 共享的通知名
extension Notification.Name {
    /// 收藏目录或文件模板发生变更，AppDelegate 收到后会重新预热图标缓存。
    /// FinderExtension 收到后应清空自身的内存图标缓存。
    static let finderMenuAssetsDidChange = Notification.Name("com.snapclick.finderMenuAssetsDidChange")
}
