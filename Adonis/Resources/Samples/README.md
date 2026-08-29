# 本地测试样片

四张 PNG 均由用户在 2026-08-29 的 Adonis 开发会话中明确提供，用于本地 Demo 与回归测试。它们不得被解释为来自外部社交平台抓取的素材。

| 文件 | SHA-256 |
| --- | --- |
| sample-01.png | `eeab59ff1e4b4ef9e8413bdd6a6f0a0b823aef520c09d39a1321a23d67759829` |
| sample-02.png | `5899d410fe7f0c39a7f8225e5db8ce231755eeee154fe1bb453f227bd967bcdd` |
| sample-03.png | `34bf69017581655fe7bfacce63d935fbcbd05af3bb2857f9f06ac00f7dd0ae74` |
| sample-04.png | `ff47e939b5cd42f479182e5ecd81e00fc6ff9f06b119e822f8edba4485efba19` |

对应的 `sample-*-sticker.png` 是从上述原图通过 `scripts/generate_sample_stickers.swift` 在 macOS 主机上生成的真实透明贴纸，用于绕过当前 iOS 26.5 模拟器无法创建 Vision 推理上下文的问题。它们不是人工挑选或伪造的成功结果，可以使用以下命令逐张重新生成：

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
