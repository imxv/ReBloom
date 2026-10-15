# 2026-09-07 透明代理请求生命周期验证

> 状态：代理实现、12 个 Node 测试、项目专项和 234 项全量模拟器回归均通过。对应 ADO-003 / ADO-Q04 / ADO-Q05；不是公开代理或真实供应商验收。

## 改动与原因

原代理只把独立的 130 秒超时信号传给上游，没有把客户端断开传过去；供应商响应也先整体调用 `json()` 再检查图片大小。用户离开后仍可能继续等待图片，异常响应也可能在检查前占用无界内存。

现实现把每条请求的取消控制器传给上游，同时保留 130 秒截止。截止覆盖上游请求到响应体读取结束，不会在收到响应头后重新开始。客户端断开只取消本条请求；正常响应完成不会被误当成取消。

供应商 JSON 在解析前逐块计数，最多 `ceil(20 MiB / 3) × 4 + 1 MiB`；声明长度过大立即拒绝，未知长度、分块和 gzip 解压后的字节也受限制。PNG 解码后的既有 20 MiB 上限与 Alpha 检查仍保留。非成功、超限或异常响应会中止上游并释放未读响应体。

输入 schema、唯一 AI 底图输入、模型、Prompt、PNG 透明契约、来源、用户确认页和 iOS 保存逻辑均未改变。新增 504 超时与 502 超大响应继续进入现有客户端失败恢复；没有自动重试或原图直抠兜底。

## 本地 HTTP 证据

Node.js 20.20.2，`make server-test`：12 通过、0 失败、0 跳过。原有 3 项验证请求格式与透明结构，新增 9 项使用真实本地代理和上游 HTTP 连接：

1. 客户端在上游响应头之前断开，上游连接关闭。
2. 用透传流观察真实上游首个响应块；确认已读取后才断开客户端，上游连接关闭。
3. 上游不返回响应头，截止后返回稳定 504 并关闭连接。
4. 上游已返回响应头但响应体停滞，仍受同一截止约束。
5. 声明 64 MiB 响应且不发送内容，立即返回 502 并关闭上游。
6. 未声明长度的 30 MiB 分块响应，即使不结束，也在解析 JSON 前因体积被拒绝。
7. gzip 压缩传输展开到 30 MiB 后，同样被逐块上限拒绝。
8. 上游返回 429 且不结束错误体，代理立即返回稳定错误并关闭上游；响应和日志不泄露错误内容。
9. 两条同时进行的提取中取消一条，另一条仍能正常接收并进入后续 payload 检查。

超时用例通过构造器把既有截止缩短为 200 毫秒，验证事件顺序和清理；它不是 130 秒真实供应商时延证据。测试图片为合成输入，测试上游在 127.0.0.1，没有真实图片 API 请求。

[Node 结果与代码哈希](../evidence/proxy-lifecycle-node-2026-09-07.json) · [完整测试输出](../evidence/proxy-lifecycle-node-2026-09-07.tap) · [旧实现负对照输出](../evidence/proxy-lifecycle-negative-control-2026-09-07.tap)。

负对照：同样的客户端断开和声明超大响应测试在修改前的 `HEAD:server/src/server.mjs` 上各等待 5 秒仍未完成，被测试框架终止；新实现均通过。负对照只放在 `/tmp/adonis-proxy-negative-control/`，没有回滚工作区。

## 项目回归

本轮最终执行结果如下，专项有用例重叠，不能相加当作独立测试总数：

| 命令 | 结果 | iOS 测试数 / 范围 |
| --- | --- | --- |
| `make ai-sticker-regression` | 通过 | 28 |
| `make ai-sticker-visual-regression` | 通过 | 固定视觉资产 |
| `make sample-regression` | 通过 | 28 |
| `make performance-regression` | 通过 | 18 |
| `make accessibility-regression` | 通过 | 12 |
| `make test` | 通过 | 234 |

最终全量 **234 通过、0 失败、0 跳过**，结果包为 `Test-Adonis-2026.09.07_10-15-13-+0800.xcresult`。设备为 iPhone 17 Pro / iOS 26.5 模拟器；Node 源码与测试另通过 `node --check`。本轮没有改 Swift 源码或图像资产。

[完整专项结果与服务端代码哈希](../evidence/proxy-lifecycle-regressions-2026-09-07.json) 保存可复查的 `.xcresult` 路径；原始本机日志位于 `/tmp/adonis-proxy-gates/`。

## 尚未证明

代理中止 HTTP 连接不等于供应商取消生成、撤销计费或删除已接收图片。当前仍没有公开代理、真实供应商质量/成本、真实弱网或支持 Apple Intelligence 的 iPhone 全链路证据；账号鉴权、总并发限制和总费用预算也不由本次单请求限制替代。

事件语义参考 [Node.js 20 ServerResponse close/finish](https://nodejs.org/docs/latest-v20.x/api/http.html#class-httpserverresponse)。代码用 `writableEnded` 区分正常结束与提前断开，本地 socket 测试验证实际取消传播。
