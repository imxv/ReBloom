# Apple ImageCreator 旧适配器隔离验证记录

> 结论：Apple `ImageCreator` 已被收拢为只在 iOS 26 SDK 构建中启用的旧程序化适配器，并且不再承担默认人物贴纸。默认主链路已迁移到受支持的系统 Image Playground 确认页；禁用旧适配器时，Release 二进制应继续链接 `ImagePlayground.framework`，但不得导入 `ImageCreator` 符号。旧程序化生成器必须明确报告不可用，不能调用失效 API 或退回用户原图直抠。
>
> 读者：升级 Xcode / iOS SDK、修改系统 Image Playground、迁移风格花园或决定云端图片上传边界的工程师、产品负责人和 AI。
>
> 阅读后的行动：先运行 `make legacy-provider-isolation`；同时阅读 [默认 AI 贴纸迁移到系统 Image Playground 验证记录](2026-08-31-image-playground-sheet-migration.md)。不得把旧 API、系统页 Debug 替身或内置样片当成 iOS 27 真机兼容证明。

## 1. API 生命周期与迁移决定

Apple 在 2026-06-11 公告：`ImageCreator` 将在 iOS 27、iPadOS 27、macOS 27 和 visionOS 27 停止工作，并建议迁移到系统 Image Playground 界面或其他服务。[Apple 停用公告](https://developer.apple.com/news/?id=dz9wvq0r)

Apple 的 `ImageCreator` 文档也已把该类型标记为 deprecated。[ImageCreator 文档](https://developer.apple.com/documentation/ImagePlayground/ImageCreator?changes=_8)

因此，`ImageCreator` 只能暂时服务尚未迁移的“风格花园”，不能继续承担默认人物贴纸或长期图片生成抽象。默认人物贴纸已经采用需要用户参与的 `ImagePlaygroundViewController`：Adonis 预置参考照片和固定概念，用户确认结果后才把 AI 底图交给 GPT Image 做透明编辑。这是产品流程的一次系统确认，不是程序化 provider 的同义替换；第二段边界见 [AI 二次透明处理验证记录](2026-08-31-ai-transparent-extraction-provider.md)。

## 2. 编译与运行时边界

| 层级 | 当前契约 |
| --- | --- |
| 默认人物贴纸 | `SystemImagePlaygroundStickerSourceSheet` 始终独立于旧编译条件；能力可用时打开系统页，只有用户确认图能进入 `AIStickerCreationPipeline`。 |
| 稳定旧接口 | `SystemCreativeImageGenerator` 仍供风格花园使用，不直接导入 `ImagePlayground`，对上层提供统一 availability、generation 与 execution metadata。 |
| 旧适配器 | `LegacyImageCreatorGenerator` 的全部代码仅在 `canImport(ImagePlayground) && ADONIS_ENABLE_LEGACY_IMAGE_CREATOR` 时编译。 |
| SDK 选择 | `project.yml` 只为 `iphoneos26.*` 与 `iphonesimulator26.*` 设置 `ADONIS_ENABLE_LEGACY_IMAGE_CREATOR`；未来 SDK 默认不编译旧实现。 |
| 运行时防线 | 即使旧适配器存在，iOS 27 及以上也直接报告不可用，不尝试调用已经停止工作的 API。 |
| 二进制契约 | 禁用旧适配器后仍应链接系统页需要的 `ImagePlayground.framework`，但 `nm -u` 不得出现 `ImageCreator`。 |
| 用户恢复 | 默认系统页不可用时提供明确样片恢复；风格花园旧 provider 不可用时隐藏入口。两者都不得伪造成功。 |

当前 Xcode 26.5 的普通 iOS 与模拟器构建仍能从 build settings 读到 `ADONIS_ENABLE_LEGACY_IMAGE_CREATOR`，所以风格花园在当前 SDK 的旧行为没有被静默移除；默认人物贴纸是否出现则单独由 `ImagePlaygroundViewController.isAvailable` 决定。

## 3. 自动门禁

运行：

```bash
make legacy-provider-isolation
```

门禁会完成：

1. 用 `ADONIS_LEGACY_PROVIDER_DISABLED` 覆盖旧 provider 条件，执行一次干净的 unsigned Release 通用 iOS 构建。
2. 用 `otool -L` 断言 App 二进制仍链接受支持的 `ImagePlayground.framework` 系统页。
3. 用 `nm -u` 断言 App 二进制没有导入任何 `ImageCreator` 符号。
4. 在相同禁用条件下运行专项测试，断言旧 `SystemCreativeImageGenerator` availability 为 unavailable，生成请求抛出 `CreativeGenerationError.unavailable`。

2026-08-31 在本切片最终代码上实际运行通过，输出为：

```text
Verified provider boundary: the supported Image Playground sheet remains linked, legacy ImageCreator symbols are absent, and the old programmatic generator reports unavailable.
```

这是一条使用当前 iOS 26.5 SDK 模拟“未来构建不启用旧条件”的隔离证据。命令退出码为 0，包含一次干净 unsigned Release 构建、二进制链接/符号检查与一次禁用条件专项测试。它还不是实际 iOS 27 SDK 的编译或真机运行证明；安装 Xcode 27 后必须重新运行门禁和目标真机回归。

## 4. 云端 provider 的隐私与安全决策边界

默认人物贴纸第一段由 Apple 系统页管理；第二段现已接入开发者代理与 GPT Image，但客户端仍没有供应商密钥，且只上传用户确认的 AI 底图，不上传用户原照片。两段都不能描述成完全离线、零网络或免费，现行边界见 [AI 二次透明处理验证记录](2026-08-31-ai-transparent-extraction-provider.md)。

如果后续为不支持 Apple Intelligence 的设备或风格花园选择云端方案，最低实现边界是：

- 图片上传前由用户做一次清楚、可撤回的同意；不得在后台自动上传。
- provider 密钥只保存在开发者控制的后端或本地开发代理中，不写入 App、Info.plist、源码或客户端 Keychain。
- 在公开测试前明确上传图片、用途、处理地区、保存期限、删除方式、训练用途和失败后的数据状态。
- 记录真实 provider、请求数、重试、取消、端到端耗时和单次成本；未知值保持未知。
- 新 provider 仍必须输出不透明 AI 源图，再由现有透明贴纸处理链抠图，并分别验证人物/穿搭保真和 Alpha 质量。

## 5. 尚未证明

- 尚未安装 iOS 27 SDK，因此没有真实证明 Xcode 27 下的工程生成、编译、系统页或旧符号行为。
- 当前 iPhone 11 不支持 Apple Intelligence，系统 Image Playground 不能让它处理用户照片。
- 尚未在支持 Apple Intelligence 的真实 iPhone 上验证默认系统页的参考图、确认、取消、网络、限额、费用、质量和实时抠图。
- 风格花园仍未选择 iOS 27 之后的长期 provider，也没有相应的质量、隐私、弱网、取消、费用和时延证据。
- 内置样片、Debug 系统页替身和四张外部实验图都不能替代目标系统或 provider 对用户本人照片的真实输出。
