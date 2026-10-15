# 本地测试样片

四张 PNG 均由用户在 2026-08-29 的 Adonis 开发会话中明确提供，用于本地 Demo 与回归测试。前三张通过人工抠图复核并进入普通体验入口；sample-04 只作为 C 级失败基线保留。它们不得被解释为来自外部社交平台抓取的素材。

| 文件 | SHA-256 |
| --- | --- |
| sample-01.png | `eeab59ff1e4b4ef9e8413bdd6a6f0a0b823aef520c09d39a1321a23d67759829` |
| sample-02.png | `5899d410fe7f0c39a7f8225e5db8ce231755eeee154fe1bb453f227bd967bcdd` |
| sample-03.png | `34bf69017581655fe7bfacce63d935fbcbd05af3bb2857f9f06ac00f7dd0ae74` |
| sample-04.png | `ff47e939b5cd42f479182e5ecd81e00fc6ff9f06b119e822f8edba4485efba19` |

对应的 `sample-*-sticker.png` 是从上述原图通过 `scripts/generate_sample_stickers.swift` 在 macOS 主机上生成的真实透明贴纸，用于绕过当前 iOS 26.5 模拟器无法创建 Vision 推理上下文的问题。它们不是人工挑选或伪造的成功结果。

## 首页 AI 展示资产

首页另外使用前三张授权原图对应的 `sample-0*-ai-source.png` 与 `sample-0*-ai-sticker.png`。这组资产与上述历史 Vision 基线相互独立：

- `ai-source` 是 Codex 内置图片生成能力产出的不透明 AI 贴纸底图。
- 内置图片能力随后把每张 AI 底图中的完整主体语义隔离到单色绿幕；审核后的绿幕候选保存在 `assets/prototypes/digital-figurine-sticker/`。
- `scripts/generate_homepage_ai_sticker.sh` 只把固定绿幕候选确定性转换为真实 Alpha、去除绿色污染并加入连续纯白边；最终 PNG 不是绘制棋盘格。
- 三张结果都包含 AI 重绘像素，首页与结果页必须标为“AI 生成”。逐张人工复核均记录了脸、姿势、衣服或配饰变化，因此它们只可用于首页示例，不是人物或穿搭保真证据。
- 生成方式、哈希、尺寸、后处理参数和人工结论保存在 `homepage-ai-showcase.json`。非确定性的 AI 阶段以归档文件锁定；只有绿幕到 Alpha 的后处理可以逐字节重现。
- 当前首页点击、普通 UI 测试、收藏卡、数字手办卡、保存记录与历史重开统一读取 `sample-0*-ai-sticker.png`。旧 `sample-*-sticker.png` 只保留为显式历史回归基线，不得静默兜底到当前产品结果。

直接请求内置图片能力输出透明 PNG 时曾得到画出来的棋盘格，相关候选已拒绝且没有进入 App。不得用“看起来像透明”替代真实 Alpha 检查，也不得用这三张首页图覆盖 `regression-baseline.json` 中的四张历史样片。

## 固定回归入口

完整基线保存在 `regression-baseline.json`，其中记录授权类型、处理版本、文件哈希、尺寸、像素指标、人工抠图结论、展示路由、覆盖标签和每张图的已知缺陷。运行：

```bash
make sample-regression
```

该命令会：

1. 校验四张原图与四张贴纸的 SHA-256。
2. 在临时目录并行重新运行生成脚本，并要求四张结果与已提交贴纸逐字节一致。
3. 在 iOS 模拟器中验证目录与基线清单一致、透明区域、可见主体、纯白边、最大连通主体、透明四角和 1536 像素长边。
4. 用三张首页 AI 贴纸分别生成 1080 × 1440 全不透明收藏卡和数字手办卡，并确认结果与对应历史直抠卡片字节不同；C 级 sample-04 继续做像素回归，但不得绕过质量闸门进入用户收藏卡。
5. 检查受控原始蒙版中的空主体、碎裂、大块背景粘连和不确定边缘，并合并最终贴纸结构结论。
6. 要求实时处理要么产生合格贴纸并携带原始蒙版结论，要么在当前模拟器明确报告 Vision 能力不足；真实 iPhone 会逐张运行真实 Vision 路径。
7. 校验三组首页 AI 底图、审核绿幕和最终透明贴纸的 SHA-256，并用固定参数逐字节重建三张真实 Alpha 贴纸。
8. 在 iOS 中确认首页 AI 底图不透明、最终贴纸有透明四角、连续纯白边、完整主连通主体，并确认历史四图及 C 级失败边界仍在。

逐张手动重新生成仍可使用：

```bash
xcrun swift scripts/generate_sample_stickers.swift \
  ReBloom/Resources/Samples/sample-01.png \
  ReBloom/Resources/Samples/sample-01-sticker.png
```

| 派生文件 | SHA-256 |
| --- | --- |
| sample-01-sticker.png | `c07053dcd70651c8951e4090d259b7f230b78123af47b88c95c8c007d4f0f616` |
| sample-02-sticker.png | `d2634c153cb6c7944e3e7b84a094af77e1b48afaa5eaf364e897ce9b2caff51a` |
| sample-03-sticker.png | `17be951440b4148a2a6c7abfb1e3975e876e4d95a1ccdad784d65a1a9c0640bf` |
| sample-04-sticker.png | `e89b89c7bb6258bb86eb8e13f54258f6cfffff2d3d46069340055972358329d9` |

## 当前覆盖与已知缺陷

| 样片 | 覆盖 | 路由 | 必须保留在记录中的已知缺陷 |
| --- | --- | --- | --- |
| sample-01 | 站姿、浅色穿搭、饮料、手提包 | A / 展示 | 左手饮料与发丝附近有少量灰白分割残留。 |
| sample-02 | 站姿、深色穿搭、大面积留白、金属包 | A / 展示 | 身体、金属包与墙面或长椅接触处仍夹带背景残留。 |
| sample-03 | 复杂店内背景、宽松裤装、脸部遮挡 | A / 展示 | 头发与肩部边界有少量灰白背景残留。 |
| sample-04 | 坐姿、深色衣物、深色背景、交叠腿部 | C / 拒绝 | 浅色软垫被大块并入主体，是明确失败边界，不是合格抠图示例。 |

固定基线用于阻止静默退化，不代表这些缺陷已经解决，也不代表四张图足以证明泛化质量。新增模型、提示、蒙版、裁切、白边或缩放逻辑时，先把候选结果生成到临时目录，逐张并排目检原图和输出；只有确认是有意变化后，才能更新贴纸、哈希、指标与已知缺陷。不得只为让测试变绿而重录基线。
