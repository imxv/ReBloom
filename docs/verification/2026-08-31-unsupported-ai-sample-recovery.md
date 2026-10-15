# 2026-08-31 AI 生图不可用时的样片恢复验证记录

> 现行更新：内置样片恢复已经从历史 Vision 直抠结果换为预生成 AI 底图及其真实 Alpha 贴纸，必须标为“AI 生成”并允许可选人物/穿搭复核。更换资产、来源与专项证据见 [首页 AI 样片重新生成验证记录](2026-08-31-homepage-ai-showcase.md)。本文第 4 节保留更换前的历史回归事实，不再代表当前 Release 样片像素来源。
>
> 状态：能力不可用提示、明确标注的内置 AI 样片恢复、来源边界、专项自动化与模拟器视觉结果已有验证；支持 Apple Intelligence 的设备使用系统 Image Playground，再经 GPT Image 透明编辑。不支持设备的第一段生成，以及代理未配置、网络失败或透明结果不合格时的真实设备恢复仍待验证。现行第二段见 [AI 二次透明处理验证记录](2026-08-31-ai-transparent-extraction-provider.md)。
>
> 读者：以后修改 Adonis 默认 AI 贴纸 provider、能力门控或失败恢复的工程 Agent。
>
> 读完后的动作：能在不引入“原图直抠”或“用样片冒充用户结果”的前提下修改不可用路径，并知道哪些结论仍需真实设备和真实 provider 证明。
>
> 对应任务：ADO-006、ADO-108、ADO-Q04、ADO-Q07

## 1. 用户契约

默认人物照片仍必须经过以下生产链路：

```text
用户照片
  → 系统 Image Playground 生成并由用户确认不透明贴纸源图
  → 只把 AI 源图发送到 Adonis 代理做 GPT Image 透明编辑
  → 双端 Alpha 门禁与本机纯白边
  → 透明贴纸与收藏卡
```

当系统图片生成能力不可用或不支持当前语言环境时：

- 页面明确说明这次没有生成用户的 AI 贴纸，也没有改用用户原图直接抠图。
- 用户可以点“先不用”回到创作页，不出现无意义的“再试一次”。
- 用户可以主动点“体验内置样片”，进入一张明确标注来源的授权、预生成 AI 样片结果。
- 内置样片只是让当前设备体验收藏卡、透明贴纸与原图对照，不解决用户自己照片的生成。
- 不得在后台自动切换样片，也不得把样片描述成用户照片、当前设备实时输出或默认 provider 成功结果。它包含预先归档的 AI 像素，因此必须诚实标为“AI 生成”。

生成失败、无可用图片或超时与“设备根本不支持”是不同状态。前者仍可在有原输入时提供重试；后者只提供退出或样片体验。

## 2. 恢复流程与来源边界

```text
系统 Image Playground 不可用，或旧 provider 返回 unavailable / unsupportedLanguage
  → 显示“当前设备不能生成 AI 贴纸”
  ├─ 先不用：清理恢复状态，留在创作页
  └─ 体验内置样片：加载首张授权展示样片
       → 使用预生成 AI 底图与对应真实 Alpha 贴纸完成结果排版
       → 显示“来自内置样片”
       → 显示“AI 生成”并允许可选人物与穿搭复核
```

| 对象 | 来源与处理契约 |
| --- | --- |
| 失败的用户照片 | 没有生成 AI 源，不进入透明编辑，也不会被保存为样片结果 |
| 内置样片原图 | 用户已授权的项目样片 |
| 样片 AI 底图 | Codex 内置图片能力预生成并归档的不透明图；不是当前设备实时生成 |
| 样片透明贴纸 | 从预生成 AI 底图语义隔离并确定性生成的真实 Alpha/纯白边结果，来源为“AI 生成” |
| 样片收藏卡 | Adonis 程序排版，人物与衣物来自 AI 样片贴纸并继承 AI 来源 |
| AI 人物与穿搭复核 | 出现；比较授权原图与最终 AI 贴纸，不把未评价写成质量通过 |

用户若在样片结果页继续点“收藏今天”，保存的是明确标注的样片记录，不是刚才失败的用户照片。这里仍由用户主动决定，不自动收藏。

## 3. 实现约束

