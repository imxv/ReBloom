# 透明贴纸存入相册验证记录

> 日期：2026-08-31
>
> 读者：继续开发结果页、PhotoKit 交付或权限恢复的工程师与 AI
>
> 阅读后的行动：先复现成功、权限拒绝和写入失败三个边界，再修改保存流程；不要把注入式模拟器证据描述成真实相册已写入。
>
> 状态：应用侧契约、PNG 字节边界和模拟器界面已验证；真实 iPhone 相册写入待验证。

## 1. 用户契约

- “收藏今天”把原图、透明贴纸、收藏卡和日期保存为 Adonis 本地 OOTD，不请求照片权限。
- “存透明贴纸”只在用户明确点击后请求 iOS 的 add-only 照片权限；不自动保存，也不在结果出现前索权。
- 无论当前预览是收藏卡、透明贴纸还是原始照片，存入相册的资产始终是 `draft.stickerImage`。
- 成功后不离开结果页，不弹出成功对话框；按钮原地变为“贴纸已存到相册”。
- 权限拒绝或系统写入失败时，作品、内部收藏能力与当前结果都保留。界面只显示一条内联说明和“再试一次 / 分享贴纸”两个恢复动作，避免重复分享入口。
- “分享贴纸”会先切换到透明贴纸，再打开真实系统分享面板；关闭后仍回到同一结果。

## 2. 实现边界

`PhotoLibrarySaver` 由两个 `@MainActor` 依赖组成：add-only 授权请求与 PNG 字节写入器。正式实现先检查 `PHPhotoLibrary.authorizationStatus(for: .addOnly)`，仅在状态未确定时请求 add-only 授权；只有 `.authorized` 或 `.limited` 可以继续。

通过授权后，服务先调用 `UIImage.pngData()`，再使用 `PHAssetCreationRequest.forAsset()` 和 `addResource(with: .photo, data:, options:)` 交付这些字节。资源文件名为 `Adonis-Sticker-<UUID>.png`，UTI 固定为 PNG。这样可以锁定透明贴纸字节，不把当前收藏卡预览交给系统，也不依赖 `UIImage` 写入路径的再编码行为。

应用只记录以下不含用户内容的本地事件：

- `贴纸存入相册`，详情为 `asset=sticker`。
- `贴纸未存入相册`，详情为 `asset=sticker;reason=permission_denied` 或 `asset=sticker;reason=write_failed`。

事件不得包含图片、文件路径、记录 ID、系统错误原文或用户文字。未知写入错误统一归一化为 `write_failed`。

## 3. TDD 证据

本切片先建立失败证据，再实现最小行为：

1. 成功 UI 测试最初因结果页没有“存透明贴纸”而失败，随后实现原地成功状态。
2. 授权边界单元测试最初因旧静态接口不可注入而失败，随后拆出授权请求与写入器。
3. 拒绝 UI 测试最初停留在“正在保存”，没有恢复界面，随后实现内联失败与分享兜底。
4. 事件契约测试最初因缺少成功/失败事件及固定错误码而编译失败；失败结果包：`.derivedData/Logs/Test/Test-Adonis-2026.08.30_23-51-33-+0800.xcresult`。
5. PNG 传输测试最初发现写入器仍接收 `UIImage`；失败结果包：`.derivedData/Logs/Test/Test-Adonis-2026.08.30_23-54-03-+0800.xcresult`。改为传输 `Data` 后，PNG 签名与 Alpha 契约通过；成功结果包：`.derivedData/Logs/Test/Test-Adonis-2026.08.30_23-54-34-+0800.xcresult`。
6. 拒绝态最初同时出现两个分享动作且文案为“改用系统分享”；失败结果包：`.derivedData/Logs/Test/Test-Adonis-2026.08.30_23-58-28-+0800.xcresult`。收敛成唯一“分享贴纸”后通过；成功结果包：`.derivedData/Logs/Test/Test-Adonis-2026.08.30_23-59-44-+0800.xcresult`。

## 4. 可重复自动验证

运行：

```sh
make photo-save-regression
make accessibility-regression
make test
```

专项回归覆盖：

- 已授权时只调用一次写入器，并传入由源透明贴纸编码出的 PNG 字节。
- PNG 具有正确签名且解码后仍存在 Alpha 通道。
- 权限拒绝时不调用写入器。
- 写入器失败时统一映射为可理解的稳定错误。
- 成功后留在结果页并显示“贴纸已存到相册”。
- 权限拒绝后只出现“再试一次 / 分享贴纸”，分享打开系统活动面板且结果没有丢失。
- 结果页动作在最大辅助字号与增强对比度下仍可滚动到达，触控区域至少 44 点。

本轮通过证据：

- `make photo-save-regression`：4 个单元测试与 2 条 UI 流程，0 失败；最终结果包 `.derivedData/Logs/Test/Test-Adonis-2026.08.31_00-36-35-+0800.xcresult`。
- `make accessibility-regression`：1 个颜色契约测试与 7 条 UI 流程，0 失败；结果包 `.derivedData/Logs/Test/Test-Adonis-2026.08.31_00-05-59-+0800.xcresult`。
- `make test`：167 个单元测试与 36 条 UI 流程，共 203 项，0 失败；结果包 `.derivedData/Logs/Test/Test-Adonis-2026.08.31_00-17-59-+0800.xcresult`。
- `make check`：严格 `swift-format` 与通用 iOS 设备静态分析通过。
- Release 通用 iOS 构建通过，主 App 与分享扩展二进制均为 `arm64`。

UI 附件名称：

- `Adonis-sticker-saved-to-photos`
- `Adonis-photo-save-permission-fallback`

## 5. 当前证据能证明什么

- 应用不会在用户明确点击前请求照片权限。
- 结果页成功、拒绝、重试和分享兜底的状态转换可重复。
- 应用交给注入写入边界的数据是透明贴纸 PNG，而不是收藏卡或原始照片。
- 正式代码使用 PhotoKit add-only 授权和 PNG 资源写入 API，且可完成通用 iOS 编译。

## 6. 尚未证明

- 真实 iPhone 的首次系统权限弹窗、拒绝与设置往返。
- `PHPhotoLibrary.performChanges` 在真实设备上成功提交，并且照片 App 可见该资源。
- 照片 App 或后续分享目的地保留 PNG 的透明通道和原始像素尺寸。
- 真实 VoiceOver 朗读顺序、手势操作和系统分享目的地完成情况。

这些项目完成前，不得把“模拟器成功按钮”或“PNG 单元测试通过”扩大为真实相册保存已经验收。
