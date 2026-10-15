# 回归结果验收与保留

`xcodebuild` 退出 0 或打印 `TEST SUCCEEDED` 不能单独证明目标用例已执行。2026-09-07 的独立 macOS XCTest 实验中，不存在的 `-only-testing` 方法产生 0 项测试、显式跳过的方法产生 1 项跳过，两次命令仍打印成功。另一个实际问题是 Xcode 自动清理 `.derivedData/Logs/Test` 中的旧结果包，使历史文档路径失效。

本工具服务 ADO-003 的首次流程回归验收与 ADO-102 工程门禁，不改变产品主线或 App 行为。

## 运行并验收

```bash
make verified-test
```

它运行完整 iOS 测试，要求至少 234 项、`AdonisTests` 与 `AdonisUITests` 都实际执行、零失败、零跳过、零预期失败。234 是当前已记录全量回归的最低数量；未来有意删除或拆分测试时，应先解释覆盖变化，再调整 `MINIMUM_TESTS`，不要为得到绿色结果降低它。数量下限与两个 target 存在不等于逐个证明当前源码中所有用例都被选中；关键用例可用下述 `--require` 单独锁定。

每次运行都会创建独立的 `.artifacts/verified-tests/<UUID>/tests.xcresult`。只有 `xcodebuild` 退出 0 且该结果包通过核验，才产生同目录的 `verification.json` 并返回 0。已有包不覆盖，失败包保留，不从公共日志目录猜测“最新一次”。此目录已被仓库忽略；需交付的 JSON 可显式复制进 `docs/evidence`，不要把截图或图片包自动提交。

此入口是可选增强，现有 `make test` 与其他专项命令保持原状。它只隔离结果输出，不隔离 DerivedData、源文件或模拟器；两个 UI 测试仍不能同时操作同一个模拟器。并行需要调用者分别指定独立模拟器与 `DERIVED_DATA`，还需注意 `make project` 共享工程生成。

专项可以直接使用 runner，不需要修改已有 Makefile 配方：

```bash
PYTHONDONTWRITEBYTECODE=1 python3 scripts/run_verified_tests.py --minimum-tests 1 -- \
  -project Adonis.xcodeproj -scheme Adonis \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath .derivedData test \
  -only-testing:AdonisTests/ModelStorePolicyTests
```

runner 自动把每个 `-only-testing:Target/Suite/Method` 或 `-only-testing Target/Suite/Method` 转成必需覆盖条件，两种写法混用也逐项检查。指定单个方法时必须精确执行该方法；指定 suite 或 target 时，检查其中至少一个用例实际通过，并不推断该 suite 的源码用例总数。命令执行不使用 shell 拼接，带空格的路径作为独立参数传递。取消、进程失败或验证失败均不会生成成功报告。

## 只检查已完成结果

```bash
python3 scripts/verify_xcresult.py '/absolute/path/to/tests.xcresult' \
  --minimum-tests 234 \
  --require AdonisTests \
  --require AdonisUITests/AdonisFlowUITests/testPreparedSampleCanBeCollectedAndFoundInBloomCalendar \
  --output '/absolute/path/to/new-verification.json'
```

要求显式结果路径。它只读取该包，不启动 App、不修改模拟器、不重跑测试，也不会创建缺失的结果包。`--require` 可重复，按 target / suite / method 完整路径段匹配，不接受通配符；方法末尾的 `()` 可省略。`--output` 是可选的，默认向标准输出写 JSON；已有输出文件一律拒绝覆盖，也禁止写进输入结果包。

核验条件：

- `Info.plist` 存在，且当前 Xcode 的 `xcresulttool` 能读取 summary 与 tests。
- summary 为 Passed，测试数为合法非负整数，达到至少 1 项或显式数量下限；通过数等于总数，失败、跳过、预期失败均为 0。
- 开始与结束时间有效，没有未解释的 failure details；用例树数量与摘要一致。
- 所有用例通过；用例树若记录某次失败重试，也拒绝按干净通过验收。
- 每个必需 target、suite 或方法实际存在且通过；同名方法不会跨 target 冒充。

工具面向当前 Xcode 26 XCTest 结果格式。重复的用例身份、不一致的树、未知状态或缺失字段会拒绝验收，不能静默降级为成功。复杂参数化、重复与多配置测试如产生不同结果结构，应补充独立证据后扩展解析；当前门禁不保证覆盖所有 Swift Testing 或未来 Xcode 格式。

## 证据范围

JSON 包含读取时间、测试开始/结束时间、原结果路径、统计、用例标识、设备平台，以及 summary/tests 两份解析内容的 SHA-256。哈希可用于对照保存的报告，但不是源代码哈希，也不证明结果与当前 checkout 一致。后续改代码必须重新运行相应门禁；重新读取历史包不算新回归。

该工具不会证明截图已经目检、生成像素合格、真实供应商质量、相册实际写入或真实 iPhone 验收。它不自动勾选 ADO-006、ADO-008、ADO-108，也不修改已有历史验证记录。独立结果目录防止 Xcode 的默认日志轮换，但仍可能被用户手工删除；JSON 不能替代完整结果包与需要的截图。

## 工具自身回归

```bash
make test-tools
```

只运行 Python 标准库测试，不启动模拟器或发起供应商请求。本轮实现验证、真实结果包核验与独立 XCTest 反例见 [验证记录](verification/2026-09-07-test-evidence.md)。
