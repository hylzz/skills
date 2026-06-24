# Go 测试风格指南

陈述性、可复用的测试编写约定。适用于 HTTP 服务、分层架构的 Go 项目。

示例中的 `{Feature}`、`Your Service`、`entity` 等为**通用占位**，不含特定业务域；执行 Skill 时按当前项目替换。

---

## 1. 总体原则

- **两层互补**：集成测试验证端到端行为；单元测试验证纯逻辑。同一行为不重复测两遍。
- **BDD 框架**：集成测试使用 **Ginkgo v2 + Gomega**；单元测试默认 **标准库 `testing` + 表驱动**（复杂场景可用 Ginkgo）。
- **打桩克制**：**非必要不用 gomonkey**；优先真实依赖、testsupport、接口注入、手写 stub/fake。
- **可独立运行**：每个 `It` 场景数据隔离；`AfterEach` 清理；不依赖 Spec 执行顺序。
- **环境缺失则跳过**：`Setup` 失败用 `Skip()`，不要 Fail。

---

## 2. BDD 集成测试（Ginkgo + Gomega）

### 2.1 结构映射

| Ginkgo | BDD 语义 | 职责 |
|--------|----------|------|
| `Describe` | 功能 / API | 按业务能力或 API 分组 |
| `Context` | **Given** 前置条件 | 共享 Given 放 `BeforeEach` |
| `It` | **When + Then** | 一次用户行为 + 全部断言 |
| `BeforeEach` | Given 准备 | Setup、造数 |
| `AfterEach` | 清理 | Teardown 数据、Reset 打桩 |

`It` 的描述用完整行为句，例如：

```text
It("When 提交合法请求 Then 应创建实体并返回成功", ...)
It("When 提交非法参数 Then 应返回 400", ...)
```

### 2.2 Suite 入口与命名

每个集成测试包 **一个** Suite 入口文件（如 `suite_test.go`）。业务 Spec 分散在同包 `*_test.go` 中，**不要**单独建 `internal/test/` 大杂烩目录。

#### 命名层级

| 层级 | 命名依据 | 示例 |
|------|----------|------|
| **Suite**（`RunSpecs` 第二参数） | 服务名 / API 边界 / 限界上下文 | `{Service Name} API Suite` |
| **`TestXxx` 函数** | 与 Suite 对应，`PascalCase`、无空格 | `Test{ServiceName}API` |
| **`Describe`** | 具体 API 或业务能力 | `{Feature A} API`、`{Feature B} API` |
| **`Context` / `It`** | Given / When+Then 行为句 | `Given 无已有记录` |

Suite 名会出现在 `go test` 输出和 `-focus` / `-skip` 匹配范围中，是**整包 Spec 的报告标题**，不是单个用例粒度。

#### Suite 命名原则

- **用业务边界，不用技术分层**：优先服务名、API 名、限界上下文；避免 `Controller Suite`、`Handler Suite` 等仅描述代码层的名称。
- **一个集成测试包一个 Suite**：包内所有 Spec 共用同一 Suite 名；更细的业务语义放在 `Describe`，不要为了命名再拆 Suite。
- **`TestXxx` 与 `RunSpecs` 保持一致**：函数名是 Suite 名的代码标识，字符串是 CI/终端可读标题。

| 集成测试包范围 | 推荐 Suite 名 | 避免 |
|--------------|---------------|------|
| 整个服务的 HTTP/API 面 | `{Service Name} API Suite` | `Controller Suite` |
| 单一限界上下文 | `{Bounded Context} Suite` | `Integration Suite` |
| Worker / 消费者端到端 | `{Domain} Worker Suite` | `Consumer Suite`（过泛） |

#### 入口示例

```go
package api_test // 与被测层一致，常见为 xxx_test 外部测试包

import (
    "testing"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

func TestYourServiceAPI(t *testing.T) { // 替换为项目服务名
    RegisterFailHandler(Fail)
    RunSpecs(t, "Your Service API Suite") // 替换为项目 Suite 名
}
```

#### 用例输出分隔（suite_test.go）

**不要**在各 `Describe` 的 `BeforeEach`/`AfterEach` 里打印标题；在 **`suite_test.go` 用 Suite 级顶层钩子统一处理**，Describe 内的钩子仍只负责 Setup/Teardown/清理：

