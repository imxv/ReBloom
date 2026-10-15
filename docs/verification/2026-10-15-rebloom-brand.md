# ReBloom 品牌更名验证

日期：2026-10-15。

用户选定将本项目由 Adonis 更名为 ReBloom，把 Adonis 留给另一个项目。本次更名覆盖 App 展示名称、系统分享扩展入口、首页品牌、权限与恢复提示、生成卡片页脚及当前产品文档。现有测试中与这些文案对应的期望同步更新，未新增 UI 单元测试。

## 兼容范围

- Xcode 工程、target、Swift 类型和本地目录沿用原名；仍使用 `Adonis.xcodeproj` / `Adonis` scheme。
- 主 App Bundle ID 保持 `studio.adonis.localdemo`，分享扩展保持 `studio.adonis.localdemo.share`。
- App Group、数据库与媒体目录、导出 schema、文件名前缀、通知标识、HTTP header 与 `ADONIS_*` 环境变量保持原值。
- 原有业务改动、历史截图、样片、测试证据与 TODO 的完成边界保留；历史记录中的 Adonis 名称不改写为新品牌。

## 本轮检查

- `git diff --check` 通过。
- `make check` 通过：严格 Swift 格式检查与通用 iOS 设备静态分析；工具链为 Xcode 27.0（27A266a）。
- `make server-test test-tools` 通过，覆盖本地代理契约与 Python 验证工具。
- 使用 XcodeBuildMCP `build_sim(buildForTesting: true)`，选择 iPhone 18 Pro / iOS 27.0、Debug、`CODE_SIGNING_ALLOWED=NO`；App、分享扩展与现有测试 target 编译通过。
- 读取编译产物 Info.plist：主 App 展示名为 `ReBloom`，分享入口为 `收进 ReBloom`；Bundle ID 与上述兼容值一致。
- 当前文档的本地链接检查通过；独立代码审查未发现剩余更名阻断项。

## 证据边界

本轮所有模拟器均处于关闭状态，没有启动 App、执行 iOS 测试或取得运行截图。编译测试 target 不代表其中测试已执行，也不代表新品牌布局已通过模拟器或真机目检。既有历史回归不作为本轮源码的重新验收。以上检查不验证真实 Apple/OpenAI provider、人物或衣物保真及真实 iPhone。

仓库含原始人物样片，GitHub 交付使用私有仓库 `imxv/ReBloom`；原有公开空仓库 `imxv/Adonis` 保留给另一个项目。上传代码不等于部署 App 或透明处理代理。
