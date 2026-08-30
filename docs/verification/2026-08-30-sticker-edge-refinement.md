# 2026-08-30 贴纸边缘细化验证

> 结论：Adonis 已在 Vision 粗蒙版之后增加受原图边缘引导的 Alpha 细化。它只改变透明度，不生成、补画或重绘人物、脸、衣物和配饰的 RGB 像素；纯白贴纸边仍在细化后的主体外生成。四张授权固定样片已重新目检并录入新基线，前三张继续展示，sample-04 的软垫粘连仍是 C 级拒绝案例。

## 1. 本轮目标

用户已经明确要求贴纸尽量保持原照片中的元素不动，只得到干净透明主体和纯白贴纸边。本轮没有增加新的风格选项、参数页或确认步骤，而是改进现有默认处理链路：

1. Vision 继续提供人物粗蒙版。
2. 原始蒙版质量门禁先运行，避免后处理掩盖空主体、严重碎裂或大块背景粘连。
3. `StickerMatteRefiner` 使用原图亮度边缘引导粗蒙版上采样，并把结果限制在粗蒙版定义的 trimap 未知区域内。
4. 明确前景阈值 `0.99` 与明确背景阈值 `0.01` 保持不变；只有中间过渡区允许细化。
5. `CIBlendWithMask` 只把细化结果写入 Alpha，主体颜色继续逐像素来自输入照片。
6. 白色轮廓根据细化后的 Alpha 生成，再进入裁切、放大和收藏卡排版。

当前 Core Image 参数为 `inputSpatialSigma = 3`、`inputLumaSigma = 0.15`。固定样片生成脚本使用同一套参数与 trimap 约束，处理版本提升为 `sticker-vision-edge-refine-v2`。

## 2. TDD 契约

实现按三个先失败、后通过的行为契约推进：

- 相同输入范围下，细化蒙版尺寸必须不变，明确前景仍不透明、明确背景仍透明。
- 在相同粗蒙版下，原图亮度边缘位置改变时，Alpha 过渡也应随原图边缘移动，证明它不是普通双线性放大。
- 提取后的半透明像素按非预乘颜色还原后必须等于原照片，只允许 Alpha 改变。

三个新增测试与既有 `StickerProcessorTests`、`RawMatteQualityGateTests`、`StickerQualityAssessorTests`、`SampleRegressionTests` 一起进入 `make sample-regression`，防止后续重构悄悄改回重绘或无引导缩放。

## 3. 固定样片目检与新基线

候选结果先写入临时目录，再与旧基线逐张查看全图和边缘细节；确认变化有意后才替换仓库资产。目检观察到边缘过渡更平顺，没有发现主体图案、手持物、脸部或衣物被重新生成。变化主要发生在 Alpha 过渡，不能据此宣称已经达到专业发丝抠图。

| 样片 | 新尺寸 | 新贴纸 SHA-256 | 人工结论 |
| --- | --- | --- | --- |
| sample-01 | 848 × 1536 | `c07053dcd70651c8951e4090d259b7f230b78123af47b88c95c8c007d4f0f616` | A 级展示；饮料、包与衣物元素保留，少量灰白边缘仍存在。 |
| sample-02 | 547 × 1536 | `d2634c153cb6c7944e3e7b84a094af77e1b48afaa5eaf364e897ce9b2caff51a` | A 级展示；人物与金属包保留，接触墙面和长椅处仍有残留。 |
| sample-03 | 529 × 1536 | `17be951440b4148a2a6c7abfb1e3975e876e4d95a1ccdad784d65a1a9c0640bf` | A 级展示；托盘、手与衣服图案保留，复杂背景交界仍有少量残留。 |
| sample-04 | 1176 × 1536 | `e89b89c7bb6258bb86eb8e13f54258f6cfffff2d3d46069340055972358329d9` | C 级拒绝；大块浅色软垫仍被并入主体，不进入普通入口或收藏卡。 |

精确像素指标、授权来源、覆盖标签和已知缺陷统一见 [固定样片回归基线](2026-08-30-sample-regression-baseline.md) 与 `Adonis/Resources/Samples/regression-baseline.json`。

## 4. 当前执行证据

- `make sample-regression`：四张源图和贴纸哈希通过，macOS 重生成与仓库结果逐字节一致；23 项测试全部通过、0 失败、0 跳过。结果包：`.derivedData/Logs/Test/Test-Adonis-2026.08.30_20-36-30-+0800.xcresult`。
- `make test`：185 项全部通过、0 失败、0 跳过，其中 153 个单元测试、32 个真实模拟器 UI 流程。结果包：`.derivedData/Logs/Test/Test-Adonis-2026.08.30_20-37-45-+0800.xcresult`。
- 两个结果包均使用 `xcresulttool get test-results summary` 独立确认。
- `make check`：严格 `swift-format` 与通用 iOS 设备静态分析通过。
- unsigned Release 通用 iOS 构建通过；主 App 与分享扩展均由 `file` 确认为 Mach-O 64-bit arm64。
- `xcrun devicectl list devices` 显示登记的 iPhone 11（`5079B30A-3FD0-5BBC-8E29-D58F0C4E999B`）为 `unavailable`，因此没有把通用设备构建当作真实 iPhone 运行证据。

## 5. 尚未证明

- 真实 iPhone 上实时 Vision 粗蒙版与边缘细化的最终质量、性能和内存占用。
- 蓬松发丝、透明或半透明衣料、多人、严重遮挡、运动模糊和更复杂手持物的泛化质量。
- sample-04 的背景粘连问题没有修复；边缘细化不能替代语义级前景纠错。
- 当前本机链路仍是离线基线，不等于专业人像抠图模型，也不证明用户愿意保存或分享结果。

下一步必须在真实 iPhone 和更多授权失败样本上验证，再决定是否引入更强的 trimap/refinement 模型或单独的多人、物体处理路由。
