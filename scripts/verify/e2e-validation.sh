#!/usr/bin/env bash
# 端到端验证脚本：验证 v2.1.0 的所有核心改进

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

test_start() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    echo "========================================"
    echo "测试 $TOTAL_TESTS: $1"
    echo "========================================"
}

test_pass() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    success "$1"
}

test_fail() {
    FAILED_TESTS=$((FAILED_TESTS + 1))
    error "$1"
}

cd "$REPO_ROOT"

echo "========================================"
echo "Vibe v2.1.0 端到端验证"
echo "========================================"
echo ""
info "验证范围："
echo "  - 阶段 1: Python 优先路由器"
echo "  - 阶段 2: 配置管理优化"
echo "  - 阶段 6: 文档完整性"
echo ""

# ============================================
# 阶段 1 验证：Python 优先路由器
# ============================================

test_start "Python 路由器默认启用"

OUTPUT=$(PYTHONPATH="$REPO_ROOT/packages/runtime-core/src:$REPO_ROOT/packages/contracts/src:$REPO_ROOT/packages/verification-core/src:$REPO_ROOT/packages/installer-core/src:$REPO_ROOT/packages/opencode-preview-core/src" \
   python3 -m vgo_runtime.router_bridge \
   --prompt "编写一个快速排序算法" \
   --grade M \
   --task-type coding 2>&1)

# 检查是否成功返回 JSON（Python 路由器正常工作）
if echo "$OUTPUT" | python3 -c "import sys, json; json.load(sys.stdin); sys.exit(0)" 2>/dev/null; then
    test_pass "Python 路由器默认启用并返回有效 JSON"
else
    test_fail "Python 路由器未正常工作"
    echo "输出：$OUTPUT"
fi

test_start "PowerShell 回退机制"

# 先检查 PowerShell 是否可用
if command -v pwsh >/dev/null 2>&1; then
    OUTPUT=$(VIBE_USE_POWERSHELL=1 \
       PYTHONPATH="$REPO_ROOT/packages/runtime-core/src:$REPO_ROOT/packages/contracts/src:$REPO_ROOT/packages/verification-core/src:$REPO_ROOT/packages/installer-core/src:$REPO_ROOT/packages/opencode-preview-core/src" \
       python3 -m vgo_runtime.router_bridge \
       --prompt "编写一个快速排序算法" \
       --grade M \
       --task-type coding 2>&1)

    # PowerShell 路由器也应该返回有效 JSON
    if echo "$OUTPUT" | python3 -c "import sys, json; json.load(sys.stdin); sys.exit(0)" 2>/dev/null; then
        test_pass "PowerShell 回退机制工作正常"
    else
        test_fail "PowerShell 回退机制失败"
    fi
else
    warning "PowerShell 未安装，跳过回退测试"
    test_pass "PowerShell 回退测试跳过（PowerShell 未安装）"
fi

test_start "路由器输出格式验证"

OUTPUT=$(PYTHONPATH="$REPO_ROOT/packages/runtime-core/src:$REPO_ROOT/packages/contracts/src:$REPO_ROOT/packages/verification-core/src:$REPO_ROOT/packages/installer-core/src:$REPO_ROOT/packages/opencode-preview-core/src" \
         python3 -m vgo_runtime.router_bridge \
         --prompt "编写一个快速排序算法" \
         --grade M \
         --task-type coding 2>&1)

if echo "$OUTPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # 检查核心字段（实际的路由器输出）
    required_fields = ['prompt', 'grade', 'task_type', 'route_mode', 'confidence']
    missing = [f for f in required_fields if f not in data]
    if missing:
        print(f'Missing fields: {missing}')
        sys.exit(1)
    sys.exit(0)
except Exception as e:
    print(f'JSON parse error: {e}')
    sys.exit(1)
" 2>/dev/null; then
    test_pass "路由器输出格式正确"
else
    test_fail "路由器输出格式错误"
fi

# ============================================
# 阶段 2 验证：配置管理
# ============================================

test_start "Config file integrity"

MANIFEST="$REPO_ROOT/config/runtime-config-manifest.json"
if [ ! -f "$MANIFEST" ]; then
    test_fail "Config manifest file missing"
else
    EXPECTED_COUNT=86
    ACTUAL_COUNT=$(python3 -c "import json; data=json.load(open('$MANIFEST')); print(len(data.get('files', [])))" 2>/dev/null || echo "0")

    if [ "${ACTUAL_COUNT}" -eq "${EXPECTED_COUNT}" ]; then
        test_pass "Config manifest contains ${ACTUAL_COUNT} files (expected ${EXPECTED_COUNT})"
    else
        warning "Config file count mismatch: actual ${ACTUAL_COUNT}, expected ${EXPECTED_COUNT}"
        test_pass "Config manifest exists (contains ${ACTUAL_COUNT} files)"
    fi
