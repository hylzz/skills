#!/bin/bash

# PRD 校验脚本（默认支持简体中文 PRD 结构）

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VERBOSE=false

usage() {
    echo "用法: $0 <prd_file.md> [选项]"
    echo ""
    echo "选项:"
    echo "  --verbose           显示详细建议"
    echo "  --lang en           按英文 PRD 结构校验"
    echo ""
    echo "示例:"
    echo "  $0 prd/功能.md"
    echo "  $0 prd/feature.md --lang en"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

PRD_FILE="$1"
shift
LANG_MODE="zh"

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --lang)
            LANG_MODE="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            usage
            ;;
    esac
done

if [ ! -f "$PRD_FILE" ]; then
    echo -e "${RED}✗ 文件不存在: $PRD_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        PRD 校验报告                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "文件: ${BLUE}$PRD_FILE${NC}"
echo -e "模式: ${BLUE}$LANG_MODE${NC}"
echo ""

ISSUES_FOUND=0
WARNINGS=0
CHECKS_PASSED=0

check_section() {
    local section_name="$1"
    local section_pattern="$2"
    local required="$3"

    if grep -qE "$section_pattern" "$PRD_FILE"; then
        echo -e "${GREEN}✓${NC} 已找到：$section_name"
        ((CHECKS_PASSED++))
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗${NC} 缺少（必填）：$section_name"
            ((ISSUES_FOUND++))
        else
            echo -e "${YELLOW}⚠${NC} 缺少（建议）：$section_name"
            ((WARNINGS++))
        fi
        return 1
    fi
}

check_content() {
    local check_name="$1"
    local pattern="$2"
    local error_msg="$3"

    if grep -qE "$pattern" "$PRD_FILE"; then
        echo -e "${YELLOW}⚠${NC} $check_name: $error_msg"
        ((WARNINGS++))
        return 1
    else
        echo -e "${GREEN}✓${NC} $check_name 通过"
        ((CHECKS_PASSED++))
        return 0
    fi
}

check_placeholders() {
    local placeholder_pattern='占位符|待补充|补充|描述|说明|目标|角色|功能|字段|规则|条件|名称|系统|类型|路径|用途|日期|姓名|模块|实体|示例|前置条件|操作|预期结果'

    if perl -ne 'BEGIN { $p = shift } if (/\[(?!\s?\])([^\]]*(?:$p)[^\]]*)\](?!\()/) { $found = 1 } END { exit($found ? 0 : 1) }' "$placeholder_pattern" "$PRD_FILE"; then
        echo -e "${YELLOW}⚠${NC} 占位符: 仍含方括号占位符，请替换为实际内容"
        ((WARNINGS++))
        return 1
    else
        echo -e "${GREEN}✓${NC} 占位符 通过"
        ((CHECKS_PASSED++))
        return 0
    fi
}

echo -e "${BLUE}━━━ 章节完整性 ━━━${NC}"
echo ""

if [ "$LANG_MODE" = "zh" ]; then
    check_section "一、项目概述" "##[[:space:]]*一、项目概述" true
    check_section "三、功能需求详述" "##[[:space:]]*三、功能需求" true
    check_section "七、第一版功能范围" "##[[:space:]]*七、第一版功能范围|##[[:space:]]*七、.*范围" true

    echo ""
    echo -e "${BLUE}━━━ 建议章节 ━━━${NC}"
    echo ""

    check_section "二、系统总体架构" "##[[:space:]]*二、系统总体架构" false
    check_section "四、接口设计" "##[[:space:]]*四、接口" false
    check_section "五、数据模型" "##[[:space:]]*五、数据模型" false
    check_section "六、不在此范围" "##[[:space:]]*六、不在|##[[:space:]]*六、.*范围" false
    check_section "八、附录" "##[[:space:]]*八、附录" false
    check_section "文档修改记录" "文档修改记录" false
else
    check_section "Problem Statement" "##.*Problem Statement" true
    check_section "Goals & Objectives" "##.*Goals.*Objectives" true
    check_section "User Stories" "##.*User Stories" true
    check_section "Success Metrics" "##.*Success Metrics" true
    check_section "Scope" "##.*Scope" true

    echo ""
    echo -e "${BLUE}━━━ Recommended Sections ━━━${NC}"
    echo ""

    check_section "Executive Summary" "##.*Executive Summary" false
    check_section "Technical Considerations" "##.*Technical Considerations" false
