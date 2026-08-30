# 2026-08-31 AI 贴纸先生成后抠图验证记录

> 状态：主链路、来源、持久化、Debug 产品回归、模拟器全量回归与 arm64 Release 构建已验证；真实 Apple 输出和真实 iPhone Vision 仍待验证。
>
> 对应任务：ADO-006、ADO-105、ADO-Q02、ADO-Q04、ADO-Q05、ADO-Q06

## 1. 用户决定与生产契约

本轮锁定的默认人物贴纸链路是：

```text
用户原始照片
  → Apple ImageCreator 按隐藏配方生成不透明贴纸形象
  → 将 AI 生成图压平为不透明白底图
  → StickerProcessor 只对这张 AI 图抠图、细化 Alpha 并加纯白边
  → 透明贴纸
  → 程序排版收藏卡与后续派生作品
```

关键不变量：

- 抠图输入必须是 AI 生成图，不是用户原图。
- AI 能力不可用、生成失败或生成图抠图失败时，不得静默退回用户原图直抠。
- 用户只选择或拍摄一张图片，不需要选择 Prompt、Skill、模型、风格或参数。
- 用户原图始终保留为对照；透明贴纸、收藏卡及使用它们的派生作品必须按实际情况标为“AI 生成”。
- “尽量保持本人、姿势、衣物颜色与细节、鞋、包、配饰、头发和身体比例”是隐藏配方的目标，不是当前已经证明的质量保证。
- AI 贴纸不得用于建立事实性 OOTD 衣物线索或自动污染衣橱。

四张历史固定样片仍保留为人像分割、Alpha、白边和困难边缘的直抠算法回归。它们不是默认上传链路，也不能证明 Apple AI 输出质量。

## 2. 实现边界

### 2.1 AI 源与抠图顺序

- `AIStickerCreationPipeline` 先通过 `CreativeAIStickerSourceGenerator` 调用 `.aiStickerSource`，拿到 provider 图片与执行元数据。
- provider 图片按实际像素尺寸压平到不透明白色画布；即使 provider 返回透明区域，进入抠图前也不再透明。
- `onGeneratedSource` 在抠图前触发，用于结束 AI 生成计时、保存 provider 执行元数据并开始主体分割阶段。
- `StickerExtractor` 只接收压平后的 AI 图。
- `.aiStickerSource` 不进入用户可见的风格花园目录；当前映射到 Apple animation style，内部概念固定要求单人、完整人物、干净暖白背景、无文字、无边框和不裁肢体。

### 2.2 主页面与失败语义

- `CreateView` 对真实相册或相机人物输入执行 AI 生成 → 抠图 → 质量闸门 → 收藏卡。
- 失败事件使用稳定错误码并记录 `fallback=none`。
- AI 能力不可用时明确说明系统创作能力尚未准备好；生成或抠图失败时允许重试或换图，不交付原图直抠替代品。
- 超时降级只能交付同一次 AI 链路中已经通过结构检查并完成排版的中间结果。
- 预处理好的内置样片继续走旧回归链路；它们是快速预览和困难样本基线，不是生产上传证明。

### 2.3 来源、存储与导出

| 资产 | 来源契约 |
| --- | --- |
| 用户原图 | `userProvided` |
| AI 不透明贴纸源 | `aiGenerated` |
| 从 AI 源抠出的透明贴纸 | `aiGenerated` |
| 使用 AI 贴纸的收藏卡 | `aiGenerated`，同时说明版式由 Adonis 完成 |
| 花影海报、月度 Lookbook、数字手办等派生作品 | 输入含 AI 像素时继续为 `aiGenerated` |
| 历史直抠固定样片 | `derivedFromOriginal` |

收藏事务会同时保存 `source.png`、`ai-sticker-source.png`、`sticker.png` 与 `card.png`；任一步失败会回滚本次已写媒体。删除 OOTD 时也会删除可选 AI 源。

`adonis-personal-data-v8` 增加：

- `outfit_ai_sticker_source` 视觉资产；
- 每条 OOTD 的 AI 源路径、贴纸与收藏卡实际来源；
- Apple provider、provider 请求数、外部请求数、网络与费用口径；
- AI 生成阶段及其执行元数据。

Apple 当前只向 App 暴露系统能力边界。Adonis 记录 provider 请求为 1、外部请求数未知、网络为 `system_managed`、费用未公开；不得改写成离线、零网络或免费。

## 3. TDD 与自动化证据

### 3.1 失败先行

引入生产实现前，以下测试结果记录了缺少类型、顺序、回调或持久化契约的失败：

- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_00-50-55-+0800.xcresult`
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_00-52-04-+0800.xcresult`
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_00-55-15-+0800.xcresult`
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_01-00-39-+0800.xcresult`

### 3.2 已通过的专项与全量证据

- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_03-05-11-+0800.xcresult`：最终代码状态下的 `make ai-sticker-regression` 通过 7 个单元测试与 1 个 UI 流程。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_01-38-09-+0800.xcresult`：`make sample-regression` 通过 27 项固定样片与抠图回归。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_01-40-14-+0800.xcresult`：`make performance-regression` 通过 14 个单元测试与 4 个 UI 流程。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_01-41-51-+0800.xcresult`：`make creative-regression` 通过。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_01-44-47-+0800.xcresult`：`make lookbook-regression` 通过 5 个单元测试与 1 个 UI 流程。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_01-46-41-+0800.xcresult`：`make figurine-regression` 通过。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_01-48-08-+0800.xcresult`：`make photo-save-regression` 通过 4 个单元测试与 2 个 UI 流程。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_02-16-52-+0800.xcresult`：`make input-routing-regression` 通过 11 个单元测试与 2 个 UI 流程。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_02-35-27-+0800.xcresult`：`make accessibility-regression` 通过 1 个单元测试与 7 个 UI 流程。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_02-46-41-+0800.xcresult`：最终 `make test` 共 214 项通过，包含 177 个单元测试与 37 个 UI 流程，0 失败。

核心断言包括：

- 透明 provider 像素会先压平为不透明白色；
- 抠图收到的像素来自 AI 图，与用户原图不同；
- 阶段顺序严格为 `ai_source_ready` → `matting`；
- 隐藏适配器固定调用 `.aiStickerSource`；
- AI 来源与 provider 元数据从 `GenerationDraft` 保存到 `OutfitRecord`；
- 分享卡页脚披露 AI 贴纸像素；
- 花影海报、数字手办与月度 Lookbook 会继承 AI 来源；
- 导出包含 AI 源、动态来源和执行元数据。

专项命令：

```sh
make ai-sticker-regression
```

它组合运行 AI pipeline、性能元数据、分享卡来源、个人数据导出与专用 UI 流程。专项结果页附件 `Adonis-ai-transparent-sticker-result` 与 `Adonis-ai-sticker-main-flow` 已人工目检：透明棋盘格可见、纯白贴纸边连续，并明确显示“AI 生成 · 画面包含 AI 生成或重绘”。

## 4. Debug UI 夹具与真实边界

`-ui-testing-ai-sticker-main-flow` 只在 Debug 构建中生效：

1. 生成端把授权 sample-01 的已知透明贴纸合成到 1080 × 1440 不透明白底画布，作为确定性 AI 源夹具。
2. 该生成图确实先到达抠图边界。
3. 当前 iOS 26.5 模拟器无法创建 Vision 推理上下文，因此该单一参数下的 Debug extractor 返回对应授权样片的已知透明贴纸，以继续验证结果、来源、收藏和历史。

在加入第二段 Debug 夹具前，两次真实模拟器 Vision 尝试都稳定显示“这张 AI 贴纸还抠不干净”，没有改用原图直抠：

- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_01-15-38-+0800.xcresult`
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_01-19-29-+0800.xcresult`

因此 UI 成功回归只证明产品链路。它不证明：

- Apple `ImageCreator` 在真实设备可用；
- Apple 真实输出会稳定保持本人、衣物、姿势和配饰；
- 真实 iPhone Vision 能把该生成图抠干净；
- Apple 实际网络行为、费用、时延或资源下载方式；
- 真实相册、分享目的地或 VoiceOver 行为。

Release 构建不得包含或接受该 UI 测试入口。

## 5. 最终工程验证

- `make check` 通过严格 Swift 格式检查与通用 iOS 静态分析。
- 无签名 Release 通用 iOS 构建通过；`Adonis.app/Adonis` 为 arm64 Mach-O 可执行文件。
- 对 Release 二进制执行字符串扫描，没有发现 `-ui-testing-ai-sticker-main-flow`，Debug AI 夹具未进入 Release 产物。
- 首轮全量结果 `Test-Adonis-2026.08.31_02-00-05-+0800.xcresult` 暴露了一条仍期待旧“失败后收进衣橱”行为的测试；契约改为 AI 不可用时只允许换图，不绕过 AI 贴纸链路。
- 次轮全量结果 `Test-Adonis-2026.08.31_02-17-38-+0800.xcresult` 的产品界面已显示、启用且位于屏幕内，但 XCUI 在可点击检查与实际点击间发生竞态；测试保留可点击断言并改为点击元素中心坐标。随后专项回归与最终 214 项全量回归均通过。

这些结果证明当前代码、确定性夹具、模拟器产品链路和 arm64 构建边界；不把它们表述为真实 Apple 图片生成、真实 iPhone Vision、真实 PhotoKit、系统分享目的地或 VoiceOver 证明。

## 6. 仍待验证

- 在支持 Apple 系统图片生成的真实 iPhone 上完整运行“选图 → AI 生成 → 抠图 → 收藏 → 花历重开”。
- 对授权固定样本逐项评价脸、发型、肤色、身体比例、姿势、衣服颜色/图案/领口/袖型/长度、鞋、包和配饰。
- 记录真实成功率、耗时、失败原因、取消、弱网、系统资源下载与重试行为。
- 使用新生成图检查头发、透明材质、手持物、遮挡、半身、多人和浅色背景的抠图边界。
- 由首轮目标用户无讲解完成流程，确认作品是否值得收藏或分享到社交媒体。