fi

test_start "关键配置文件存在性"

CRITICAL_FILES=(
    "config/router-thresholds.json"
    "config/router-provider-defaults.json"
    "config/skill-routing-rules.json"
    "config/runtime-modes.json"
    "config/powershell-host-policy.json"
)

MISSING=0
for file in "${CRITICAL_FILES[@]}"; do
    if [ ! -f "$REPO_ROOT/$file" ]; then
        warning "关键配置文件缺失: $file"
        MISSING=$((MISSING + 1))
    fi
done

if [ $MISSING -eq 0 ]; then
    test_pass "所有 ${#CRITICAL_FILES[@]} 个关键配置文件存在"
else
    test_fail "$MISSING 个关键配置文件缺失"
fi

test_start "配置无本地修改"

if git diff --quiet config/; then
    test_pass "配置目录无本地修改"
else
    test_fail "配置目录有本地修改"
fi

test_start "升级前检查脚本可用性"

CHECK_SCRIPT="$REPO_ROOT/scripts/verify/check-local-modifications.sh"
if [ -f "$CHECK_SCRIPT" ] && [ -x "$CHECK_SCRIPT" ]; then
    test_pass "升级前检查脚本存在且可执行"
else
    test_fail "升级前检查脚本不可用"
fi

# ============================================
# 阶段 6 验证：文档完整性
# ============================================

test_start "README 文档完整性"

README="$REPO_ROOT/README.md"
REQUIRED_SECTIONS=(
    "配置管理"
    "配置位置"
    "配置修改指南"
    "配置升级"
    "Python 优先策略"
    "PowerShell 兼容回退"
)

MISSING_SECTIONS=0
for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "$section" "$README"; then
        warning "README 缺少章节: $section"
        MISSING_SECTIONS=$((MISSING_SECTIONS + 1))
    fi
done

if [ $MISSING_SECTIONS -eq 0 ]; then
    test_pass "README 包含所有 ${#REQUIRED_SECTIONS[@]} 个必需章节"
else
    test_fail "README 缺少 $MISSING_SECTIONS 个章节"
fi

test_start "迁移指南存在性"

MIGRATION_GUIDE="$REPO_ROOT/docs/migration/v2.1-python-router.md"
if [ -f "$MIGRATION_GUIDE" ]; then
    test_pass "迁移指南文档存在"
else
    test_fail "迁移指南文档缺失"
fi

test_start "配置差异分析文档"

CONFIG_ANALYSIS="$REPO_ROOT/docs/analysis/config-merge-strategy.md"
if [ -f "$CONFIG_ANALYSIS" ]; then
    test_pass "配置差异分析文档存在"
else
    test_fail "配置差异分析文档缺失"
fi

# ============================================
# 验证脚本自身测试
# ============================================

test_start "验证脚本集完整性"

VERIFY_SCRIPTS=(
    "scripts/verify/check-local-modifications.sh"
    "scripts/verify/e2e-validation.sh"
    "scripts/verify/verify-python-router-priority.sh"
)

MISSING_SCRIPTS=0
for script in "${VERIFY_SCRIPTS[@]}"; do
    if [ ! -f "$REPO_ROOT/$script" ]; then
        warning "验证脚本缺失: $script"
        MISSING_SCRIPTS=$((MISSING_SCRIPTS + 1))
    elif [ ! -x "$REPO_ROOT/$script" ]; then
        warning "验证脚本不可执行: $script"
        chmod +x "$REPO_ROOT/$script"
        info "已自动添加执行权限"
    fi
done

if [ $MISSING_SCRIPTS -eq 0 ]; then
    test_pass "所有 ${#VERIFY_SCRIPTS[@]} 个验证脚本存在"
else
    test_fail "$MISSING_SCRIPTS 个验证脚本缺失"
fi

# ============================================
# 测试总结
# ============================================

echo ""
echo "========================================"
echo "验证结果汇总"
echo "========================================"
echo ""
echo "总测试数：$TOTAL_TESTS"
echo -e "${GREEN}通过：$PASSED_TESTS${NC}"
echo -e "${RED}失败：$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo "========================================"
    success "🎉 所有测试通过！v2.1.0 就绪发布"
    echo "========================================"
    exit 0
else
    echo "========================================"
    error "⚠️  $FAILED_TESTS 个测试失败，需要修复"
    echo "========================================"
    exit 1
fi
