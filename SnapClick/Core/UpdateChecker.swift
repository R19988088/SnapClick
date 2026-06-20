import AppKit
import Foundation

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let owner = "Tyeerth"
    private let repo = "SnapClick"

    private var isChecking = false

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates(showNoUpdateAlert: Bool = true) {
        guard !isChecking else { return }
        isChecking = true
        performRequest(showNoUpdateAlert: showNoUpdateAlert, remainingRetries: 1)
    }

    private func performRequest(showNoUpdateAlert: Bool, remainingRetries: Int) {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SnapClick", forHTTPHeaderField: "User-Agent")

        session.dataTask(with: request) { [weak self] data, _, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    if remainingRetries > 0 {
                        self.performRequest(showNoUpdateAlert: showNoUpdateAlert, remainingRetries: remainingRetries - 1)
                    } else {
                        self.isChecking = false
                        if showNoUpdateAlert { self.showErrorAlert(reason: error.localizedDescription) }
                    }
                    return
                }

                self.isChecking = false

                guard
                    let data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let tag = json["tag_name"] as? String
                else {
                    if showNoUpdateAlert { self.showErrorAlert(reason: nil) }
                    return
                }

                let htmlURL = (json["html_url"] as? String).flatMap { URL(string: $0) }
                    ?? URL(string: "https://github.com/\(self.owner)/\(self.repo)/releases/latest")

                if self.isNewer(tag, than: self.currentVersion) {
                    self.showUpdateAlert(latestVersion: tag, releaseURL: htmlURL)
                } else if showNoUpdateAlert {
                    self.showUpToDateAlert()
                }
            }
        }.resume()
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = normalize(remote)
        let l = normalize(local)
        let count = max(r.count, l.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    private func normalize(_ version: String) -> [Int] {
        let trimmed = version
            .lowercased()
            .replacingOccurrences(of: "v", with: "")
        let core = trimmed.split(separator: "-").first.map(String.init) ?? trimmed
        return core.split(separator: ".").map { Int($0) ?? 0 }
    }

    private func showUpdateAlert(latestVersion: String, releaseURL: URL?) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "发现新版本".localized
        alert.informativeText = String(
            format: "检测到新版本 %@，当前版本 %@。是否前往下载页面？".localized,
            latestVersion, currentVersion
        )
        alert.addButton(withTitle: "前往下载".localized)
        alert.addButton(withTitle: "稍后".localized)
        if alert.runModal() == .alertFirstButtonReturn, let releaseURL {
            NSWorkspace.shared.open(releaseURL)
        }
    }

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "已是最新版本".localized
        alert.informativeText = String(
            format: "当前版本 %@ 已是最新。".localized, currentVersion
        )
        alert.addButton(withTitle: "好".localized)
        alert.runModal()
    }

    private func showErrorAlert(reason: String?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "检查更新失败".localized
        var text = "无法连接到更新服务器，请检查网络后重试。".localized
        if let reason, !reason.isEmpty {
            text += "\n(\(reason))"
        }
        alert.informativeText = text
        alert.addButton(withTitle: "好".localized)
        alert.runModal()
    }
}