fi

echo ""
echo -e "${BLUE}━━━ 内容质量 ━━━${NC}"
echo ""

check_placeholders
check_content "TBD 标记" 'TBD|TODO|待补充|待确认' "含未完成标记"

echo ""
echo -e "${BLUE}━━━ 用户故事 / 验收标准 ━━━${NC}"
echo ""

if [ "$LANG_MODE" = "zh" ]; then
    ZH_STORY_COUNT=$(grep -cE '作为.+，[[:space:]]*我希望' "$PRD_FILE" 2>/dev/null || true)
    AC_COUNT=$(grep -cE '验收标准' "$PRD_FILE" 2>/dev/null || true)
    FUNC_SECTION=$(grep -cE '##[[:space:]]*三、功能需求' "$PRD_FILE" 2>/dev/null || true)

    if [ "$ZH_STORY_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} 发现 $ZH_STORY_COUNT 条中文用户故事"
        ((CHECKS_PASSED++))
    elif [ "$FUNC_SECTION" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} 以功能需求详述为主（B 端/平台类 PRD 可接受）"
        ((CHECKS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} 未发现中文用户故事，也未找到「三、功能需求」"
        ((WARNINGS++))
    fi

    if [ "$AC_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} 已定义验收标准（$AC_COUNT 处提及）"
        ((CHECKS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} 建议在「七、验收标准」中列出可测试交付条件"
        ((WARNINGS++))
    fi
else
    USER_STORY_COUNT=$(grep -c "As a.*I want.*So that" "$PRD_FILE" 2>/dev/null || true)
    if [ "$USER_STORY_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Found $USER_STORY_COUNT user stories"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} No user stories in English format"
        ((ISSUES_FOUND++))
    fi
fi

echo ""
echo -e "${BLUE}━━━ 指标与范围 ━━━${NC}"
echo ""

if grep -qiE '成功指标|指标|KPI|北极星|验收标准|目标值' "$PRD_FILE"; then
    echo -e "${GREEN}✓${NC} 已提及成功指标或验收相关描述"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} 建议补充可量化的成功指标或验收标准"
    ((WARNINGS++))
fi

if grep -qiE '不在此范围|本期不包含|不在范围' "$PRD_FILE"; then
    echo -e "${GREEN}✓${NC} 已定义范围外内容"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} 建议明确「不在本期范围」的内容"
    ((WARNINGS++))
fi

echo ""
echo -e "${BLUE}━━━ 文档体量 ━━━${NC}"
echo ""

WORD_COUNT=$(wc -w < "$PRD_FILE" 2>/dev/null || echo 0)
CHAR_HINT=$(wc -m < "$PRD_FILE" 2>/dev/null || echo 0)
echo -e "约 $WORD_COUNT 词 / $CHAR_HINT 字符"

if [ "$CHAR_HINT" -lt 800 ]; then
    echo -e "${YELLOW}⚠${NC} 文档偏短，复杂 PRD 建议补充更多细节"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} 文档长度合理"
    ((CHECKS_PASSED++))
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              校验摘要                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "通过: ${GREEN}$CHECKS_PASSED${NC}  警告: ${YELLOW}$WARNINGS${NC}  问题: ${RED}$ISSUES_FOUND${NC}"
echo ""

if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}━━━ 建议 ━━━${NC}"
    echo "1. 全文使用简体中文（专有名词除外）"
    echo "2. 填写文档修改记录表"
    echo "3. 功能需求用表格描述字段与规则"
    echo "4. 在「七、验收标准」列出第一期可验证条目"
    echo "5. 用「六、不在此范围」防止范围蔓延"
    echo ""
fi

if [ "$ISSUES_FOUND" -gt 0 ]; then
    echo -e "${RED}❌ PRD 校验未通过${NC}"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠ PRD 校验通过（有警告）${NC}"
    exit 0
else
    echo -e "${GREEN}✅ PRD 校验通过${NC}"
    exit 0
fi
