---
name: setup-rules
description: >-
  Sync personal Cursor rule templates from ~/.cursor/rules into the current
  project's .cursor/rules/. Use when the user runs /setup-rules, asks to load
  global rules into a project, bootstrap project rules, or sync .mdc templates.
disable-model-invocation: true
---

# Setup Rules

将 `~/.cursor/rules` 中用户自行安装的全局 rule 同步到当前项目的 `.cursor/rules/`。

本 skill **不会**在 `~/.cursor/rules` 预置任何 rule 文件；用户需手动把要复用的 `.mdc` 放进该目录。

## Global rules source

| Path | 说明 |
|------|------|
| `~/.cursor/rules` | Windows 与 Linux 统一；用户手动安装 `.mdc` |
| `CURSOR_RULES_SRC` | 可选环境变量，覆盖默认路径 |

只同步 `*.mdc` 文件；其他文件（如 `README.md`）不会复制到项目。

## When to run

- 新项目需要载入已在 `~/.cursor/rules` 安装的全局 rule
- 用户在全局目录新增或更新了 rule，想推到当前项目

## Process

### 1. Explore

读取当前状态，不要假设：

- `~/.cursor/rules` 是否存在、有哪些 `.mdc`
- 项目 `.cursor/rules/` 是否已有文件

```bash
ls -la "$HOME/.cursor/rules" 2>/dev/null || echo "directory missing"
```

**若目录不存在或没有 `.mdc` 文件**：停止同步，告知用户需先将 rule 手动安装到 `~/.cursor/rules`（例如从其他项目复制，或用 create-rule 写好后再放进去）。**不要**替用户创建示例 rule。

### 2. Confirm (if needed)

项目内已有同名 `.mdc` 时默认**不覆盖**；说明将跳过哪些文件。仅当用户明确要求时用 `--force`。

用户可指定只同步部分 rule（按文件名），手动复制即可。

### 3. Sync

```bash
bash "$HOME/.cursor/skills/setup-rules/scripts/sync-rules.sh" --dry-run .
bash "$HOME/.cursor/skills/setup-rules/scripts/sync-rules.sh" .
```

覆盖已有文件：

```bash
bash "$HOME/.cursor/skills/setup-rules/scripts/sync-rules.sh" --force .
```

脚本不可用时：

1. `mkdir -p .cursor/rules`
2. 复制 `~/.cursor/rules/*.mdc` → `.cursor/rules/`
3. 已存在且未要求覆盖则跳过

### 4. Report

汇报源路径、已复制/已跳过的文件，并说明：全局 rule 在 `~/.cursor/rules` 手动维护；项目内可单独修改，默认不会被覆盖。

## Installing global rules (user manual)

用户自行将 `.mdc` 放入 `~/.cursor/rules`，例如：

```bash
mkdir -p ~/.cursor/rules
cp /path/to/my-rule.mdc ~/.cursor/rules/
```

`.mdc` 格式（frontmatter + 正文）见 create-rule skill；`alwaysApply: true` 表示始终生效，`globs` 表示按文件匹配。

## Bundled script

- [scripts/sync-rules.sh](./scripts/sync-rules.sh) — 从 `~/.cursor/rules` 复制 `.mdc`，默认不覆盖，支持 `--force` 与 `--dry-run`
