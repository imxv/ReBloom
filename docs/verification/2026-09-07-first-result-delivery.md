# 2026-09-07 首屏与结果交付优化

> 状态：本轮实现、静态分析、专项回归、全量模拟器测试与截图目检完成。对应 ADO-003；真实 AI、真机与用户价值验收仍待完成。

## 用户可见变化

- 首页 Hero 最小高度从 290 点缩为 220 点，保留内容驱动高度与动态字号，提前露出内置样片。两个纯装饰圆形不再参与点击，避免越出卡片后挡住设置按钮。
- 结果页使用独立底栏持续展示唯一“收藏今天”；滚动区与底栏分别布局。处理风格创作时仍与底层页面一起禁用。
- “存透明贴纸 / 分享”移至来源说明之后、可选复核与创作入口之前；保留权限拒绝、重试与分享恢复。
- AI 收藏记录没有衣物线索时，说明“衣物以原照片为准”，不再把主动跳过分析描述成姿势或遮挡失败。非 AI 历史空态及已有衣物关系保持原样。

## 最终验证

`make check` 通过严格 Swift 格式检查与通用 iOS 静态分析，日志为 `/tmp/adonis-iteration-check-v3.log`。下表专项存在用例重叠，不应相加作为独立测试总数。

| 命令 | 结果 | iOS 测试数 / 检查范围 |
| --- | --- | --- |
| `make ai-sticker-regression` | 通过 | 28 |
| `make ai-sticker-visual-regression` | 通过 | 资产与视觉清单检查 |
| `make sample-regression` | 通过 | 28 |
| `make performance-regression` | 通过 | 18 |
| `make photo-save-regression` | 通过 | 6 |
| `make persistence-regression` | 通过 | 5 |
| `make figurine-regression` | 通过 | 7 |
| `make wardrobe-visual-regression` | 通过 | 21 |
| `make accessibility-regression` | 通过 | 12 |
| `make test` | 通过 | 234 |

最终全量结果为 **234 通过、0 失败、0 跳过**：`Test-Adonis-2026.09.07_04-12-15-+0800.xcresult`。最大辅助字号与增强对比度专项为 **12 通过、0 失败、0 跳过**；脚本退出时恢复模拟器设置。测试日期 2026-09-07，设备为 iPhone 17 Pro / iOS 26.5 模拟器。

[结构化验证记录](../evidence/first-result-validation-2026-09-07.json) 保留各次执行结果与 `.xcresult` 路径，包括中途失败。原始日志与测试包为本机证据，不包含在发布包中。

## 回归中发现并修复的问题

1. 初版 `safeAreaInset` 底栏与滚动内容的点击区域重叠，复核与退出按钮被误判为可点击。改成滚动区与底栏上下独立布局，未放宽操作断言。失败记录：`Test-Adonis-2026.09.07_03-26-31-+0800.xcresult`。
2. 第二轮大字号中，首页用例错误地只查找普通字号分段控件。测试改为分别检查分段控件和辅助字号菜单的默认“收藏卡”，保留首屏收藏可点击与屏幕范围断言。失败记录：`Test-Adonis-2026.09.07_03-31-56-+0800.xcresult`；最终专项通过。
3. 首页缩短后，视觉裁切外的装饰圆形拦截设置按钮，使超时、正常完成与取消后的三个性能查看流程失败。为两个装饰圆形添加 `allowsHitTesting(false)` 后，原测试与全量测试通过。失败记录：`Test-Adonis-2026.09.07_03-48-56-+0800.xcresult`。
4. 首次冷启动门禁因模拟器拒绝启动 App（`Busy / Application failed preflight checks`）失败，尚未执行到收藏恢复。重新启动模拟器后，同一用例与最终全量测试通过；未清除生产数据或修改存储逻辑。

## 截图目检

| 截图 | 当前可确认的事实 |
| --- | --- |
| [普通字号首页](../evidence/first-result-home-2026-09-07.png) | 首屏能看见原图与 AI 样片预览，保留明确来源 |
| [普通字号结果首屏](../evidence/first-result-first-screen-2026-09-07.png) | 收藏卡默认显示，收藏按钮完整可见 |
| [结果操作顺序](../evidence/first-result-delivery-actions-2026-09-07.png) | 存贴纸、分享在可选创作之前；滚动后底部收藏仍可见 |
| [AI 收藏衣物说明](../evidence/first-result-ai-clothing-boundary-2026-09-07.png) | 空态说明实际跳过原因，不制造衣物事实 |
| [最大辅助字号首屏](../evidence/first-result-accessibility-2026-09-07.png) | 收藏按钮完整可见，预览区继续滚动 |
| [最大辅助字号复核](../evidence/first-result-fidelity-accessibility-2026-09-07.png) | 原图与最终 AI 贴纸纵向对照，复核表单可滚动 |

截图均取自本轮通过的模拟器测试，使用已声明的内置 AI 样片或 Debug 夹具，未重录或替换图像回归基线。

## 范围与额度

本轮开始时账户主额度已用 85%，最后一次读数为已用 86%。持续按实时账户读数控制，不使用额度重置。此前已存在的未提交首页 AI 样片、适配器、测试和文档改动保留；本轮没有提交、推送或部署。

本轮不改变供应商、上传范围、生成像素、PhotoKit 写入、存储事务或衣物关联算法。模拟器证据不能证明真实 Apple/OpenAI 输出、人物与衣物保真、系统照片实际写入、VoiceOver 或真实 iPhone。

已另备 [首轮五人无讲解测试](../first-user-test.md) 执行模板；尚未招募或执行，不据此勾选 ADO-008。ADO-006、ADO-108 与真实用户验收继续保持未完成。
