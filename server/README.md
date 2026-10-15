# ReBloom 透明贴纸代理

这个最小服务只接收第一步已经生成、且由用户确认的 AI 贴纸底图。它不会接收用户原照片，也不会保存图片。服务把底图发送给 GPT Image 编辑接口，请求真实透明 PNG；响应在服务端和 iOS 客户端都会检查 Alpha，棋盘格或全不透明图片会被拒绝。

本地运行需要 Node.js 20+：

```bash
cd server
OPENAI_API_KEY=你的开发环境密钥 \
ADONIS_PROXY_CLIENT_TOKEN=本地临时令牌 \
npm start
```

默认只监听 `127.0.0.1:8787`。容器或受控测试环境可另设 `HOST` 与 `PORT`；把监听地址改成公网可达并不等于已经具备生产安全边界。

iOS 模拟器构建时传入完整端点和同一个临时令牌：

```bash
make build \
  ADONIS_STICKER_EXTRACTION_URL=http://127.0.0.1:8787/v1/sticker-extractions \
  ADONIS_STICKER_PROXY_TOKEN=本地临时令牌
```

供应商密钥只放在服务端环境变量 `OPENAI_API_KEY`，不得写进 App、Info.plist、源码或提交记录。`ADONIS_PROXY_CLIENT_TOKEN` 只适合本地开发；公开测试前仍需在网关完成 HTTPS、限流、滥用防护与设备级鉴权，不能把可从 App 提取的固定令牌当成生产安全边界。

运行本地契约测试：

```bash
npm test
```


## 取消与响应读取边界

- 客户端在等待期间断开连接，代理会中止对应的上游 HTTP 请求；其他同时进行的请求不受影响。
- 上游请求与响应体共用 130 秒截止，响应头已经收到也不会重新计时。超时返回 `504 / provider_timeout`。
- 供应商 JSON 在流式读取时限制为 `ceil(20 MiB / 3) × 4 + 1 MiB`，容纳既有 PNG 上限对应的 Base64 和有限元数据；实际解码后的 PNG 仍不能超过 20 MiB。
- `Content-Length` 已声明过大时立即拒绝；分块传输、缺少长度以及 HTTP 解压后的数据同样逐块检查。超限返回 `502 / provider_response_too_large`，停止读取剩余内容。
- 非成功供应商响应直接返回稳定错误并关闭未读响应体；日志不包含供应商响应内容。客户端已经离开时只记录 `client_disconnected`，不会继续尝试交付图片。

取消上游连接只证明代理停止传输和等待，不保证供应商任务立即结束、撤销计费或删除已接收数据。这些本机边界也不代替公开服务的鉴权、总并发限制和费用预算。

`npm test` 包含真实本地 HTTP 服务之间的断开、超时、分块超限、gzip 解压超限和并行请求隔离测试，全部只使用合成输入与本地上游，不调用图片供应商。测试可通过服务构造器缩短截止；启动脚本始终使用默认 130 秒。
