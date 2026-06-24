# 测试示例

约定见 [STYLE.md](STYLE.md)。集成测试用 **Ginkgo + Gomega**；单元测试用 **标准 testing**。

以下示例均为**通用模板**，包名、路由、Suite 名、业务码等需按当前项目替换。

---

## Suite 入口

Suite 名用服务/API 边界，不用 `Controller Suite` 等技术层名称。详见 STYLE §2.2。

```go
// suite_test.go
package api_test

import (
    "fmt"
    "os"
    "testing"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

func TestYourServiceAPI(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "Your Service API Suite") // 替换为项目 Suite 名
}

// Suite 级：每个 It 前打标题、结束后换行；Describe 内 BeforeEach/AfterEach 只做 Setup/清理。
var _ = BeforeEach(func() {
    _, _ = fmt.Fprintf(os.Stderr, "\n▶ %s\n", CurrentSpecReport().FullText())
})

var _ = AfterEach(func() {
    _, _ = fmt.Fprintln(os.Stderr)
})
```

---

## Ginkgo 集成 Spec（完整模板）

```go
// entity_create_test.go
package api_test

import (
    "context"
    "net/http"

    "your/module/testsupport" // 替换为项目 testsupport 包路径

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

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
                Path:    env.APIPrefix() + "/entities",
                JSON:    req,
                Headers: testsupport.AuthHeader("admin"),
            })
            Expect(err).NotTo(HaveOccurred())
            Expect(w.Code).To(Equal(http.StatusOK))
            Expect(apiResp.Code).To(Equal(0)) // 按项目业务码调整

            entity, err := testsupport.FindEntity(ctx, entityID)
            Expect(err).NotTo(HaveOccurred())
            Expect(entity).NotTo(BeNil())
        })
    })

    Context("Given 已存在同名实体", func() {
        BeforeEach(func() {
            testsupport.CreateEntity(GinkgoT(), env,
                testsupport.ValidCreatePayload(entityID))
        })

        It("When 再次创建 Then 应返回 409", func() {
            w, apiResp, err := testsupport.ExecHTTPAPI(testsupport.HTTPReq{
                Router:  env.Router,
                Method:  http.MethodPost,
                Path:    env.APIPrefix() + "/entities",
                JSON:    testsupport.ValidCreatePayload(entityID),
                Headers: testsupport.AuthHeader("admin"),
            })
            Expect(err).NotTo(HaveOccurred())
            Expect(w.Code).To(Equal(http.StatusConflict))
            Expect(apiResp.Msg).NotTo(BeEmpty())
        })
    })
})
```

---

## Ginkgo：鉴权场景

```go
Context("Given 未携带身份 Header", func() {
    It("When 访问受保护接口 Then 应返回 401", func() {
        w, _, err := testsupport.ExecHTTPAPI(testsupport.HTTPReq{
            Router: env.Router,
            Method: http.MethodGet,
            Path:   env.APIPrefix() + "/protected-resource", // 按项目路由调整
        })
        Expect(err).NotTo(HaveOccurred())
        Expect(w.Code).To(Equal(http.StatusUnauthorized))
    })
})
```

---

## 单元测试：表驱动（不用 Ginkgo）

```go
func TestValidateCode(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        wantErr bool
    }{
        {"合法", "abc_123", false},
        {"空", "", true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateCode(tt.input)
            if (err != nil) != tt.wantErr {
                t.Fatalf("ValidateCode(%q) err = %v", tt.input, err)
            }
        })
    }
}
```

---

## gomonkey：按需打桩

优先 fake/stub；仅无法注入时使用。

```go
// patches.go（testsupport 或测试包内）
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

```go
var _ = Describe("某需打桩的单元", func() {
    var patches PatchSet

    AfterEach(func() {
        patches.Reset()
    })

    It("When 外部调用失败 Then 应返回 wrapped error", func() {
        patches.ApplyFunc(externalCall, func() error {
            return errors.New("boom")
        })
        err := functionUnderTest()
        Expect(err).To(MatchError(ContainSubstring("boom")))
    })
})
```

运行含 gomonkey 的包：

```bash
go test -gcflags="all=-N -l" ./path/to/pkg/...
```

---

## 覆盖率检查

```bash
go test ./path/to/pkg/... -coverprofile=coverage.out -covermode=atomic
go tool cover -func=coverage.out | tail -1
```
