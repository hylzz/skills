# 测试基础设施能力清单与代码模板

集成测试依赖的 **testsupport** 指一组**能力**，不是固定包名或目录。执行 Skill 时先盘点项目现状，再决定复用或搭建。

---

## 1. 决策流程

```
1. 在仓库中搜索现有测试基础设施
   （常见：internal/testsupport、testsupport、internal/test/support、pkg/testutil 等）

2. 对照下方「必备 / 可选能力」逐项核对

3. 全部必备能力已满足 → 直接复用，不新建重复封装

4. 缺项 → 在已有包中扩展；完全没有 → 按 §3 模板新建
   （包名/路径遵循项目惯例，不必叫 internal/testsupport）
```

**原则**：能复用不重建；只补缺失能力；模板代码需按项目路由、配置、鉴权 Header 改名/改 import。

---

## 2. 能力清单

### 2.1 必备（集成测试 HTTP + 真实依赖）

| 能力 | 说明 | 典型符号 |
|------|------|----------|
| **环境 Setup** | 加载测试配置、初始化 DB/缓存、装配模块、注册路由 | `Setup() (*Env, error)` |
| **环境 Teardown** | 释放连接、关闭模块 | `Teardown()` / `(e *Env) Teardown()` |
| **API 路径前缀** | 拼接测试请求 Path | `APIPrefix()` |
| **HTTP 执行** | 向 Router 发请求 | `ExecHTTP(req)` |
| **HTTP + 业务响应解析** | 解析统一 JSON 包装（code/data/msg） | `ExecHTTPAPI(req)` |
| **身份 Header** | 构造鉴权所需 Header | `AuthHeader(name)` 等 |
| **唯一业务 ID** | 用例间隔离的主键/租户 ID | `NewUniqueID()` |
| **数据清理** | 用例结束删除本用例造数 | `Clean*(ctx, id)` |
| **Setup 失败 Skip** | 依赖不可用时跳过，不 Fail | Ginkgo `Skip(...)` |

### 2.2 按需（视项目而定）

| 能力 | 说明 |
|------|------|
| **内部调用 Header** | 内网/内部 API 所需 Header |
| **合法请求体模板** | 构造通过校验的 Create/Update 请求 |
| **高层造数 helper** | 如 `CreateXxx(t, env, req)`，封装多步 HTTP |
| **查库/查缓存断言** | `FindEntity`、`CountBy*` |
| **PatchSet（gomonkey）** | 聚合补丁，`Reset()` 供 `AfterEach` 调用 |
| **DropTestDatabase** | 套件级清空测试库（慎用，优先用例级 Clean） |

### 2.3 对照示例

| 项目已有 | 是否满足 |
|----------|----------|
| 仅有 `httptest` 手写请求、无 Setup | ❌ 缺环境生命周期，需补 |
| 有 Setup + ExecHTTP，无 Clean | ⚠️ 补 Clean 或等价清理 |
| 另一包名但能力齐全 | ✅ 直接复用，Skill 中引用该包即可 |
| SDK 提供的 `testsupport.ExecHTTPAPI` | ✅ 可复用 SDK，只补项目特有的 Setup/造数 |

---

## 3. 代码模板

以下模板为**示意**，import、配置字段、路由注册、Header 名需替换为项目实际值。

### 3.1 env.go — 环境生命周期

```go
package testsupport // 或项目既有包名

import (
    "context"
    "fmt"

    "github.com/gin-gonic/gin"
)

// Env 集成测试运行环境。
type Env struct {
    Router *gin.Engine
    Config Config // 项目配置类型
}

// Setup 初始化测试依赖；失败返回 error（调用方 Skip）。
func Setup() (*Env, error) {
    gin.SetMode(gin.TestMode)

    cfg, err := loadTestConfig()
    if err != nil {
        return nil, err
    }
    if err := initDatabase(cfg); err != nil {
        return nil, fmt.Errorf("连接数据库失败: %w", err)
    }
    if err := initCache(cfg); err != nil {
        return nil, fmt.Errorf("连接缓存失败: %w", err)
    }
    mods, err := initModules(cfg)
    if err != nil {
        return nil, fmt.Errorf("初始化模块失败: %w", err)
    }
    if err := runBootstrap(context.Background(), cfg, mods); err != nil {
        return nil, fmt.Errorf("bootstrap 失败: %w", err)
    }

    r := gin.New()
    registerRoutes(r, mods)

    return &Env{Router: r, Config: cfg}, nil
}

// Teardown 释放资源。
func (e *Env) Teardown() {
    if e == nil {
        return
    }
    closeModules()
    closeCache()
    closeDatabase()
}

// APIPrefix 返回 HTTP 测试路径前缀（含版本）。
func (e *Env) APIPrefix() string {
    return e.Config.RouterPrefix + "/v1" // 按项目调整
}
```

