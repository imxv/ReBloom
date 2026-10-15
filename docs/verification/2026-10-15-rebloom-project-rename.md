# ReBloom 本地目录与 Xcode 工程更名验证

日期：2026-10-15。基线提交：`dd3ba1f`。

## 更名范围

- 实际仓库目录：`/Users/sunmozong/ReBloom`。
- 工程与主 scheme：`ReBloom.xcodeproj` / `ReBloom`。
- 源码目录与 targets：`ReBloom`、`ReBloomShareExtension`、`ReBloomTests`、`ReBloomUITests`；共享源码目录为 `ReBloomShared`。
- Makefile、回归脚本、样片清单、代理测试资源路径、README 中英文及当前开发文档同步使用新路径。历史证据中的旧命令和结果路径保留；实际指向搬迁资源的 Markdown 链接目标已更新。
- Codex 已登记的项目仍引用旧路径，且工具禁止自动操作 Codex 自身的项目设置。本机保留 `/Users/sunmozong/Adonis → /Users/sunmozong/ReBloom` 符号链接，使当前聊天及旧终端引用继续可用；它不是第二份仓库。后续将 Codex 中的项目目录改为新路径后，可单独移除旧链接。

## 数据兼容约束

主 App 的 `PRODUCT_MODULE_NAME` 显式固定为 `Adonis`，分享扩展固定为 `AdonisShareExtension`。主 App、扩展与测试的 Bundle ID、App Group、Swift 模型类型和属性、`AdonisMedia`、分享收件箱、通知标识、导出 schema、`ADONIS_*` 配置均保持原值。

移动前后共 139 个 Swift、plist 和 entitlements 文件的内容字节相同。仅工程、target、scheme、产品与源码位置变动；测试宿主更新为 `ReBloom.app/ReBloom`，现有 `@testable import Adonis` 和 `AdonisFlowUITests` 类名保留。

## 运行与数据实证

在原安装的 iPhone 18 Pro / iOS 27.0 模拟器中，用普通首页内置样片保存 `Bloom No. 001`。终止 App 后备份实际数据容器，记录默认 SwiftData 数据库 UUID、模型元数据、完整收藏行与 4 个媒体文件的 SHA-256。备份保存在忽略的 `.artifacts/project-rename/before-data`，不随仓库上传。

从新根目录构建 `ReBloom.xcodeproj`，以同一 Bundle ID **覆盖安装**，没有卸载 App。随后验证：

1. 数据库 UUID、模型元数据、旧收藏行和原有 4 个媒体哈希完全一致。模拟器在覆盖安装时重新分配了数据容器目录，但内容与数据库身份保留。
2. 花历仍显示原有 1 次盛开，打开 `Bloom No. 001` 可见原收藏卡和 AI 来源说明，图片已目检。
3. 无启动参数重新打开 App，使用第二张内置样片生成并保存 `Bloom No. 002`。
4. 再次真实终止并无参数启动，数据库中保留编号 `[1, 2]`，媒体共 8 个；旧行和旧媒体仍不变，设置页显示“穿搭记录 2”。

旧卡回看的页面导航使用既有 Debug 参数 `-ui-testing-open-rebloom-reminder` 选中花历，再关闭失效提醒提示并打开旧记录；该参数没有启用 `-ui-testing`、内存库或 UUID 测试库。首次覆盖启动、新收藏和最终冷启动均无参数。本轮没有新增 UI 测试或注入替代收藏数据。

- [数据与构建标识核对报告](../evidence/rebloom-project-rename-data-2026-10-15.json)
- [升级后原收藏卡截图](../evidence/rebloom-renamed-project-restored-2026-10-15.png)
- [冷启动后两条收藏截图](../evidence/rebloom-renamed-project-cold-launch-2026-10-15.png)

## 已通过检查

- `make check`：严格 Swift 格式检查及通用 iOS 静态分析。
- XcodeBuildMCP `build_run_sim`：新工程 Debug 构建、覆盖安装及启动成功，产物为 `ReBloom.app`。
- `make server-test test-tools ai-sticker-visual-regression`：代理契约、34 项验证工具测试及 4 组历史 AI 样片资源/哈希检查通过。
- 通过 `scripts/run_verified_tests.py` 运行新 target 的 `ModelStorePolicyTests`、`MediaStoreTests`、`SharedImageInboxTests` 与既有 `testCollectedOutfitSurvivesProcessTerminationAndRelaunch`，在独立 iPhone 17 Pro / iOS 26.5 模拟器上 **10 项通过、0 失败、0 跳过**。[独立结果核验](../evidence/rebloom-project-rename-tests-2026-10-15.json)
- 当前文档链接、样片资源路径和 SHA-256、回归脚本语法、98 处测试 selector 与 scheme 引用检查通过；独立审查未发现更名阻断项。

## 验证边界

本轮覆盖安装使用 `CODE_SIGNING_ALLOWED=NO`。原模拟器安装没有可访问的 App Group 容器，正式默认数据库实际位于 App 数据容器；两份 App Group entitlements 保持字节一致，但本轮不能证明签名后的共享容器运行或真实 iPhone 升级。真实设备继续需要原签名 Team 和既有 entitlement 权限。没有验证真实 provider、人物/衣物保真或完整应用全量回归。
