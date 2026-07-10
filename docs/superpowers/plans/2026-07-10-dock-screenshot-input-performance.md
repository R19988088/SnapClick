# Dock、截图输入与性能优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复 Dock 面板定位/尖角、窗口描边投影、Alt+A 字符泄漏和压力笔迹抖动，重做原生玻璃工具栏，并降低截图标注热路径的内存和 CPU 开销。

**架构：** 保留现有 AppKit 控制器和 Dock 缩略图链路，只在共享边界增加可测试的几何、热键消费、输入稳定和图像处理逻辑。Dock 缩略图尺寸、枚举和捕获保持不变；截图效果继续统一由 `ScreenCaptureEngine` 输出。

**技术栈：** Swift、AppKit、Core Graphics、Core Image、ScreenCaptureKit、SF Symbols、shell 契约测试、Xcode/macOS 签名工具链。

---

## 文件职责

- 修改 `SnapClick/Core/HotkeyManager.swift`：同步判断热键是否命中并消费事件。
- 修改 `SnapClick/App/AppDelegate.swift`：Dock 稳定锚点、尖角和系统标题覆盖；保留现有缩略图实现。
- 创建 `SnapClick/Modules/Screenshot/AnnotationInputStabilizer.swift`：独立的压力平均与速度自适应坐标滤波。
- 修改 `SnapClick/Modules/Screenshot/AnnotationCanvas.swift`：接入稳定器、缩小重绘区域、缓存低对比图。
- 修改 `SnapClick/Modules/Screenshot/AnnotationTool.swift`：共享工具栏原生玻璃外观与 SF Symbols。
- 修改 `SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift`：使用共享玻璃工具栏并维护捕获任务生命周期。
- 修改 `SnapClick/Modules/Screenshot/AnnotationEditorWindow.swift`：与就地工具栏保持一致。
- 修改 `SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift`：统一描边/投影并移除整图扫描、TIFF 副本和临时 CIContext。
- 修改 `SnapClick/UI/MainWindow.swift`：修正截图设置文案。
- 修改 `SnapClick.xcodeproj/project.pbxproj`：把稳定器加入 SnapClick target。
- 修改 `scripts/test_hotkey_safety.sh`：热键消费回归契约。
- 修改 `scripts/test_dock_window_control.sh`：Dock 稳定锚点和尖角合同，同时锁定无缩略图性能改造。
- 修改 `scripts/test_screenshot_annotation_contracts.sh`：截图效果、玻璃工具栏和性能合同。
- 创建 `scripts/test_annotation_input_stabilizer.swift`：直接编译生产稳定器的行为测试。

### 任务 1：热键事件消费

- [ ] 在 `scripts/test_hotkey_safety.sh` 增加断言：`handleKeyEvent` 返回 `Bool`，匹配时 callback 返回 `nil`，未匹配时透传。
- [ ] 运行 `scripts/test_hotkey_safety.sh`，预期因当前 `handleKeyEvent` 返回 `Void` 而失败。
- [ ] 修改 `HotkeyManager.handleKeyEvent`，同步返回是否命中；callback 命中时派发 action 并返回 `nil`。
- [ ] 重新运行脚本，预期 PASS。

### 任务 2：压力和坐标稳定器

- [ ] 创建 `scripts/test_annotation_input_stabilizer.swift`，覆盖首包立即输出、4 样本压力平均、reset 清历史、慢速抖动平滑和快速运动趋近原始输入。
- [ ] 创建最小生产类型声明并运行：

```bash
xcrun swiftc SnapClick/Modules/Screenshot/AnnotationInputStabilizer.swift scripts/test_annotation_input_stabilizer.swift -o /tmp/snapclick-stabilizer-test
/tmp/snapclick-stabilizer-test
```

预期首次因滤波行为未实现而 FAIL。

- [ ] 实现固定 4 样本压力环形缓冲与速度自适应 EMA；不等待未来样本。
- [ ] 将源文件加入 Xcode target，重跑行为测试，预期 PASS。
- [ ] 在 `AnnotationCanvas` 起笔 reset，拖动逐样本过滤，抬笔完成后 reset；普通鼠标回退当前线宽。
- [ ] 为路径数组预留容量，并使用扩展后的线段脏矩形调用 `setNeedsDisplay(_:)`。

### 任务 3：窗口描边投影和图像性能

