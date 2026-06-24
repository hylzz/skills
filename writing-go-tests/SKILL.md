---
name: writing-go-tests
description: 编写 Go 测试：集成测试用 Ginkgo+Gomega BDD，单元测试用标准 testing；盘点或搭建 testsupport 测试基础设施；按需 gomonkey 打桩。在用户要求补测试、写用例、覆盖率、BDD、Ginkgo 时使用。
---

# Go 测试编写

> **写每个用例前先判断价值**：只写能验证真实行为、关键分支或回归风险的用例，不写 trivial、重复或与已有测试等价的 Spec。

**先阅读**：[STYLE.md](STYLE.md)（Ginkgo BDD、gomonkey、覆盖率）。  
**基础设施**：[testsupport-template.md](testsupport-template.md)（能力清单 + 代码模板）。

文档中的 `{Service Name}`、`{Feature}`、`Your Service` 等为**占位符**，执行时替换为当前项目的实际名称。

## 执行流程

```
1. 读 STYLE.md
2. 盘点项目测试基础设施能力 → 满足则复用，不足则按 template 搭建/扩展
3. 集成 → Ginkgo+Gomega；单元 → testing 表驱动
4. 打桩：优先 fake/stub，必要时 gomonkey
5. 跑测试 + 覆盖率
```

## Step 1：盘点或搭建测试基础设施

**testsupport 是能力集合，不是固定路径。** 先在仓库搜索现有封装（常见目录名：`testsupport`、`testutil`、`test/support` 等），再对照 [testsupport-template.md §2](testsupport-template.md#2-能力清单) 逐项核对。

| 结论 | 动作 |
|------|------|
| 必备能力 **已全部满足** | **直接复用**已有包，不重复造轮子 |
| **部分缺失** | 在已有包中 **补缺失函数** |
| **完全没有** | 按 [testsupport-template.md §3](testsupport-template.md#3-代码模板) **新建**（包名/路径遵循项目惯例） |

### 必备能力（摘要）

- `Setup()` / `Teardown()` — 环境生命周期
- `APIPrefix()` — HTTP 路径前缀
- `ExecHTTP` / `ExecHTTPAPI` — 发请求 + 解析业务响应
- `AuthHeader` 等 — 鉴权 Header
- `NewUniqueID()` + `Clean*(ctx, id)` — 用例隔离与清理
- Setup 失败 → Ginkgo `Skip(...)`，勿 Fail

按需：内部 Header、造数 helper、查库断言、PatchSet。详见 template。

## Step 2：测试类型与框架

| 类型 | 框架 | 包 | 放置 |
|------|------|-----|------|
| **集成** | **Ginkgo + Gomega** | `xxx_test` | `internal/controller/` 等 |
| **单元** | **`testing` 表驱动** | `xxx` 或 `xxx_test` | 与源码同目录 |

集成测试包内 **一个** `suite_test.go`。Suite 名用**服务/API/限界上下文**（执行时替换为当前项目名），不用 `Controller Suite` 等技术分层名（详见 STYLE §2.2）。

`suite_test.go` 还需注册 **Suite 级顶层 BeforeEach/AfterEach** 打印每个 `It` 标题并换行分隔（详见 STYLE §2.2）；**不要**在各 Describe 的 BeforeEach/AfterEach 里重复写。

```go
func TestYourServiceAPI(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "Your Service API Suite") // 替换为项目 Suite 名
}
```

Spec 写在同包其他 `*_test.go`；业务语义在 `Describe`（如 `{Feature} API`），结构用 `Context` / `It`。

## Step 3：BDD 结构（Ginkgo）

| 节点 | 含义 |
|------|------|
| `Describe` | 功能/API |
| `Context` | Given（`BeforeEach` 准备前置） |
| `It` | When + Then（行为描述 + Gomega 断言） |

**禁止**：`BeforeSuite` 共享可变业务数据；依赖 Spec 顺序。

helper 需要 `*testing.T` 时传 `GinkgoT()`。

## Step 4：gomonkey（按需）

仅当无法接口注入、必须替换包级函数/方法/变量时使用。详见 STYLE §5。

- `AfterEach` 必须 `patches.Reset()`
- 运行：`go test -gcflags="all=-N -l" ./pkg/...`

## Step 5：覆盖率

| 情况 | 行为 |
|------|------|
| 用户指定 | **严格达标** |
| 未指定 | 行 ≥80%、分支 ≥70%、核心包 ≥85%（STYLE §7） |

## 检查清单

- [ ] STYLE.md、testsupport-template.md 已读
- [ ] 已盘点并复用/搭建测试基础设施
- [ ] 集成测试 Suite 名有业务含义（STYLE §2.2）；suite_test.go 含顶层 BeforeEach/AfterEach 用例标题分隔
- [ ] AfterEach 清理；gomonkey 已 Reset
- [ ] 覆盖率达标
- [ ] `go test ./...` 通过

## 示例

- [examples.md](examples.md) — Ginkgo Spec、gomonkey、单元表驱动
- [testsupport-template.md](testsupport-template.md) — 能力清单与代码模板
- [STYLE.md](STYLE.md) — 完整约定
