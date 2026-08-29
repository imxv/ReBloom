# Adonis

Adonis 是一个中文 iOS 原生本地 Demo：用户给它一张自拍或 OOTD，App 在设备上生成保留原图内容的透明贴纸和分享收藏卡，把当天结果记录进花历；商品图则可以逐渐形成衣橱。

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
- 保存 OOTD 时尽力留下上身与下身的临时画面线索；以后打开花历记录，可从最多 3 个衣橱候选中一键确认、否定、暂放或明确创建新衣服。
- 从 OOTD 明确创建新衣服后，可以在原处补一张更清楚的商品图或平铺图；图片与可确定的颜色信息会更新到同一件衣服，不会重复建档。
- 商品图、截图或平铺图加入衣橱时，本机自动提取主色、判断画面是否像干净商品图，并在高置信度时采用类别建议。
- 衣物分类不确定时保持未分类，用户可点一下纠正；同一图片不会重复入库。
- 记录不含图片内容的本地处理耗时与错误信息。

当前 iOS 26.5 模拟器的 Vision 推理运行时不可用，因此四张内置样片使用项目脚本在 macOS 主机上预处理的真实透明结果，以便完整体验收藏、分享和花历链路；模拟器对自选照片会明确提示这一限制，不会伪造生成成功。真机仍走实时 Vision 路径。详见 [验证记录](docs/verification/2026-08-29-ios-local-demo.md)。

衣橱的颜色与白底判断不依赖 Vision，因此可以在模拟器运行；类别建议在模拟器保持为空，在 iPhone 上才会尝试系统通用分类。它不是可靠的服饰匹配能力，边界和测试证据见 [衣橱轻量导入验证](docs/verification/2026-08-29-wardrobe-import.md)。

OOTD 线索同样不是服饰实例分割或同款识别：当前只根据透明人物中的相对位置与颜色给出少量待确认候选，不会自动关联，也不会在用户明确点击“这是新衣服”前污染衣橱。状态语义与 UI 证据见 [OOTD 衣物线索验证](docs/verification/2026-08-29-ootd-garment-observations.md)。

从 OOTD 建档后补商品图属于“同一件衣服的素材升级”，不是历史同款识别：它保留原单品、人工名称、人工分类和备注，拒绝自动合并已经属于其他单品的重复图片。事务与回归边界见 [OOTD 单品补商品图验证](docs/verification/2026-08-29-ootd-product-image-upgrade.md)。

## 产品与开发上下文

开发前依次阅读：

1. [产品方向](docs/product-direction.md)
2. [iOS 本地 Demo 实施说明](docs/ios-local-demo.md)
3. [任务清单](TODO.md)
