# 2026-08-29 生成内容来源标识验证记录

> 当前结论（2026-08-31 更新）：Adonis 在不增加上传前问题的前提下，统一区分原始图片、原图处理、程序排版、识别建议、AI 补全与 AI 生成。默认人物贴纸现为“AI 生成不透明源 → 对生成源抠图”，因此透明贴纸、收藏卡及使用该贴纸的派生作品均按实际情况保留 `ai_generated`；历史直抠样片仍为 `derived_from_original`。下文 2026-08-29 的截图与测试数字是当时基线，不代表当前默认像素来源。

## 来源类型契约

`VisualContentProvenance` 提供六个稳定、可编码的类型：

| 代码值 | 用户名称 | 约束 |
| --- | --- | --- |
| `user_provided` | 原始图片 | 用户选择、拍摄或主动分享，Adonis 没有改动画面内容 |
| `derived_from_original` | 原图处理 | 只做背景移除、裁切、透明通道与纯白边，不重绘主体 |
| `programmatic_composition` | 程序排版 | 程序只新增日期、花朵和版式；输入含 AI 像素时，最终来源必须继续为 AI 生成 |
| `recognition_suggestion` | 识别建议 | 本机分析得到，确认前只是一条建议 |
| `ai_filled` | AI 补全 | 未来用于标记 AI 补充的缺失、遮挡或画面外区域 |
| `ai_generated` | AI 生成 | AI 新生成或重绘的内容；当前用于默认透明贴纸及其派生作品，以及风格花园 |

只有后两类的 `containsAIGeneratedPixels` 为 `true`；只有识别建议的 `requiresUserConfirmation` 为 `true`。接入试穿、风格化或其他供应时，不得复用“原图处理”逃避 AI 内容说明。永生花园另以 `user_review_required` 执行质量状态要求用户主动对照，但这与“识别建议等待确认”是不同维度。

## 低心智负担交互

- 上传前仍只有统一图片入口，不要求用户选择生成方式、模型或来源类型。
- 结果默认直接展示收藏卡；同一个三段切换提供“收藏卡 / 透明贴纸 / 原始照片”。切换后，格式标签、来源说明和系统分享对象同步变化。
- 结果说明放在图片和两个轻量标签之后，不抢占首个结果；原有“收藏今天 / 分享 / 再做一张”三个动作不变。
- 花历详情使用同一三段切换和同一来源说明，避免首次结果与历史解释不一致。
- 衣橱颜色、画面类型和未确认分类显示为“识别建议”，并明确人工分类始终优先。
- OOTD 上身与下身线索也显式写为“本机识别建议”，确认前不影响衣橱。

## 分享卡与透明贴纸

1080 × 1440 收藏卡的页脚按贴纸来源动态生成：历史直抠贴纸可说明人物与衣物来自原图；默认 AI 贴纸显示“贴纸由 AI 生成 · 卡面由 ADONIS 排版”。声明使用次级字号，不遮挡人物、日期、Bloom 编号和品牌主标题。

透明贴纸本体继续保持无水印。来源取决于抠图输入：直接从可信原图产生时属于原图处理；默认从 AI 不透明生成源产生时仍属于 AI 生成。App 在结果与历史中解释，不把文字烘焙到用户可能继续创作的 PNG 上。

## 个人数据导出

标准 TAR 的 `manifest.json` 新增 `visualAssets`。每个条目包含：

- 图片路径与业务角色；
- 所属记录 ID；
- 机器可读来源类型和用户说明；
- 是否包含 AI 生成像素；
- 是否等待用户确认。

2026-08-29 的 v7 导出测试固定创建 1 条 OOTD、1 件衣物、1 条线索、1 张花影海报、1 张永生花园和 1 张待导入图片，共验证 8 个视觉资产条目；当时只有永生花园包含 AI 生成像素。当前 `adonis-personal-data-v8` 另保存默认 AI 不透明贴纸源、贴纸/收藏卡动态来源和 provider 执行元数据，现行证据见 [AI 贴纸先生成后抠图验证记录](2026-08-31-ai-sticker-first-pipeline.md)。

## 自动验证

- 来源契约与个人数据导出的 7 个专项单元测试通过，0 失败；结果包为 `.derivedData/Logs/Test/Test-Adonis-2026.08.29_23-43-07-+0800.xcresult`。
- 结果、历史和衣橱的 2 个专项 UI 流程测试通过，0 失败；结果包为 `.derivedData/Logs/Test/Test-Adonis-2026.08.29_23-43-54-+0800.xcresult`。
- 最新完整执行 `make check`，严格 `swift-format` 与通用 iOS 设备静态分析通过；执行 `make test`，127 个单元测试与 28 个 UI 流程测试共 155 项全部通过、0 失败、0 跳过。`xcresulttool` 独立汇总一致，结果包为 `.derivedData/Logs/Test/Test-Adonis-2026.08.30_11-55-11-+0800.xcresult`。
- 最终 XCTest 生成的 TAR 已从结果包导出，再由 macOS `tar -tf`、`tar -xOf` 与 `jq` 独立读取。归档包含清单、7 个媒体文件和 1 张待导入图片；`visualAssets` 实际为 8 项，只有永生花园的 `containsAIGeneratedPixels` 为 `true`，只有 `garment_observation_preview` 的 `requiresUserConfirmation` 为 `true`。

## 界面证据

以下截图来自 iPhone 17 Pro、iOS 26.5 模拟器的 UI 测试附件，不是设计稿。

![首次结果在主要内容之后说明程序排版](../evidence/content-provenance-result-2026-08-29.png)

![花历详情沿用同一来源说明](../evidence/content-provenance-history-2026-08-29.png)

![衣橱本机分析明确标为识别建议](../evidence/content-provenance-recognition-2026-08-29.png)

三张原图均为 1206 × 2622。逐图检查结果：三段切换没有截断；收藏卡人物、衣物、主标题、日期和 Bloom 编号未被新增说明遮挡；来源说明在结果之后且主要按钮仍可滚动到达；衣橱识别说明没有遮挡一键分类入口。

文件 SHA-256：

- `content-provenance-result-2026-08-29.png`：`dc623294ac6e2590aa567875224f27cbeb770197744a8e94d22c1a6867ce9b8a`
- `content-provenance-history-2026-08-29.png`：`9afc12f5ead047fe978dcdd14937cc370c10393d36c6fbbdf9e1c81a2a641f35`
- `content-provenance-recognition-2026-08-29.png`：`643c0554f1694bceae4a40461bd9d24c65c8f12dfbff1486af163bcf3131f9d4`

## 尚未证明

- 当前没有接入 AI 补全或供应商级虚拟试穿。默认 AI 贴纸和风格花园都已适配 Apple 系统图片生成，但模拟器成功图仍是 Debug 夹具，尚无真实 Apple 输出质量证据；详见 [AI 贴纸先生成后抠图验证记录](2026-08-31-ai-sticker-first-pipeline.md)与 [永生花园系统创作验证记录](2026-08-30-mythic-garden.md)。
- 收藏卡来源声明是否足够被首轮用户理解，仍需无讲解测试。
- 动态字体、VoiceOver 和真实 iPhone 分享到不同目标的体验归入 ADO-Q07，尚未完成。
