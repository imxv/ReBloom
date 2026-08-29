# Adonis

Adonis 是一个中文 iOS 原生本地 Demo：用户给它一张自拍或 OOTD，App 在设备上生成保留原图内容的透明贴纸和分享收藏卡，并把结果自然记录进衣橱与花历。

当前版本没有账号、服务端、付费 API、远程分析或公开部署。完整产品边界与验收标准见 [iOS 本地 Demo 实施说明](docs/ios-local-demo.md)。

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
```

`make check` 使用当前 Xcode 工具链自带的 `swift-format` 做严格格式检查，并对通用 iOS 设备目标执行静态分析；`make format` 可以机械修正 Swift 排版。

项目已经提交生成后的 Xcode 工程。`make project` 只在修改 `project.yml` 或新增 target 后需要执行；脚本会把固定版本的 XcodeGen 下载到项目忽略的本地工具目录，不修改系统 Homebrew。

## 当前功能

- 从相册、相机或四张内置授权样片选择照片。
- 在 iPhone 上使用 Apple Vision 实时分割人物。
- 使用 Core Image 生成真实透明通道与纯白贴纸边。
- 程序化生成带日期与 Bloom 编号的分享收藏卡。
- 将 OOTD、衣橱单品和花历记录保存在本机，并支持删除。
- 记录不含图片内容的本地处理耗时与错误信息。

当前 iOS 26.5 模拟器的 Vision 推理运行时不可用，因此四张内置样片使用项目脚本在 macOS 主机上预处理的真实透明结果，以便完整体验收藏、分享和花历链路；模拟器对自选照片会明确提示这一限制，不会伪造生成成功。真机仍走实时 Vision 路径。详见 [验证记录](docs/verification/2026-08-29-ios-local-demo.md)。

## 产品与开发上下文

开发前依次阅读：

1. [产品方向](docs/product-direction.md)
2. [iOS 本地 Demo 实施说明](docs/ios-local-demo.md)
3. [任务清单](TODO.md)
