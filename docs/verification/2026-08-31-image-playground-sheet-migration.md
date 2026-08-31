# 默认 AI 贴纸迁移到系统 Image Playground 验证记录

> 结论：默认人物贴纸不再依赖程序化 `ImageCreator` 生成第一张结果。系统能力可用时，Adonis 把用户选择的照片和固定贴纸概念预置进系统 Image Playground，用户只需在系统界面确认一张不透明 AI 生成图。本文原始实现随后把它交给 `StickerProcessor`；第二段现已替换为 GPT Image 透明编辑与双端 Alpha 门禁，见 [AI 二次透明处理验证记录](2026-08-31-ai-transparent-extraction-provider.md)。取消、失败或能力不可用都不会改用用户原图直接抠图。
>
> 读者：修改默认人物贴纸、Image Playground 系统界面、生成来源、抠图输入、取消恢复、provider 元数据或 iOS SDK 边界的工程师、产品负责人和 AI。
>
> 阅读后的行动：运行 `make ai-sticker-regression`、`make legacy-provider-isolation` 与 `make accessibility-regression`；不要把 Debug 确认页、模拟器截图或 SDK 编译成功描述成真实 Apple 生图质量或真实 iPhone 可用性。

## 1. 用户流程与低心智边界

生产流程固定为：

1. 用户只选择或拍摄一张照片，不填写 Prompt，不选择模型、参数或内部工作流。
2. Adonis 自动路由人物创作，并打开 Apple 提供的系统 Image Playground 界面。
3. 系统界面已带入用户照片与固定的“完整单人、暖白背景、尽量保持人物和穿搭”的概念；iOS 18.4 及以上只允许动画样式，iOS 26.4 及以上使用低变化度。用户只确认自己愿意采用的一张结果。
4. 系统只把用户确认的图片 URL 交还 Adonis。Adonis 在系统界面关闭前读取图片，记录系统页 provider 元数据，并把该图压平为不透明底图。
5. 当前实现只把这张 AI 底图发送到 Adonis 代理，由 GPT Image 返回真实透明 PNG；客户端验证 Alpha 并程序化加入纯白异形边，再完成收藏卡、来源说明、可选人物与穿搭复核、收藏和历史回看。

系统确认是 Apple API 的必要交互，不扩展成 Adonis 自己的模板、风格、Prompt 或参数页。当前默认路径只增加这一处系统确认；结果之后的“这张还像你吗？”继续可跳过，不阻塞收藏。

## 2. 实现数据链

| 阶段 | 输入 | 输出 | 不允许的行为 |
| --- | --- | --- | --- |
| 系统生成 | 用户照片、固定内部概念 | 用户在系统页确认的不透明 AI 图 | 不把原图直接当生成结果，不暴露 Prompt 或参数 |
| AI 源固化 | 系统确认图 | 不透明 `generatedSourceImage` | 不保留透明洞作为抠图捷径 |
| AI 透明编辑 | 不透明 AI 源 | 带真实 Alpha 的主体 PNG | 不读取用户原图，不调用 Vision 兜底 |
| 白边与交付 | 透明主体 PNG | 带纯白边的透明贴纸 | 保留全部可见部件，拒绝伪透明与严重碎裂 |
| 收藏与派生 | 原图、AI 源、透明贴纸 | 收藏卡、记录和后续作品 | 不把 AI 像素降级标成“原图处理” |

关键实现：

- `SystemImagePlaygroundStickerSourceSheet` 包装 `ImagePlaygroundViewController`，预置 `sourceImage`、固定 concept、允许样式和系统 options，并在 delegate 回调中先读取临时 URL，再交还 `CreativeProviderOutput`。
- `CreateView` 用 item 驱动的全屏状态保存同一 generation ID、性能 recorder、输入来源和衣橱失败候选。系统页停留期间撤销后台处理截止，不会在用户选择时从页面下方超时；确认后才启动 150 秒 AI 透明处理截止。
- `AIStickerCreationPipeline.createSticker(from: CreativeProviderOutput)` 是系统确认图进入第二段的唯一入口。它先强制不透明，再通知上层 AI 源就绪并调用透明编辑 extractor；该入口不检查或调用旧 source generator。
- `CreativeProviderIdentifier.appleImagePlaygroundSheet` 与历史 `appleImagePlayground` 分开保存。系统页记录 provider 请求为 1、外部请求数未知、网络由系统管理、费用未公开、结果需要用户复查。
- `LegacyImageCreatorGenerator` 仍暂时服务尚未迁移的“风格花园”，不再承担默认人物贴纸第一张结果。

## 3. 取消、失败与设备边界

- 用户在系统页取消：记录同一 generation 的取消终态，关闭系统页并回到创作首页；不弹失败警告，不进入第二段。
- 系统结果 URL 无法读取：记录 `stage=ai_sticker_source` 与稳定错误码，允许重新尝试；不进入第二段。
- 系统能力不可用：沿用明确的“当前设备不能生成 AI 贴纸”恢复；只有用户主动选择后才能体验标注的内置样片。
- AI 透明编辑或 Alpha 门禁失败：说明透明处理没有完成，允许重试或换图；不改用 Vision 或原照片直抠。

