# 2026-08-31 AI 二次透明处理验证记录

> 状态：两段式代码契约、代理请求格式、双端 Alpha 门禁和本机纯白边已实现；真实 GPT Image 请求、真实人物边缘质量、公开代理与支持 Apple Intelligence 的真机仍待验证

## 1. 本轮用户决定

默认人物贴纸不再把用户上传的原照片直接交给 Vision 抠图，也不再把第一段 AI 生成图交给 Vision。固定顺序为：

```text
用户原照片
  → Apple 系统 Image Playground 生成贴纸底图
  → 用户在系统页确认一张不透明 AI 底图
  → 只把这张 AI 底图发给 Adonis 代理
  → GPT Image 编辑并返回真实透明 PNG
  → 服务端检查 PNG Alpha
  → iOS 再检查 Alpha、主体与碎裂程度
  → iOS 保留全部可见部件并程序化加入纯白边
  → 透明贴纸与收藏卡
```

这条产品链路只有系统 Image Playground 的结果确认是额外交互。用户不选择模型、Prompt、抠图方式、质量阈值或白边参数。任一步失败时可以重试或换图，但不得静默改用用户原图直抠。

## 2. 为什么替换原来的第二段

历史实现用 Apple Vision 从不透明图片估计人物蒙版。真实样片已经暴露头发、手套、靴边、反光包、遮挡和相邻物体容易遗漏或粘连；继续微调本机阈值不能稳定解决模型没有识别到的部件。

本轮把第二段改为图片编辑模型本身生成透明背景。它的目标是让模型结合完整画面语义保留人物、衣服、鞋、包、手持物和配饰，再由程序只做可确定的 Alpha 验证、裁切和纯白边。第二段仍可能重绘像素，因此“内容完全不变”是待真实样片验证的质量目标，不能由结构测试证明。

Codex 内置图片工具不是可由发布版 iOS App 直接调用的运行时接口。App 侧对应使用服务端 GPT Image 编辑接口；供应商密钥只存在于开发者控制的代理环境中。

## 3. Codex 内置图片实验

对项目中的不透明 AI 样片 `ai-source-sample-04-v1.png` 做了两次“只移除背景、保留手套和靴边”的图片编辑实验。视觉上主体部件基本保留，但两个返回文件都把棋盘格画进 RGB 像素，没有真实 Alpha：

| 结果 SHA-256 | 尺寸 | 透明通道 |
| --- | ---: | --- |
| `19fcbed188559005955174c09a7638ac83b5687a0e4c2d1c90e24ef9a2c677b5` | 1086 × 1448 | 无 |
| `d78f3a1128022413ea94409a161ad89780592af674e0444c46e681ac9c2876e3` | 1086 × 1448 | 无 |

这两个文件没有作为成功资产复制进项目。该实验说明“看起来像透明背景”不能作为产品验收；必须解析文件 Alpha。

## 4. 供应商请求契约

代理调用 OpenAI 图片编辑端点 `/v1/images/edits`，当前字段为：

- `model=gpt-image-2`
- `background=transparent`
- `output_format=png`
- `quality=high`
- `size=auto`
- 图片输入只包含用户已经在系统页确认的不透明 AI 底图
- 固定内部指令要求只移除背景，保留全部人物、衣物、鞋包、配饰、头发、姿势、颜色、纹理、标识和手持物，不添加白底、棋盘格、阴影、描边、文字或新物体

