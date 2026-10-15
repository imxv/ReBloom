# ReBloom

让每一个你，重新盛开。

项目原名 Adonis，现更名为 ReBloom，代码仓库为 [imxv/ReBloom](https://github.com/imxv/ReBloom)。App 与系统分享入口使用新名称；为兼容现有本地数据与开发配置，Xcode 工程/target、Bundle ID、App Group、存储与导出标识、`ADONIS_*` 环境变量暂时沿用原名。因此以下命令仍打开 `Adonis.xcodeproj`。历史截图、样片和验证记录保留生成时的名称与证据范围。

ReBloom 是一个中文 iOS 原生 Demo：用户给它一张自拍或 OOTD，在系统页确认一张不透明 AI 贴纸底图后，App 只把这张底图送去透明处理，得到透明贴纸和分享收藏卡；用户点击“收藏今天”后才记录进花历。商品图还可以从照片或其他 App 的系统分享面板直接收进衣橱。

ReBloom 以本地存储和本机派生为主；默认人物链路在用户确认系统生成的 AI 底图后，可将这张底图发送到开发者控制的透明贴纸代理调用 GPT Image。当前没有账号、云同步或公开部署，真实供应商与线上安全仍待验证。完整产品边界与验收标准见 [iOS 本地 Demo 实施说明](docs/ios-local-demo.md)。

## 运行

环境要求：当前版本使用 Xcode 26，最低目标系统为 iOS 17。

```bash
make project
open Adonis.xcodeproj
```

也可以直接构建和测试：

```bash
make build
make test
make check
make legacy-provider-isolation
```

`make check` 使用当前 Xcode 工具链自带的 `swift-format` 做严格格式检查，并对通用 iOS 设备目标执行静态分析；`make format` 可以机械修正 Swift 排版。

需要保留完整回归结果并自动核对测试数量、零失败/跳过和必需用例时，使用 `make verified-test`。每次结果独立保存到 `.artifacts/verified-tests`，避免误读并行任务或被 Xcode 日志轮换清理；它不隔离共享模拟器。已完成结果也可只读验收，详见 [回归结果验收与保留](docs/test-evidence.md)。工具自身测试为 `make test-tools`。

项目已经提交生成后的 Xcode 工程。`make project` 只在修改 `project.yml` 或新增 target 后需要执行；脚本会把固定版本的 XcodeGen 下载到项目忽略的本地工具目录，不修改系统 Homebrew。

## 当前功能

- 从相册、相机或首页三张内置 AI 样片选择照片。
- 默认人物链路先通过系统 Image Playground 生成不透明 AI 底图，再由配置的透明处理服务生成贴纸；Apple Vision 只用于其他明确的本机分析与历史回归。
- 客户端检查真实透明通道并生成纯白贴纸边。
- 程序化生成带日期与 Bloom 编号的分享收藏卡。
- 从生成结果或花历记录一次点击生成 1080 × 1440 的 2.5D 数字手办展台卡，并交给系统分享；人物和衣服直接沿用输入透明贴纸，展台不再重绘主体。输入贴纸含 AI 像素时，手办卡继续标为“AI 生成”；当前不生成 3D 网格或补全缺失人体。
- 花历有当月收藏时，一次点击生成最多包含最近 6 次盛开的 1080 × 1440 月度贴纸 Lookbook，并交给系统分享；无需 Prompt、模型或模板选择。
- 在 Apple 系统图片生成能力可用时，从一个“风格花园”入口选择永生花园、花神速写或月光剧场；成品明确标为 AI 生成，可对照原图、收藏、分享并从花历回看。
- 将 OOTD、衣橱单品和花历记录保存在本机；本地设置可查看数据数量、导出标准 TAR 副本，或经二次确认清空记录、媒体、待导入图片和临时归档。
- 默认 AI 贴纸及内置 AI 样片不生成事实性衣物线索。历史可信原图处理记录如有上身与下身线索，可在花历中从最多 3 个衣橱候选中确认、否定、暂放或明确创建新衣服。
- 从 OOTD 明确创建新衣服后，可以在原处补一张更清楚的商品图或平铺图；图片与可确定的颜色信息会更新到同一件衣服，不会重复建档。
- 后来加入商品图或平铺图时，衣物详情可提示最多 3 条相似的旧 OOTD；只有用户点击“是这件”才回填穿着关系，点击“不是它”后不再重复询问。
- 商品图、截图或平铺图加入衣橱时，本机自动提取主色、判断画面是否像干净商品图，并在高置信度时采用类别建议。
- 干净商品图中的上装或外套可从衣物详情一次点击做“贴纸试搭”：自动使用最近一次已收藏 OOTD，本机裁切衣物并加纯白边后覆盖到上身，支持停止、原图对照、收藏、分享和花历回看。
- 其他 App 分享的图片或商品截图会通过系统分享扩展进入本机收件箱，下次回到 ReBloom 时自动分析并收进衣橱；一次最多接收 5 张。
- 衣物分类不确定时保持未分类，用户可点一下纠正；同一图片不会重复入库。
- 记录不含图片内容的本地处理耗时与错误信息。

当前 iOS 26.5 模拟器的 Vision 推理运行时不可用，因此四张历史样片使用项目脚本在 macOS 主机上预处理的真实透明结果，以便验证历史回归和收藏、分享、花历链路；普通首页入口使用前三张归档的预生成 AI 样片。默认人物照片必须先得到 AI 不透明贴纸源，再对该源图做透明处理；AI 生图不可用时会明确提示，并只在用户主动选择后进入标注为“来自内置样片”的体验结果，不会把用户原图直接处理或用样片冒充用户结果。四张授权照片的独立历史实验验证了“AI 底图再抠图”的技术顺序，也暴露了人物与穿搭变化；它不证明当前 Apple/OpenAI 生产链路质量。默认人物贴纸已经适配系统 Image Playground 与 GPT Image 透明编辑；即将停用的 Apple `ImageCreator` 只作为 iOS 26 风格花园的旧适配器保留。当前 iPhone 11 不支持 Apple Intelligence，旧设备兼容和风格花园的长期 provider 仍待决定。详见 [系统确认页迁移](docs/verification/2026-08-31-image-playground-sheet-migration.md)、[透明代理验证](docs/verification/2026-08-31-ai-transparent-extraction-provider.md)、[两段式视觉实验](docs/experiments/2026-08-31-ai-opaque-source-matting.md)、[旧适配器隔离验证](docs/verification/2026-08-31-legacy-image-creator-isolation.md)与 [不可用恢复验证](docs/verification/2026-08-31-unsupported-ai-sample-recovery.md)。

衣橱的颜色与白底判断不依赖 Vision，因此可以在模拟器运行；类别建议在模拟器保持为空，在 iPhone 上才会尝试系统通用分类。它不是可靠的服饰匹配能力，边界和测试证据见 [衣橱轻量导入验证](docs/verification/2026-08-29-wardrobe-import.md)。

历史可信 OOTD 线索也不是服饰实例分割或同款识别：候选由类别、颜色、图片来源与本机视觉签名排序，最多展示 3 个，只有用户明确确认才改变衣橱关系。默认 AI 贴纸会跳过衣物线索分析，避免把生成图的衣服当成真实事实。状态语义与证据见 [OOTD 衣物线索验证](docs/verification/2026-08-29-ootd-garment-observations.md)与 [衣橱视觉排序验证](docs/verification/2026-08-30-wardrobe-visual-matching.md)。

从 OOTD 建档后补商品图属于“同一件衣服的素材升级”，不是历史同款识别：它保留原单品、人工名称、人工分类和备注，拒绝自动合并已经属于其他单品的重复图片。事务与回归边界见 [OOTD 单品补商品图验证](docs/verification/2026-08-29-ootd-product-image-upgrade.md)。

衣橱历史回填同样不是自动同款识别：它反向查找尚未处理的画面线索，只展示少量候选，并把“确认或排除”的最终决定留给用户；确认结果仍可从花历撤销。状态规则与真实 UI 证据见 [衣橱历史穿着回填验证](docs/verification/2026-08-29-wardrobe-history-backfill.md)。

“贴纸试搭”只是本机程序草图，不是 AI 写实换装：人物与背景来自最近 OOTD，衣物来自商品图；它不预测尺码、合身、垂坠、褶皱或真实遮挡。当前 iOS 26.5 模拟器的人体姿态没有可用计算设备，专项成功图使用仅 Debug 的固定姿态，真机 Vision 与泛化质量仍待验证。实现与证据见 [贴纸试搭验证](docs/verification/2026-08-30-sticker-try-on.md)。

“风格花园”把三个系统配方收在一个低心智入口中，但三种都会重绘整张画面，不保证身份或衣服保持不变。模拟器成功图只是 Debug 抽象夹具；真实 Apple 输出、时延、网络、费用和固定样本质量仍待真机验证。实现与证据见 [精选风格花园验证](docs/verification/2026-08-30-curated-style-garden.md)。

当前系统分享只读取用户主动分享的图片附件，不抓取购物页面，也不解析商品链接或 SKU。成功、重复与失败重试的边界见 [购物应用图片分享验证](docs/verification/2026-08-29-shopping-app-image-share.md)。

ReBloom 不做账号云同步；默认人物链路会在用户确认 AI 底图后，仅将这张底图发送到配置的 ReBloom 代理做透明处理，原照片不会发送到第二段。iOS 系统设备备份是否包含 App 数据由用户的系统设置控制。导出范围、临时文件、文件保护和彻底删除证据见 [本地数据导出与删除验证](docs/verification/2026-08-29-local-data-controls.md)。

## 产品与开发上下文

开发前依次阅读：

1. [产品方向](docs/product-direction.md)
2. [iOS 本地 Demo 实施说明](docs/ios-local-demo.md)
3. [任务清单](TODO.md)
