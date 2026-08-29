# 本地测试样片

四张 PNG 均由用户在 2026-08-29 的 Adonis 开发会话中明确提供，用于本地 Demo 与回归测试。它们不得被解释为来自外部社交平台抓取的素材。

| 文件 | SHA-256 |
| --- | --- |
| sample-01.png | `eeab59ff1e4b4ef9e8413bdd6a6f0a0b823aef520c09d39a1321a23d67759829` |
| sample-02.png | `5899d410fe7f0c39a7f8225e5db8ce231755eeee154fe1bb453f227bd967bcdd` |
| sample-03.png | `34bf69017581655fe7bfacce63d935fbcbd05af3bb2857f9f06ac00f7dd0ae74` |
| sample-04.png | `ff47e939b5cd42f479182e5ecd81e00fc6ff9f06b119e822f8edba4485efba19` |

对应的 `sample-*-sticker.png` 是从上述原图通过 `scripts/generate_sample_stickers.swift` 在 macOS 主机上生成的真实透明贴纸，用于绕过当前 iOS 26.5 模拟器无法创建 Vision 推理上下文的问题。它们不是人工挑选或伪造的成功结果。

## 固定回归入口

完整基线保存在 `regression-baseline.json`，其中记录授权类型、处理版本、文件哈希、尺寸、像素指标、覆盖标签和每张图的已知缺陷。运行：

```bash
make sample-regression
```

该命令会：

1. 校验四张原图与四张贴纸的 SHA-256。
2. 在临时目录并行重新运行生成脚本，并要求四张结果与已提交贴纸逐字节一致。
3. 在 iOS 模拟器中验证目录与基线清单一致、透明区域、可见主体、纯白边、最大连通主体、透明四角和 1536 像素长边。
4. 用四张贴纸分别生成 1080 × 1440 全不透明收藏卡。
5. 要求实时处理要么产生合格贴纸，要么在当前模拟器明确报告 Vision 能力不足；真实 iPhone 会逐张运行真实 Vision 路径。

逐张手动重新生成仍可使用：

```bash
xcrun swift scripts/generate_sample_stickers.swift \
  Adonis/Resources/Samples/sample-01.png \
  Adonis/Resources/Samples/sample-01-sticker.png
```

| 派生文件 | SHA-256 |
| --- | --- |
| sample-01-sticker.png | `d955397f25f7bf0b847d1f608a2423c91a820738a1989bbba8463148af029344` |
| sample-02-sticker.png | `5ce0d85742ffa585bb36da7d846ae073c28f6ef34a8e05fbc60e5657c578ea27` |
| sample-03-sticker.png | `62cfa4d8105d017eabd7e6e3548bd6735f98cc7c45fb3a5eb6ccfda63e5fe156` |
| sample-04-sticker.png | `893626428ebf7e8b9414f8d61dc409681cf994568d6d7ad6ddf2b11869fb566d` |

## 当前覆盖与已知缺陷

| 样片 | 覆盖 | 必须保留在记录中的已知缺陷 |
| --- | --- | --- |
| sample-01 | 站姿、浅色穿搭、饮料、手提包 | 左手饮料与发丝附近有少量灰白分割残留。 |
| sample-02 | 站姿、深色穿搭、大面积留白、金属包 | 身体、金属包与墙面或长椅接触处仍夹带背景残留。 |
| sample-03 | 复杂店内背景、宽松裤装、脸部遮挡 | 头发与肩部边界有少量灰白背景残留。 |
| sample-04 | 坐姿、深色衣物、深色背景、交叠腿部 | 浅色软垫被大块并入主体，是明确失败边界，不是合格抠图示例。 |

固定基线用于阻止静默退化，不代表这些缺陷已经解决，也不代表四张图足以证明泛化质量。新增模型、提示、蒙版、裁切、白边或缩放逻辑时，先把候选结果生成到临时目录，逐张并排目检原图和输出；只有确认是有意变化后，才能更新贴纸、哈希、指标与已知缺陷。不得只为让测试变绿而重录基线。
