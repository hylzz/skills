#!/bin/bash

# PRD 生成脚本 — 交互式生成简体中文 PRD 骨架

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     PRD 生成器 — 简体中文交互模式      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_FILE="$SKILL_DIR/references/prd_template.md"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}✗ 未找到模板: $TEMPLATE_FILE${NC}"
    exit 1
fi

prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local required="$3"

    while true; do
        echo -e "${YELLOW}${prompt}${NC}"
        read -r input

        if [ -n "$input" ]; then
            printf -v "$var_name" '%s' "$input"
            break
        elif [ "$required" != "true" ]; then
            printf -v "$var_name" '%s' ""
            break
        else
            echo -e "${RED}此项为必填，请填写。${NC}"
        fi
    done
}

echo -e "${GREEN}步骤 1：基本信息${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

prompt_input "产品/功能名称:" PRODUCT_NAME true
prompt_input "一句话描述:" DESCRIPTION true
prompt_input "输出文件名（默认: ${PRODUCT_NAME}_产品需求文档.md）:" OUTPUT_FILE false

if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="${PRODUCT_NAME}_产品需求文档.md"
fi

echo ""
echo -e "${GREEN}步骤 2：问题与背景${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

prompt_input "要解决的核心问题/痛点:" PROBLEM true
prompt_input "主要目标用户:" PRIMARY_USERS true
prompt_input "关键业务目标:" BUSINESS_GOALS true

echo ""
echo -e "${GREEN}步骤 3：成功与范围${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

prompt_input "如何衡量成功（指标）:" SUCCESS_METRICS true
prompt_input "目标上线时间（或填「待定」）:" TIMELINE false
prompt_input "明确不在本期范围的内容:" OUT_OF_SCOPE false

echo ""
echo -e "${GREEN}步骤 4：PRD 类型${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1) 标准版（完整章节）"
echo "  2) 精简版（概述 + 功能 + 范围验收）"
echo ""

while true; do
    read -p "请选择 (1-2): " prd_type
    case $prd_type in
        1) PRD_TYPE="standard"; break;;
        2) PRD_TYPE="lean"; break;;
        *) echo -e "${RED}无效选项，请输入 1 或 2。${NC}";;
    esac
done

AUTHOR=$(whoami 2>/dev/null || echo "—")
TODAY=$(date +%Y/%m/%d 2>/dev/null || date +%Y-%m-%d)

echo ""
echo -e "${BLUE}正在生成 PRD...${NC}"
echo ""

if [ "$PRD_TYPE" = "lean" ]; then
cat > "$OUTPUT_FILE" << EOF
# ${PRODUCT_NAME}产品需求文档

文档修改记录

| 序号 | 版本号 | 修改时间 | 修改人 | 备注 |
| --- | --- | --- | --- | --- |
| 1 | V1.0 | ${TODAY} | ${AUTHOR} | 初版（精简） |

## 一、项目概述

### 1.1 项目背景

${PROBLEM}

### 1.2 项目目标

${BUSINESS_GOALS}

### 1.3 目标用户

| **用户角色** | **描述** | **核心诉求** |
| --- | --- | --- |
| ${PRIMARY_USERS} | [补充描述] | [补充诉求] |

## 三、功能需求详述

### 3.1 核心功能

${DESCRIPTION}

**验收标准：**

- [ ] [可测试条件 1]
- [ ] [可测试条件 2]

## 七、第一版功能范围

### 7.1 本期包含

- [功能点 1]
- [功能点 2]

### 7.2 本期不包含

${OUT_OF_SCOPE:-（待补充）}

### 7.3 验收标准（第一期）

${SUCCESS_METRICS}

**目标上线：** ${TIMELINE:-待定}

EOF
else
cat > "$OUTPUT_FILE" << EOF
# ${PRODUCT_NAME}产品需求文档

文档修改记录

| 序号 | 版本号 | 修改时间 | 修改人 | 备注 |
| --- | --- | --- | --- | --- |
| 1 | V1.0 | ${TODAY} | ${AUTHOR} | 初版 |

## 一、项目概述

### 1.1 项目背景

${PROBLEM}

### 1.2 项目目标

${BUSINESS_GOALS}

### 1.3 目标用户

| **用户角色** | **描述** | **核心诉求** |
| --- | --- | --- |
| ${PRIMARY_USERS} | [补充描述] | [补充诉求] |

### 1.4 成功指标

${SUCCESS_METRICS}

## 二、系统总体架构

### 2.1 架构图

\`\`\`plaintext
[在此补充系统组件与数据流向]
\`\`\`

### 2.2 技术栈

| **层级** | **技术选型** | **说明** |
| --- | --- | --- |
| [层级] | [技术] | [说明] |

### 2.3 核心业务流程

[描述或补充 mermaid 流程图]

## 三、功能需求详述

### 3.1 [模块名称]

${DESCRIPTION}

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| [field] | [type] | 是/否 | [说明] |

**业务规则：**

- [规则 1]

**验收标准（模块级，可选）：**

- [ ] [条件 1]

## 四、接口设计（概要）

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| [METHOD] | [/api/...] | [说明] |

## 五、数据模型设计（概要）

### 5.1 [实体名称]

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | string | 主键 |

## 六、不在此范围的功能（由业务系统自行实现或后续版本）

${OUT_OF_SCOPE:-（待补充）}

## 七、第一版功能范围

### 7.1 本期包含

| 编号 | 功能点 | 说明 |
| --- | --- | --- |
| F-001 | [功能] | [说明] |

### 7.2 本期不包含

| 编号 | 功能点 | 原因 |
| --- | --- | --- |
| O-001 | [功能] | [原因/后续版本] |

### 7.3 验收标准（第一期）

- [ ] [端到端交付标准 1]
- [ ] [交付标准 2]

**目标上线：** ${TIMELINE:-待定}

## 八、附录

### 8.1 开放问题

| 编号 | 问题 | 负责人 | 期望结论时间 |
| --- | --- | --- | --- |
| Q-001 | [待决策项] | [姓名] | [日期] |

### 8.2 风险与应对

| 风险 | 影响 | 概率 | 应对策略 |
| --- | --- | --- | --- |
| [风险] | 高/中/低 | 高/中/低 | [措施] |

EOF
fi

echo -e "${GREEN}✓ PRD 已生成${NC}"
echo ""
echo -e "输出文件: ${BLUE}$OUTPUT_FILE${NC}"
echo ""
echo -e "${YELLOW}后续步骤:${NC}"
echo "  1. 对照 references/prd_template.md 补全各章节"
echo "  2. 补充字段表、接口与数据模型"
echo "  3. 完善「七、验收标准」"
echo "  4. 运行校验: scripts/validate_prd.sh $OUTPUT_FILE"
echo ""
echo -e "${GREEN}完成${NC}"