- [ ] 更新 `scripts/test_screenshot_annotation_contracts.sh`，要求删除 `visiblePixelBounds`、直接 `CGImage` 编码、共享 CIContext、缓存低对比图和真实“添加圆角”文案。
- [ ] 运行脚本，预期在上述旧路径上 FAIL。
- [ ] 修改 `ScreenCaptureEngine.applyShadow`：以已知完整图像矩形绘制 1pt 分隔线和投影，不再分配 RGBA 数组扫描 alpha。
- [ ] 修改 `saveScreenshot`：直接使用 `NSBitmapImageRep(cgImage:)` 编码目标格式。
- [ ] 复用长生命周期 CIContext，删除样本转换中的临时 context。
- [ ] 在 `AnnotationCanvas.baseImage` 更新时生成一次低对比图，`drawHighlightMask` 只复用缓存。
- [ ] 将设置文案“窗口透明”改为“添加圆角”，不改存储键。
- [ ] 重跑截图合同，预期 PASS。

### 任务 4：原生玻璃矩形工具栏和图标

- [ ] 扩充截图合同，要求 `AnnotationToolbarChrome.makeView()`、12pt 主圆角、7pt 按钮圆角、macOS 26 `NSGlassEffectView` 和 `NSVisualEffectView` 回退。
- [ ] 运行合同，预期 FAIL。
- [ ] 在 `AnnotationToolbarChrome` 创建共享玻璃 view/content host，并把 `apply(to:)` 改为矩形 chrome。
- [ ] `CaptureOverlayWindow` 和 `AnnotationEditorWindow` 均从共享工厂创建工具栏，并把控件装入 content host。
- [ ] 替换图标：`pencil.tip`、`textformat`、`rectangle.dashed`、`square.grid.3x3.fill`、`number.circle`、四向拖动符号，并保留旧系统 fallback。
- [ ] 重跑截图合同，预期 PASS。

### 任务 5：Dock 稳定锚点、尖角和标题覆盖

- [ ] 更新 `scripts/test_dock_window_control.sh`，要求读取 `largesize`、面板使用 `popUpMenu` 层级、生成方向尖角、每次刷新重算 frame，同时断言不存在新增 `thumbnailCache`。
- [ ] 运行脚本，预期 FAIL。
- [ ] 保留 `PreviewMetrics.tileWidth/tileHeight/imageHeight`、`copyWindows`、`loadThumbnails` 和 `captureThumbnail` 不变。
- [ ] 添加 Dock 最大图标尺寸读取与底/左/右稳定锚点计算。
- [ ] 在同一 app/fingerprint 快速返回前更新面板 frame，修复未放大命中后保持低位的问题。
- [ ] 为玻璃主体添加随 orientation 旋转、指向图标中心的尖角；提升到 `popUpMenu` 层级遮住系统标题。
- [ ] 重跑 Dock 合同，预期 PASS。

### 任务 6：集中验证和构建

- [ ] 运行全部脚本：

```bash
scripts/test_hotkey_safety.sh
scripts/test_screenshot_annotation_contracts.sh
scripts/test_dock_window_control.sh
xcrun swiftc SnapClick/Modules/Screenshot/AnnotationInputStabilizer.swift scripts/test_annotation_input_stabilizer.swift -o /tmp/snapclick-stabilizer-test
/tmp/snapclick-stabilizer-test
```

- [ ] 运行 Debug 编译：

```bash
xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

- [ ] 审查 diff，确认用户已有 Finder Forward Delete 改动被保留，且 Dock 缩略图性能链没有变化。

### 任务 7：签名 Release DMG

- [ ] 构建签名 Release：

```bash
xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData DEVELOPMENT_TEAM=HQ6YY6QF8H CODE_SIGN_IDENTITY="Apple Development: esc_g@hotmail.com (72LZ3ELC38)" CODE_SIGN_STYLE=Manual build
```

- [ ] 打包并验证：

```bash
scripts/build_dmg.sh build/DerivedData/Build/Products/Release/SnapClick.app
codesign --verify --deep --strict build/DerivedData/Build/Products/Release/SnapClick.app
hdiutil verify dist/SnapClick.dmg
shasum -a 256 dist/SnapClick.dmg
```

- [ ] 记录 app 的 `TeamIdentifier=HQ6YY6QF8H`、DMG 验证结果和 SHA-256。本轮未要求 push，不推送远端。