```go
var _ = BeforeEach(func() {
    _, _ = fmt.Fprintf(os.Stderr, "\n▶ %s\n", CurrentSpecReport().FullText())
})

var _ = AfterEach(func() {
    _, _ = fmt.Fprintln(os.Stderr)
})
```

- 输出到 **`os.Stderr`**，配合 `go test -v` 即可在终端/IDE 看到（无需改各 Describe）
- 顶层 `BeforeEach` 在 Describe 的 Setup **之前**执行，顺序：标题 → Setup 日志 → It 日志 → 换行
- 若仅用 `GinkgoWriter`，需额外加 `-args -ginkgo.v` 才可见；集成测包推荐 Stderr 方案
- 业务 Spec 文件**无需**为打印标题重复写钩子

同一包内按业务能力分 `Describe`，而非按 Handler/Controller 文件名：

```go
var _ = Describe("{Feature A} API", func() { /* ... */ })
var _ = Describe("{Feature B} API", func() { /* ... */ })
```

### 2.3 Spec 模板

```go
var _ = Describe("{Feature} API", func() {
    var (
        env      *testsupport.Env
        ctx      context.Context
        entityID string
    )

    BeforeEach(func() {
        var err error
        env, err = testsupport.Setup()
        if err != nil {
            Skip("集成环境不可用: " + err.Error())
        }
        ctx = context.Background()
        entityID = testsupport.NewUniqueID()
    })

    AfterEach(func() {
        if env != nil {
            _ = testsupport.CleanEntity(ctx, entityID)
            env.Teardown()
        }
    })

    Context("Given 无已有记录", func() {
        It("When 提交合法创建请求 Then 应持久化并返回成功", func() {
            req := testsupport.ValidCreatePayload(entityID)

            w, apiResp, err := testsupport.ExecHTTPAPI(testsupport.HTTPReq{
                Router:  env.Router,
                Method:  http.MethodPost,
                Path:    env.APIPrefix() + "/entities", // 按项目路由调整
                JSON:    req,
                Headers: testsupport.AuthHeader("admin"),
            })
            Expect(err).NotTo(HaveOccurred())
            Expect(w.Code).To(Equal(http.StatusOK))
            Expect(apiResp.Code).To(Equal(0)) // 按项目业务码常量调整

            entity, err := testsupport.FindEntity(ctx, entityID)
            Expect(err).NotTo(HaveOccurred())
            Expect(entity).NotTo(BeNil())
        })
    })

    Context("Given 已存在同名实体", func() {
        BeforeEach(func() {
            testsupport.CreateEntity(GinkgoT(), env, testsupport.ValidCreatePayload(entityID))
        })

        It("When 再次创建 Then 应返回 409", func() {
            w, apiResp, err := testsupport.ExecHTTPAPI(/* ... */)
            Expect(err).NotTo(HaveOccurred())
            Expect(w.Code).To(Equal(http.StatusConflict))
            Expect(apiResp.Msg).NotTo(BeEmpty())
        })
    })
})
```

### 2.4 Gomega 断言约定

- HTTP：`Expect(w.Code).To(Equal(http.StatusOK))`
- 业务码：`Expect(apiResp.Code).To(Equal(0))`（或项目常量）
- 消息：`Expect(apiResp.Msg).To(ContainSubstring("关键字"))`
- 查库：`Expect(entity).NotTo(BeNil())`、`Expect(count).To(Equal(int64(1)))`
- 错误：`Expect(err).NotTo(HaveOccurred())`

### 2.5 应覆盖的场景类型

每个核心 API 至少：

1. Happy path
2. 参数/体非法 → 400
3. 业务规则拒绝 → 400/409
4. 资源不存在 → 404
5. 鉴权缺失/不足 → 401/403
6. 状态流转与副作用

### 2.6 反模式（Ginkgo）

- ❌ `BeforeSuite` / `AfterSuite` 持有可变共享业务数据
- ❌ 多个 `Describe` 依赖执行顺序
- ❌ 空 `It` 或只有 `Expect(true).To(BeTrue())`
- ❌ 集成测试环境不可用时 Fail（应 `Skip`）

---

## 3. 测试基础设施

testsupport 指满足集成测试所需的**一组能力**，不是固定包名。执行 Skill 时先搜索项目已有封装（如 `testsupport`、`testutil`、`test/support`），**能力齐全则复用**；缺项则扩展或按 [testsupport-template.md](testsupport-template.md) 搭建。

