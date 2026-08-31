# Adonis 透明贴纸代理

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
