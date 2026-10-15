# ReBloom

当前产品目标见 [产品方向](docs/product-direction.md)，iOS 本地范围见 [Demo 说明](docs/ios-local-demo.md)，任务顺序见 [TODO](TODO.md)。按请求查阅相关部分，小改动无需先读完整文档集。

- 产品围绕 OOTD 与自然形成的衣橱；不要扩成通用 AI 工具箱或要求用户理解 Prompt、模型和工作流。
- 区分用户原图、识别建议、AI 生成与程序排版；派生成品继承输入的 AI 来源，不把候选关系描述成确认事实。
- 默认贴纸路径为用户确认系统生成的 AI 底图，再将该底图交给透明处理代理；不上传原照片到第二段，不静默回退原图直抠。供应商密钥只在代理端。
- 本地收藏以媒体和 SwiftData 保存均成功为准；草稿不等同于跨进程持久化。删除、导出和分享须保持原有数据边界。
- 保留 TODO 中的工作范围和真实验证证据；模拟器、Debug 夹具及历史样片不能证明真实 provider、真机或人物/衣物保真。

仅在涉及对应领域时读取：

| 修改领域 | 约束与历史证据 |
|---|---|
| 系统 AI 贴纸、透明处理、质量、超时和来源 | [贴纸链路](docs/agent-guidance/sticker-pipeline.md) |
| 衣橱、视觉匹配、商品补图和历史关系 | [衣橱契约](docs/agent-guidance/wardrobe.md) |
| 存储、分享、相册、权限和无障碍 | [数据与权限](docs/agent-guidance/data-and-permissions.md) |
| Lookbook、海报、试搭、展柜、花历和提醒 | [派生作品](docs/agent-guidance/derived-artifacts.md) |
| 选择验证命令或解释证据范围 | [验证索引](docs/agent-guidance/verification.md) |

Swift 检查入口为 `make check`；按相关行为选择已有回归或实际预览。禁止给 UI 写单元测试。文档编辑只检查内容和链接，无需运行整套应用测试。
