# 2026-08-31 首页 AI 样片重新生成验证记录

> 结论：创作首页前三张示例已经重新生成并接入为“授权原图 → 预生成 AI 透明贴纸”。每张卡仍只有一次点击；首页、结果页和派生收藏卡都按实际像素标为“AI 生成”。四张历史 Vision 直抠样片及 C 级 sample-04 未被覆盖或删除。
>
> 读者：以后修改首页样片、图片提示、语义抠图、透明边缘、来源标签或能力不可用恢复的工程 Agent。

## 1. 用户体验与来源契约

- 首页标题为“内置 AI 样片 · 已预生成”，并排显示授权原图与最终 AI 透明贴纸。
- 右侧贴纸必须是真实 Alpha PNG，轮廓外是透明像素，轮廓上是连续纯白贴纸边；不得接受画出来的棋盘格。
- 点卡片直接进入收藏卡、透明贴纸、原始照片、可选人物/穿搭复核、收藏和分享，不增加模型、Prompt、参数或模板选择。
- 这些图片包含 Codex 内置图片能力生成或重绘的像素，因此即使点击时没有网络请求，也必须标为“AI 生成”。
- “预生成”只表示图片已归档进 App，不表示当前设备实时运行了 Apple Image Playground、GPT Image 或任何线上 provider。
- 三张结果均出现人物、姿势、衣服或配饰变化，只可用于首页示例；不得把 Alpha、纯白边或视觉好看解释为本人和穿搭保真。

## 2. 两段生成与抠图方式

本次使用 Codex 内置 `imagegen` 图片编辑能力，输入均为用户已明确提供并登记在 `regression-baseline.json` 的前三张照片。

```text
授权原图
  → 内置 imagegen 生成不透明 AI 贴纸底图
  → 逐张目检主体、衣物、手持物与配饰
  → 内置 imagegen 把完整主体语义隔离到单色绿幕
  → 逐张目检分离部件与边缘完整性
  → scripts/generate_homepage_ai_sticker.sh
       绿幕颜色估计 → 真实 Alpha → 去绿污染 → 纯白边 → 裁切/1536 长边
  → 逐张透明背景目检与像素门禁
```

接受的最终提示规范分成两种编辑角色：

1. 不透明底图：只把所附原图作为人物、穿搭、姿势、手持物和配饰事实参考；移除原环境，生成完整单人、暖白纯色背景、贴纸感但不加描边的不透明图。逐张明确锁定饮料与吸管、包、蝴蝶结、波点、金属编织包、甜点托盘、宽腿裤和鞋等容易遗漏元素。
2. 语义隔离：只把背景替换为均匀、无阴影、无纹理的高饱和绿色；完整保留 AI 底图中的人、头发、双手、鞋、包、饮料、吸管、甜点、托盘、蝴蝶结和其他分离部件，不新增白边、棋盘格或透明效果。

直接要求内置图片能力输出透明 PNG 的候选没有真实 Alpha，而是在不透明图片里绘制棋盘格，因此被拒绝。最终流程使用内置图片能力做语义主体隔离，再用可审计脚本形成真实 Alpha；这仍是“先生成 AI 贴纸图，再对该 AI 图抠图”，没有回到原图 Vision 直抠。

## 3. 资产、人工结论与可重复范围

清单 `Adonis/Resources/Samples/homepage-ai-showcase.json` 保存授权、工具模式、版本、文件哈希、尺寸、绿幕参数、请求次数和人工结论。

| 样片 | AI 底图 | 最终贴纸 | Alpha 目检 | 内容保真目检 |
| --- | --- | --- | --- | --- |
| sample-01 | 1086 × 1448，不透明 | 811 × 1536，真实 Alpha | 可接受；吸管、饮料、包完整，纯白边连续 | 有变化：脸、姿势、衣服与配饰细节 |
| sample-02 | 1086 × 1448，不透明 | 545 × 1536，真实 Alpha | 可接受；双手和金属包完整，纯白边连续 | 有变化：脸、手势与包纹理 |
| sample-03 | 1086 × 1448，不透明 | 557 × 1536，真实 Alpha | 可接受；甜点、托盘、包、裤腿和鞋完整 | 有变化：脸、局部衣物与饰品 |

非确定性的 AI 输出以提交的底图和绿幕候选归档，不声称可以从 Prompt 逐像素复现。`scripts/generate_homepage_ai_sticker.sh` 与清单参数可以把三张审核绿幕逐字节重建为提交的透明贴纸。历史 `regression-baseline.json`、`sample-*-sticker.png` 与 sample-04 保持不变。

## 4. App 接入与测试夹具边界