### 3.2 http.go — HTTP 与 Header

```go
package testsupport

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"

    "github.com/gin-gonic/gin"
)

type APIResponse struct {
    Code int             `json:"code"`
    Data json.RawMessage `json:"data"`
    Msg  string          `json:"msg"`
}

type HTTPReq struct {
    Router  *gin.Engine
    Method  string
    Path    string
    JSON    any
    Headers http.Header
}

func AuthHeader(authName string) http.Header {
    h := make(http.Header)
    h.Set("X-Auth-Name", authName) // 按项目鉴权 Header 调整
    return h
}

func InternalHeader() http.Header {
    h := make(http.Header)
    h.Set("X-Internal-Request", "true")
    return h
}

func ExecHTTP(r HTTPReq) (*httptest.ResponseRecorder, error) {
    body, _ := json.Marshal(r.JSON)
    req := httptest.NewRequest(r.Method, r.Path, bytes.NewReader(body))
    if r.Headers != nil {
        req.Header = r.Headers.Clone()
    }
    if r.JSON != nil {
        req.Header.Set("Content-Type", "application/json")
    }
    w := httptest.NewRecorder()
    r.Router.ServeHTTP(w, req)
    return w, nil
}

func ExecHTTPAPI(r HTTPReq) (*httptest.ResponseRecorder, APIResponse, error) {
    w, err := ExecHTTP(r)
    if err != nil {
        return nil, APIResponse{}, err
    }
    var resp APIResponse
    if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
        return w, APIResponse{}, err
    }
    return w, resp, nil
}
```

### 3.3 helpers.go — 造数与清理

```go
package testsupport

import (
    "context"
    "fmt"
    "math/rand/v2"
    "testing"
)

func NewUniqueID() string {
    return fmt.Sprintf("test-%d", rand.IntN(1_000_000))
}

func ValidCreatePayload(id string) CreateRequest {
    return CreateRequest{ID: id /* ... */}
}

func CleanEntity(ctx context.Context, id string) error {
    // 按项目实现清理逻辑
    return nil
}

func CreateEntity(t *testing.T, env *Env, req CreateRequest) CreateResponse {
    t.Helper()
    w, resp, err := ExecHTTPAPI(HTTPReq{
        Router: env.Router, Method: "POST",
        Path: env.APIPrefix() + "/entities", JSON: req,
        Headers: AuthHeader("admin"),
    })
    if err != nil || w.Code != 200 || resp.Code != 0 {
        t.Fatalf("CreateEntity: status=%d err=%v", w.Code, err)
    }
    return CreateResponse{}
}
```

### 3.4 assert.go — 查库断言（可选）

```go
package testsupport

import "context"

func FindEntity(ctx context.Context, id string) (*Entity, error) {
    return nil, nil
}

func CountByTenant(ctx context.Context, table, tenantID string) (int64, error) {
    return 0, nil
}
```

### 3.5 patches.go — gomonkey 聚合（按需）

```go
package testsupport

import "github.com/agiledragon/gomonkey/v2"

type PatchSet struct {
    patches []*gomonkey.Patches
}

func (p *PatchSet) ApplyFunc(target, double any) *PatchSet {
    p.patches = append(p.patches, gomonkey.ApplyFunc(target, double))
    return p
}

func (p *PatchSet) Reset() {
    for i := len(p.patches) - 1; i >= 0; i-- {
        p.patches[i].Reset()
    }
    p.patches = nil
}
```

运行含 gomonkey 的包：`go test -gcflags="all=-N -l" ./...`

---

## 4. 与 Ginkgo 集成

```go
BeforeEach(func() {
    var err error
    env, err = testsupport.Setup()
    if err != nil {
        Skip("集成环境不可用: " + err.Error())
    }
    entityID = testsupport.NewUniqueID()
})

AfterEach(func() {
    if env != nil {
        _ = testsupport.CleanEntity(ctx, entityID)
        env.Teardown()
    }
})
```

需要 `*testing.T` 的 helper：`testsupport.CreateEntity(GinkgoT(), env, req)`。

---

## 5. 新建时的目录建议

包名/路径以项目惯例为准，常见：

- `internal/testsupport/`
- `internal/testutil/`
- `pkg/testsupport/`

文件拆分参考：`env.go`、`http.go`、`helpers.go`、`assert.go`、`patches.go`（按需）。