- 不可用状态使用中性的底层错误说明，不再误导用户“可以继续使用花影海报”；没有人物贴纸结果时，花影海报并不是可执行恢复路径。
- 默认 AI 贴纸页面为不可用状态提供专用文案和样片入口；其他系统图片创作仍可使用各自的能力门控。
- 样片恢复继续使用 `preparedSample` 输入来源，但当前产品像素来源必须为 `aiGenerated`，并保存预生成 AI 底图供可选复核。
- 样片恢复不得创建事实性 OOTD 衣物线索；“这张还像你吗？”只评价原图与最终 AI 贴纸的变化，不是 Alpha 闸门。
- 普通 `-ui-testing` 与 Release、普通手动 Debug 使用同一组首页 AI 底图和透明贴纸；样片收藏卡、数字手办卡、保存记录与花历重开都保持 `aiGenerated`。只有明确添加 `-ui-testing-historical-sample-fixture` 的隔离回归才读取旧 `derivedFromOriginal` 贴纸，历史夹具不得成为当前视觉证据或静默兜底。
- 若以后移除全部展示样片，界面不得继续承诺“体验内置样片”。

## 4. TDD、专项回归与视觉证据

失败先行时观察到两类旧行为：

- UI 测试找不到新的能力不可用标题与“体验内置样片”按钮，证明旧界面没有可执行恢复路径。
- 错误文案单元测试发现底层说明仍包含“继续使用花影海报”，且没有“当前设备或系统设置”边界。

以下为更换首页 AI 样片前的历史证据：

- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_06-03-39-+0800.xcresult`：中性错误文案单元测试 1 项通过。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_06-45-34-+0800.xcresult`：不可用 → 明确样片恢复 UI 流程 1 项通过。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_07-20-17-+0800.xcresult`：首次 `make ai-sticker-regression` 共 10 个单元测试与 3 个 UI 流程通过，覆盖先生成后抠图、无原图直抠、来源/导出、人物复核及不可用样片恢复。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_08-53-14-+0800.xcresult`：最大辅助字号与增强对比度下的不可用 → 样片结果专项流程 1 项通过；结果模式按系统适配为菜单，不要求三个分段按钮同时占据屏幕。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_09-28-05-+0800.xcresult`：最终产品代码下再次运行 `make ai-sticker-regression`，10 个单元测试与 3 个 UI 流程全部通过。模拟器两次错误等待动画空闲通知约 15 分钟，因此整次耗时 2,003 秒；断言仍全部通过，这个时长不是产品性能证据。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_10-19-58-+0800.xcresult`：更新旧的模糊输入路由断言后，1 个 UI 流程在 12.7 秒内通过；确认模糊商品图仍不能绕过 AI 生成直接入衣橱，并正确提供“先不用 / 体验内置样片”。该用例已加入后续 `make ai-sticker-regression`。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_10-20-36-+0800.xcresult`：全量长跑中发生点击卡顿的两个既有 UI 流程分别重跑，2 项均通过；总测试时间 90.1 秒。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_07-49-22-+0800.xcresult`：`make sample-regression` 共 27 项通过。
- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_07-49-40-+0800.xcresult`：`make performance-regression` 共 14 个单元测试与 4 个 UI 流程通过。
- 无签名 Release 通用 iOS 构建通过；`.derivedData-release/Build/Products/Release-iphoneos/Adonis.app/Adonis` 为 arm64 Mach-O，且二进制不包含本功能的两个 UI 测试启动参数。

最终专项附件 `Adonis-unavailable-ai-prepared-sample-recovery` 来自 09:28 的回归结果，为 1206 × 2622，SHA-256 为 `69526a14f9e3274d08e5ebab35618dee33bb010fad093f4a6e90f23ffbfd864f`。人工目检确认：

- 收藏卡、透明贴纸和原始照片三个切换入口均存在；
- 页面显示“来自内置样片”；
- 来源说明为“程序排版 · 人物与衣物来自原图”；
- 没有 AI 人物与穿搭复核入口；
- 卡片人物、纯白贴纸边与既有授权样片一致。

这些历史证据证明旧恢复交互和当时来源诚实性，不证明当前首页 AI 样片、Apple 真实生图、GPT Image 透明质量或真实 iPhone 完整链路。当前样片证据见 [首页 AI 样片重新生成验证记录](2026-08-31-homepage-ai-showcase.md)。

本功能最初切片中的完整 `make test` 与 `make accessibility-regression` 没有形成新的全量通过证据：

- `.derivedData/Logs/Test/Test-Adonis-2026.08.31_09-00-19-+0800.xcresult` 中 179 个单元测试全部通过；UI 长跑暴露出一条仍断言旧文案的真实测试遗漏，已修复并用上述 10:19 结果验证。另两个 UI 流程在模拟器点击或分享层关闭时失败，随后已用上述 10:20 结果分别通过。模拟器再次出现约 15 分钟的动画空闲等待后，整套测试被人工中止，因此不能宣称当前 218 项全部通过。
- 完整无障碍回归中，既有“再次盛开”测试在与本功能无关的滑动事件上等待 195 秒后超时，模拟器在若干 App 重启处还出现 5—15 分钟停顿，最终人工中止；脚本已恢复普通字号和默认对比度。

不能用上述专项通过替代当时的两套完整回归，但它们直接覆盖了本次新增界面、来源和无原图直抠契约。该切片完成时的完整全量通过基线仍为 217 项（179 个单元测试与 38 个 UI 流程）；本切片新增了第 39 个 UI 流程。

后续同日的旧 provider 隔离切片重新跑通了当前完整套件：`Test-Adonis-2026.08.31_12-06-09-+0800.xcresult` 为 218/218 通过，其中 179 个单元测试、39 个 UI 流程、0 失败、0 跳过。隔离命令另运行 1 个只在显式禁用旧 provider 时编译的测试。它更新了工程回归基线，但不改变本节关于最初长跑失败的历史记录，也不证明真实 iPhone 或真实图片生成 provider。

## 5. 当前设备与 provider 决策边界

2026-08-31 的本机检查显示，现有真机是 iPhone 11（iOS 18.7.7），当前离线。Apple 的设备要求说明 Apple Intelligence 需要 iPhone 15 Pro 系列或 iPhone 16 及更新机型；因此 iPhone 11 即使重新连接，也不能运行依赖 Apple Intelligence 的 Image Playground 图片生成。[Apple 设备要求](https://support.apple.com/en-hk/121115)

默认人物贴纸现已使用 Apple 支持的系统 Image Playground 界面；程序化 `ImageCreator` 只暂时服务尚未迁移的风格花园。Apple 已公告该旧 API 在 iOS 27 及以后停止工作，因此它不能作为长期、全设备兼容方案。[Apple ImageCreator 停用公告](https://developer.apple.com/news/?id=dz9wvq0r)

支持 Apple Intelligence 的设备路线已经实现；如果还要让 iPhone 11 处理用户自己的照片，仍需由产品负责人选择一条兼容路线：

1. 接入云端图片生成 API，并在上传前明确征得同意；供应商密钥从第一天起只放在开发者控制的后端或本地开发代理中，不得写入 App、源码、Info.plist 或客户端 Keychain。
2. 维持当前产品边界：只支持具备 Apple Intelligence 的新设备使用系统 Image Playground；iPhone 11 只可体验内置样片。
3. 打包本地 Core ML 生图模型，接受包体、速度、内存与质量风险，并先做单独可行性实验。

在旧设备兼容路线确定前，不得把当前样片恢复描述成“iPhone 11 已支持用户照片 AI 贴纸”。默认系统页实现与真实设备待验证边界见 [系统 Image Playground 迁移验证记录](2026-08-31-image-playground-sheet-migration.md)。

## 6. 修改与回归清单

修改能力不可用文案、provider 门控、样片入口或来源规则后：

1. 运行 `make ai-sticker-regression`。
2. 确认用户原图没有进入 GPT Image 透明编辑请求。
3. 确认样片入口需要用户明确点击，结果显示“来自内置样片”。
4. 确认当前产品样片结果保持“AI 生成”来源、提供可选人物/穿搭复核，且没有创建事实性 OOTD 衣物线索。
5. 若改动生成/透明编辑或耗时边界，再运行 `make ai-sticker-regression`、`make sample-regression` 与 `make performance-regression`。
6. 真正更换 provider 后，补真实请求、真实输出、隐私、时延、费用和目标设备证据。

默认系统页实现见 [系统 Image Playground 迁移验证记录](2026-08-31-image-playground-sheet-migration.md)；`ImageCreator` 的 SDK 编译隔离、二进制符号门禁与云端密钥边界见 [Apple ImageCreator 旧适配器隔离验证记录](2026-08-31-legacy-image-creator-isolation.md)。