`ImagePlaygroundViewController.isAvailable` 是生产门控。系统 Image Playground 仍要求支持 Apple Intelligence 的设备；当前 iPhone 11 不支持，因此这次迁移没有让 iPhone 11 获得真实 AI 生图能力。Apple 官方系统界面文档见 [ImagePlaygroundViewController](https://developer.apple.com/documentation/imageplayground/imageplaygroundviewcontroller) 与 [Image Playground](https://developer.apple.com/documentation/imageplayground)。

## 4. 隐私、网络与旧 API 边界

- 后续第二段已经新增只处理用户确认 AI 底图的开发者代理与 GPT Image 图片 API，但没有新增账号、客户端供应商密钥或后台自动上传原照片。供应商密钥只在代理环境中。
- 图片生成由 Apple 系统界面管理。Adonis 无法据此承诺完全离线、零网络或免费，所以外部请求数保持未知、费用保持未公开。
- Apple 已公告程序化 `ImageCreator` 在 iOS 27 停止工作；默认人物路径现已使用受支持的系统界面，旧符号隔离门禁仍保留给风格花园。官方公告见 [Apple Developer News](https://developer.apple.com/news/?id=dz9wvq0r)。
- 禁用旧适配器的 Release 二进制现在应继续链接受支持的 `ImagePlayground.framework` 系统页，但不得导入 `ImageCreator` 符号；旧 `SystemCreativeImageGenerator` 必须诚实报告不可用。

## 5. 自动与可见证据

本次先记录失败契约，再补实现：

- RED：新增“用户确认系统图是唯一抠图输入”和系统页 provider 契约后，测试因缺少 `appleImagePlaygroundSheet` 与 provider-output pipeline 入口而编译失败；结果包为 `.derivedData/Logs/Test/Test-Adonis-2026.08.31_13-24-12-+0800.xcresult`。
- GREEN：上述 2 个针对性单元测试 2/2 通过；结果包为 `.derivedData/Logs/Test/Test-Adonis-2026.08.31_13-29-04-+0800.xcresult`。
- 可见纵向流程：Debug 确认页明确显示“上传参考 → 模拟 AI 底图”，用户点击采用后才进入透明贴纸、AI 来源、收藏、花历和历史透明贴纸；初次 1/1 UI 流程通过，结果包为 `.derivedData/Logs/Test/Test-Adonis-2026.08.31_13-29-36-+0800.xcresult`。
- 最终专项：`make ai-sticker-regression` 通过 12 个单元/契约测试与 4 个 UI 流程，共 16/16，0 失败、0 跳过；结果包为 `.derivedData/Logs/Test/Test-Adonis-2026.08.31_13-44-49-+0800.xcresult`。其中主流程重新验证了双预览确认页、唯一 AI 抠图输入、透明结果、来源、收藏和花历。
- 旧 provider 隔离：`make legacy-provider-isolation` 通过；当前 iOS 26.5 SDK 的 unsigned Release 产物继续链接 `ImagePlayground.framework`，`nm -u` 不含 `ImageCreator`，禁用条件下的旧生成器专项测试明确返回 unavailable。

最终 UI 附件均为 iPhone 17 Pro、iOS 26.5 模拟器上的 1206 × 2622 截图，并已逐张目检：

| 附件 | SHA-256 | 目检结论 |
| --- | --- | --- |
| `Adonis-image-playground-source-approval` | `58300bef5be714c9a686cadb131301f31c9afea670906501727001806e8cf7f4` | 上传参考与模拟 AI 底图并排可辨，测试替身和非真实 Apple 效果说明清楚，采用与取消动作可见。 |
| `Adonis-ai-transparent-sticker-result` | `7fa5ed98e70b43c3372d983ffb5ec25c48e6c8d2dd4f0a7af1ed9523beab66ab` | 棋盘格透明确实可见，人物周围纯白异形边连续，来源明确为 AI 生成。 |
| `Adonis-ai-sticker-main-flow` | `c09ab9570bfc5eaa3834bda35e83475061c92a91765b4149edaeb829ae62bd9b` | 收藏完成、可选人物复核与后续派生入口仍可到达，没有新增 Prompt、模型或参数选择。 |

Debug 页固定写明“系统 Image Playground 测试替身”和“不代表真实 Apple 生图效果”，并使用 `ui_test_fixture` 元数据。第二段通过既有透明贴纸夹具跨过真实网络 provider；这只证明状态编排、数据角色、来源、保存与回看，不证明系统页或 GPT Image 真实生成、人物或衣物保真、网络、费用、取消 delegate 或未来 iOS 行为。

## 6. 尚未证明

- 未在支持 Apple Intelligence 的真实 iPhone 上打开系统 Image Playground、带入用户照片、确认真实结果并完成 GPT Image 透明编辑。
- 未验证系统界面的语言地区、内容拒绝、首次资源准备、Private Cloud Compute/网络状态、系统限额、取消 delegate、临时 URL 生命周期和长时间用户停留。
- 未使用四张授权固定原图对真实系统结果逐项评价身份、脸、发型、身形比例、姿势、衣物、鞋包配饰和缺失/多余内容。
- 未在真实 iOS 27 SDK 上重新执行编译和旧符号隔离门禁。
- “风格花园”仍依赖 iOS 26 旧 `ImageCreator` 适配器，尚未迁移到长期 provider。