### 3.1 必备能力

| 能力 | 说明 |
|------|------|
| Setup / Teardown | 加载测试配置、初始化依赖、装配路由 |
| APIPrefix | 测试 HTTP 路径前缀 |
| ExecHTTP / ExecHTTPAPI | 发请求、解析统一响应 |
| AuthHeader 等 | 鉴权/内部调用 Header 构造 |
| NewUniqueID | 用例级唯一业务 ID |
| Clean* | 用例结束清理造数 |
| Setup 失败 → Skip | 依赖不可用时不 Fail |

### 3.2 按需能力

合法请求体模板、高层造数 helper、查库断言、PatchSet（gomonkey）、DropTestDatabase 等——见 [testsupport-template.md §2](testsupport-template.md#2-能力清单)。

### 3.3 Setup 职责

1. 加载测试配置（如 `config.test.json`）
2. 初始化 DB、缓存等外部依赖
3. 装配业务模块 / 注册路由
4. 返回 `Env`（至少含 `Router`、配置）

`Setup` 失败 → Spec 内 `Skip(...)`。

### 3.4 与 Ginkgo 协作

需要 `*testing.T` 的 helper 在 Spec 内传 `GinkgoT()`。

代码模板见 [testsupport-template.md](testsupport-template.md)。

---

## 4. 单元测试

- **默认**：标准库 `testing` + 表驱动 + `t.Run`
- **包名**：导出 API 用 `foo_test`；未导出函数用 `foo` 白盒
- **可选 Ginkgo**：单个模块 Spec 很多、层级复杂时
- **Logger**：仅会打日志的用例内 `logger.InitLogger()`；避免无必要的 `TestMain`
- **不测 trivial**

---

## 5. 打桩（gomonkey）

### 5.1 原则

**非必要不使用。** 按优先级：

1. 真实依赖 + testsupport（集成测试首选）
2. 接口注入 + 手写 fake/stub（单元测试首选）
3. **gomonkey** — 仅当无法改构造、无法注入，且必须替换包级函数/方法/变量时

### 5.2 适用场景

- 包级函数、第三方 SDK、无法接口化的 legacy 调用
- 时间、随机数、UUID 等需要确定性结果
- 必须模拟错误返回路径，且无法用 fake 覆盖

### 5.3 不适用

- 已有接口可注入（Repository、Cache、HTTP Client）
- 集成测试能走真实 DB / 缓存等外部依赖
- 仅为少写几行 stub 代码

### 5.4 用法约定

- 补丁放项目测试基础设施包的 `PatchSet` 或测试文件内，`AfterEach` **必须** `Reset()`
- 运行需关闭内联：

```bash
go test -gcflags="all=-N -l" ./path/to/pkg/...
```

- 禁止在生产代码中为打桩加钩子

---

## 6. 断言顺序（HTTP 集成）

1. helper `err`
2. HTTP status
3. 业务 code
4. 响应 `data`
5. DB / 缓存副作用

---

## 7. 覆盖率要求

### 7.1 用户指定指标时

**严格按用户数字执行**，完成后汇报实际值与缺口。

### 7.2 用户未指定时的默认值

| 指标 | 默认值 |
|------|--------|
| 行覆盖率 | ≥ 80%（变更涉及包） |
| 分支覆盖率 | ≥ 70% |
| 核心逻辑包 | ≥ 85% |

```bash
go test ./path/... -coverprofile=coverage.out -covermode=atomic
go tool cover -func=coverage.out
```

### 7.3 执行流程

1. 明确范围 → 2. 跑基线 → 3. 补错误分支 → 4. 复测达标

---

## 8. 依赖

```go
require (
    github.com/onsi/ginkgo/v2 v2.x
    github.com/onsi/gomega v1.x
    github.com/agiledragon/gomonkey/v2 v2.x  // 按需
)
```

---

## 9. 快速检查清单

- [ ] 集成测试用 Ginkgo Describe/Context/It
- [ ] Suite 名有业务含义（§2.2）+ testsupport 就绪
- [ ] 每 Spec 数据隔离 + AfterEach 清理
- [ ] gomonkey 仅必要时使用且 AfterEach Reset
- [ ] 覆盖率达标
- [ ] `go test ./...` 通过（gomonkey 包加 `-gcflags="all=-N -l"`）