OpenAI 官方文档说明图片编辑接口适合编辑现有图片，GPT Image 支持透明背景；透明输出必须使用 PNG 或 WebP。复杂图片请求可能需要较长时间，因此客户端在用户确认底图后使用 150 秒截止，而普通本机与旧创作链路继续使用 90 秒。[图片生成与编辑指南](https://developers.openai.com/api/docs/guides/image-generation) · [GPT Image 2 模型](https://developers.openai.com/api/docs/models/gpt-image-2)

## 5. 服务端边界

最小代理位于 `server/`：

- `POST /v1/sticker-extractions` 接收 schema v1 JSON 和 Base64 PNG。
- 单张输入最多 12 MB，请求最多 18 MB，供应商输出最多 20 MB。
- 代理不写图片文件，不把图片、Base64、Prompt 或供应商响应写入日志。
- 响应与错误都带 `Cache-Control: no-store`。
- 代理解析并解压供应商 PNG；没有 Alpha、全透明、主体过小、透明比例不足或四角不透明时返回 502，不把伪透明结果交给 App。
- `OPENAI_API_KEY` 只允许在服务端环境变量中。
- `ADONIS_PROXY_CLIENT_TOKEN` 只是本地开发便利，不是生产鉴权。公开测试前必须配置 HTTPS、设备级鉴权、限流、滥用防护、预算上限和供应商数据说明。

本地运行与 App 配置见 `server/README.md`。App 从构建设置读取 `ADONIS_STICKER_EXTRACTION_URL` 和可选本地令牌；未配置时明确失败，不启用 Vision 兜底。

## 6. iOS 交付门禁

`AITransparentStickerProcessor` 对服务返回结果再次检查：

- 透明像素至少占 8%。
- 四角透明比例至少 75%。
- 可见主体与不透明主体不能为空或过小。
- 最大主体连通块低于全部可见像素的 80% 时视为严重碎裂并停止。
- 半透明边缘过多时进入轻量复查，不伪装成结构正常。
- 程序白边从最终 Alpha 膨胀得到，不让图片模型绘制白边。
- 裁切范围使用全部可见像素，不只取最大连通块；分离的包、鞋和小配饰不会被裁掉。
- 输出长边至少 1536 像素，并再次走既有透明、主体、连通与纯白边结构检查。

Alpha 门禁可以拒绝伪透明、空图和严重碎裂，但不能判断模型是否少画一只手套、改变衣服图案或重绘脸。结果后的可选“这张还像你吗？”改为比较用户原图与最终 AI 透明贴纸，覆盖两次 AI 可能造成的内容变化；它不增加上传前问卷，也不阻止收藏。

## 7. 来源、隐私与可观测性

最终贴纸包含两次 AI 处理，继续标为“AI 生成”。执行元数据分别保存：

- 底图 provider：`apple_image_playground_sheet`
- 透明编辑 provider：`openai_gpt_image`
- 组合 provider：`ai_sticker_two_pass`
- 网络：`mixed_system_and_developer_proxy`
- provider 请求数：2
- Apple 外部请求数未知，因此组合外部请求数保持未知，不伪造为 1 或 0

创作页在上传前只显示一句必要说明：原照片交给 Apple 系统生成底图；用户确认后，仅该 AI 底图发送到 Adonis 图像服务做透明处理。当前授权不包含把用户原照片、衣橱图或其他媒体发送给该代理。

## 8. 当前自动证据

2026-08-31 在 iPhone 17 Pro / iOS 26.5 模拟器完成本轮最终自动回归：

- `make ai-sticker-regression`：Node 代理 3/3、iOS 新链路与 UI 27/27；覆盖 GPT Image multipart 字段、只上传用户确认的 AI 底图、缺少配置不发请求、伪透明与严重碎裂拒绝、纯白边生成、分离配饰保留、来源、持久化和不可用恢复。
- `make ai-sticker-visual-regression`：4 组固定实验资产均通过“不透明 AI 底图 + 真实 Alpha 贴纸”的字节与像素契约。
- `make sample-regression`：27/27；历史 Vision 固定基线没有被本轮默认链路改动破坏。
- `make performance-regression`：18/18；`make accessibility-regression`：11/11；`make persistence-regression`：5/5；`make photo-save-regression`：6/6。
- `make legacy-provider-isolation` 通过：支持的系统 Image Playground 仍链接，旧 `ImageCreator` 符号不进入产物。
- `make check` 通过严格格式检查和通用 iOS 静态分析。
- 最终 `make test` 共 232/232（191 个单元测试、41 个 UI 流程），0 失败、0 跳过。结果包：`.derivedData/Logs/Test/Test-Adonis-2026.08.31_15-36-29-+0800.xcresult`；`xcresulttool` 独立读取结果同样为 `Passed`。

从该最终结果包导出的截图已经逐张目检：系统结果确认页明确展示“上传参考 → 模拟 AI 底图”；透明结果显示棋盘格、连续纯白边与 AI 来源；人物/穿搭复核比较“原图 → 最终 AI 贴纸”。这些自动测试使用本地网络替身和授权固定样片，不是一次真实 OpenAI 请求，也不证明真实人物边缘质量。

## 9. 尚未证明

- 当前环境没有 `OPENAI_API_KEY`，尚未从代理发起真实 GPT Image 请求。
- 尚未用四张授权固定样片得到真实 provider 的透明 PNG，也没有逐张检查发丝、手套、鞋边、反光包、遮挡和分离配饰。
- 尚未证明第二段不会改变脸、衣服图案、姿势、Logo 或其他可见内容。
- 尚未部署公开代理，也没有 HTTPS、设备鉴权、限流、费用、留存、删除回执、地区或训练用途证据。
- 尚未验证弱网、超时、重试、并发、供应商限额和真实成本。
- 尚未在支持 Apple Intelligence 的真实 iPhone 上跑通“选图 → 系统确认 → GPT Image 透明处理 → 收藏 → 相册/分享 → 花历重开”。

因此，本轮可以确认默认代码路径已经从 Vision 改为 AI 透明编辑，并且伪透明和严重碎裂会被拒绝；在真实 provider 样片完成前，不能宣称用户已经看到更好的实际边缘。

## 10. 回归命令

```bash
make server-test
make ai-sticker-regression
make ai-sticker-visual-regression
make sample-regression
make performance-regression
make accessibility-regression
make persistence-regression
make photo-save-regression
make legacy-provider-isolation
make check
make test
```