- `SampleCatalog.homepagePhotos` 只包含前三张、具备 AI 底图和 AI 透明贴纸的首页样片；`SampleCatalog.showcasePhotos` 继续保留历史 A 级 Vision 样片给独立回归使用。
- Release、普通手动 Debug 与普通 `-ui-testing` 点击首页样片时，结果都保存 AI 底图、透明贴纸和 `.aiGenerated` 来源，可进入人物/穿搭复核。
- 普通收藏卡、数字手办收藏卡、保存后的 `OutfitRecord` 与花历历史重开都读取同一张首页 AI 贴纸。缺少声明的 AI 资产时直接报错，不得静默回退到历史直抠贴纸。
- 历史 `sample-*-sticker.png` 只由 `-ui-testing-historical-sample-fixture` 显式启用，服务仍需旧“原图处理”语义的隔离算法回归；它不属于当前产品路径、默认测试夹具或现行视觉证据。
- 样片点击不调用运行时图片 provider，清单明确记录 `runtimeProviderRequestCount = 0`。它不能作为不可用设备的 provider 兼容方案。

## 5. 当前证据

- `make sample-regression` 最终通过 28/28，结果包为 `.derivedData/Logs/Test/Test-Adonis-2026.08.31_20-07-09-+0800.xcresult`；它覆盖四张历史样片、三张首页 AI 资产、真实 Alpha 结构和三次绿幕后处理逐字节重建。三张贴纸均只有一个主体连通分量，四角透明，主体边界包含纯白像素；脚本重建结果与提交文件逐字节一致。
- 同一条固定样片回归还逐张用三张首页 AI 贴纸生成普通收藏卡与数字手办收藏卡，并断言六张当前卡片都与对应历史直抠卡片字节不同，防止渲染器或夹具重新接回旧图。
- `make ai-sticker-regression` 通过 3/3 代理测试、22/22 iOS 单元测试和 6/6 UI 流程；新增 `testHomepageAISampleKeepsAIProvenanceAfterOpeningResult` 验证卡片点击后仍是 AI 底图、AI 透明贴纸与 `.aiGenerated`，并能进入人物/穿搭复核。该专项最初确实发现首页点击仍命中一处分散的历史 UI 夹具判断，修复为统一门控后重新通过。
- `make ai-sticker-visual-regression` 通过，四组既有 AI 视觉固定对继续满足哈希、尺寸与真实 Alpha 门禁；`make performance-regression` 通过 14/14 单元测试和 4/4 UI 流程。
- `make accessibility-regression` 通过 1/1 单元检查和 11/11 最大字体 UI 流程；该专项结果包已被后续测试轮换，全量结果包继续覆盖相同 UI 用例。
- `make check` 通过严格 `swift-format`、XcodeGen 与通用 iOS 静态分析。
- `make test` 最终通过 234/234（192 个单元测试、42 个 UI 流程，0 失败、0 跳过），结果包为 `.derivedData/Logs/Test/Test-Adonis-2026.08.31_19-49-05-+0800.xcresult`；`xcresulttool` 独立读取为 `Passed`。
- 模拟器首页截图为 [`docs/evidence/homepage-ai-showcase-2026-08-31.png`](../evidence/homepage-ai-showcase-2026-08-31.png)，SHA-256 为 `cb9dec7ce556c640c5fb8babb2f385966988109c5572e43f9046e7c16e27f167`。人工目检确认首屏清楚显示原图、AI 贴纸、AI 来源和一次点击入口。
- 普通收藏卡截图为 [`docs/evidence/homepage-ai-collection-card-2026-08-31.png`](../evidence/homepage-ai-collection-card-2026-08-31.png)，SHA-256 为 `ad3802c854b919482975b500408ece0eedd4137db4275d1cabe6ae64c1e53265`；数字手办收藏卡截图为 [`docs/evidence/homepage-ai-digital-figurine-card-2026-08-31.png`](../evidence/homepage-ai-digital-figurine-card-2026-08-31.png)，SHA-256 为 `70a15dfc0bdc0088723d032ec2b64a78cf374480767a7cca0fcb734d3082079e`。两张均为 iPhone 17 Pro、iOS 26.5 模拟器 1206 × 2622 的真实 UI 附件；人工目检确认主体、衣物、配饰和连续白边来自新 AI 贴纸，来源说明保持“AI 生成”。

Xcode 当前只保留了上述全量与固定样片两个最新结果包；更早的专项 `.xcresult` 已由后续测试轮换清理，因此本记录不把已不存在的旧路径作为可复查证据。专项命令的最终通过结论与关键数量保留在本记录中，全量结果包同时覆盖新增单元与 UI 用例。

## 6. 尚未证明

- 没有证明真实 Apple Image Playground 或 GPT Image 的输出、网络、费用、时延与边缘质量。
- 没有证明支持 Apple Intelligence 的真实 iPhone、VoiceOver、分享目的地或相册写入。
- 没有证明三张 AI 样片像本人或准确保持穿搭；人工结论明确为 `changed`。
- 没有证明真实用户会理解、保存或分享这些样片；这仍属于 ADO-008。
- 三张授权全身样片不足以证明半身、坐姿、多人、复杂遮挡、浅色边缘或泛化质量；ADO-005 与 ADO-006 继续未完成。
