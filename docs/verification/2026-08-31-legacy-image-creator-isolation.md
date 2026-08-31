# Apple ImageCreator 旧适配器隔离验证记录

> 结论：Adonis 的产品主链路仍是“用户原图 → AI 不透明贴纸图 → 对 AI 图抠图 → 透明贴纸”，但 Apple `ImageCreator` 已被收拢为只在 iOS 26 SDK 构建中启用的旧适配器。禁用该适配器时，Release 二进制不再链接 `ImagePlayground.framework`、不导入 `ImageCreator` 符号，运行时生成器明确报告不可用，并复用既有的重试或标注内置样片恢复，不会直接抠用户原图。
>
> 读者：升级 Xcode / iOS SDK、替换图片生成 provider，或决定云端图片上传边界的工程师、产品负责人和 AI。
>
> 阅读后的行动：先运行 `make legacy-provider-isolation`，再决定新的真实 provider；不得把旧 API、内置样片或 Debug 夹具当成 iOS 27 兼容证明。

## 1. API 生命周期事实

Apple 在 2026-06-11 公告：`ImageCreator` 将在 iOS 27、iPadOS 27、macOS 27 和 visionOS 27 停止工作，并建议迁移到系统 Image Playground 界面或其他服务。[Apple 停用公告](https://developer.apple.com/news/?id=dz9wvq0r)

Apple 的 `ImageCreator` 文档也已把该类型标记为 deprecated。[ImageCreator 文档](https://developer.apple.com/documentation/ImagePlayground/ImageCreator?changes=_8)

因此，`ImageCreator` 只能作为当前 iOS 26 构建的过渡适配器，不能继续承担 Adonis 的长期、自动化图片生成抽象。系统 Image Playground 界面是另一种需要用户参与的交互，不等同于当前隐藏配方的程序化 provider；是否采用它仍需单独做产品验证。

## 2. 编译与运行时边界

| 层级 | 当前契约 |
| --- | --- |
| 产品流程 | AI 先产生不透明贴纸图，`StickerProcessor` 只处理该 AI 图；任何 provider 都不得绕过这一步或退回用户原图直抠。 |
| 稳定接口 | `SystemCreativeImageGenerator` 不直接导入 `ImagePlayground`，对上层继续提供统一 availability、generation 和 execution metadata。 |
| 旧适配器 | `LegacyImageCreatorGenerator` 的全部代码仅在 `canImport(ImagePlayground) && ADONIS_ENABLE_LEGACY_IMAGE_CREATOR` 时编译。 |
| SDK 选择 | `project.yml` 只为 `iphoneos26.*` 与 `iphonesimulator26.*` 设置 `ADONIS_ENABLE_LEGACY_IMAGE_CREATOR`；未来 SDK 默认不编译旧实现。 |
| 运行时防线 | 即使旧适配器存在，iOS 27 及以上也直接报告不可用，不尝试调用已经停止工作的 API。 |
| 用户恢复 | provider 不可用时沿用现有“先不用 / 体验内置样片”；样片必须由用户明确选择并显示真实来源。 |

当前 Xcode 26.5 的普通 iOS 与模拟器构建都能从 build settings 读到 `DEBUG ADONIS_ENABLE_LEGACY_IMAGE_CREATOR`，因此本次隔离没有悄悄改变当前 SDK 26 的旧适配器行为。

## 3. 自动门禁

运行：

```bash
make legacy-provider-isolation
```

门禁会完成：

1. 用 `ADONIS_LEGACY_PROVIDER_DISABLED` 覆盖旧 provider 条件，执行一次干净的 unsigned Release 通用 iOS 构建。
2. 用 `otool -L` 断言 App 二进制没有链接 `ImagePlayground.framework`。
3. 用 `nm -u` 断言 App 二进制没有导入 `ImageCreator` 符号。
4. 在相同禁用条件下运行专项测试，断言系统生成器 availability 为 unavailable，生成请求抛出 `CreativeGenerationError.unavailable`。

2026-08-31 当前结果：

```text
Verified legacy-disabled provider boundary: no ImageCreator/ImagePlayground binary references; runtime reports unavailable.
```

同一最终工作树还通过：

- `make test`：218/218，包含 179 个单元测试和 39 个 UI 流程，0 失败、0 跳过；结果包为 `.derivedData/Logs/Test/Test-Adonis-2026.08.31_12-06-09-+0800.xcresult`。隔离目标另运行 1 个只在 `ADONIS_LEGACY_PROVIDER_DISABLED` 下编译的专项测试。
- `make ai-sticker-regression`：主链路 4 个 UI 流程 0 失败，相关单元契约同批通过。
- `make creative-regression`：创作入口 6 个 UI 流程 0 失败，相关单元契约同批通过。
- `make sample-regression`：27 个 iOS 图片处理测试 0 失败，宿主机固定样片重生成同时通过。
- `make ai-sticker-visual-regression`：4 组不透明 AI 源与真 Alpha 贴纸的哈希、尺寸和通道结构通过。
- `make performance-regression`：超时、取消、迟到结果和执行元数据专项通过。
- `make check`：严格 Swift 格式检查与通用 iOS 设备静态分析通过。

这是一条使用当前 iOS 26.5 SDK 模拟“未来构建不启用旧条件”的隔离证据。它还不是实际 iOS 27 SDK 的编译或真机运行证明；安装 Xcode 27 后必须重新运行门禁和目标真机回归。

## 4. 云端 provider 的隐私与安全决策边界

本次改动没有接入第三方图片 API，没有上传任何用户图片，也没有选择长期 provider。

如果后续选择云端方案，最低实现边界是：

- 图片上传前由用户做一次清楚、可撤回的同意；不得在后台自动上传。
- provider 密钥只保存在开发者控制的后端或本地开发代理中，不写入 App、Info.plist、源码或客户端 Keychain。
- 在公开测试前明确上传图片、用途、处理地区、保存期限、删除方式、训练用途和失败后的数据状态。
- 记录真实 provider、请求数、重试、取消、端到端耗时和单次成本；未知值保持未知。
- 新 provider 仍必须输出不透明 AI 源图，再由现有透明贴纸处理链抠图，并分别验证人物/穿搭保真和 Alpha 质量。

## 5. 尚未证明

- 尚未安装 iOS 27 SDK，因此没有真实证明 Xcode 27 下的工程生成、编译与系统 API 行为。
- 当前 iPhone 11 不支持 Apple Intelligence，旧适配器和系统 Image Playground 都不能让它处理用户照片。
- 尚未选择云端、系统界面或本地模型路线，也没有真实 provider 的质量、隐私、弱网、取消、费用和时延证据。
- 内置样片、Debug 夹具和四张外部实验图都不能替代目标 provider 对用户本人照片的真实输出。
