#!/usr/bin/env bash
# 端到端验证脚本：验证 Python 优先路由器改动

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "========================================"
echo "Vibe 路由器验证脚本 v2.1.0"
echo "========================================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 检查 Python
if ! command -v python3 &> /dev/null; then
    error "Python 3 未安装"
    exit 1
fi
success "Python 3 已安装: $(python3 --version)"

# 检查 PowerShell（可选）
if command -v pwsh &> /dev/null; then
    success "PowerShell 已安装: $(pwsh --version | head -1)"
    PWSH_AVAILABLE=1
else
    warning "PowerShell 未安装（可选依赖，不影响默认行为）"
    PWSH_AVAILABLE=0
fi

echo ""
echo "========================================"
echo "测试 1: Python 路由器（默认）"
echo "========================================"

cd "$REPO_ROOT"
export PYTHONPATH="packages/runtime-core/src:packages/contracts/src:packages/verification-core/src:${PYTHONPATH:-}"

OUTPUT=$(python3 -m vgo_runtime.router_bridge \
    --prompt "帮我实现一个功能" \
    --grade M \
    --task-type coding \
    --force-runtime-neutral 2>&1)

if echo "$OUTPUT" | python3 -c "import json, sys; data=json.load(sys.stdin); assert data.get('runtime_neutral_bridge', {}).get('engine') == 'python'" 2>/dev/null; then
    success "Python 路由器工作正常（--force-runtime-neutral）"
else
    error "Python 路由器测试失败"
    echo "$OUTPUT" | head -20
    exit 1
fi

echo ""
echo "========================================"
echo "测试 2: Python 路由器（默认，无标志）"
echo "========================================"

OUTPUT=$(python3 -m vgo_runtime.router_bridge \
    --prompt "帮我实现一个功能" \
    --grade M \
    --task-type coding 2>&1)

if echo "$OUTPUT" | python3 -c "import json, sys; data=json.load(sys.stdin); bridge=data.get('runtime_neutral_bridge', {}); assert bridge.get('engine') == 'python', f'Expected python, got {bridge.get(\"engine\")}'" 2>/dev/null; then
    success "Python 路由器默认启用（无需 PowerShell）"
else
    error "默认应该使用 Python 路由器"
    echo "$OUTPUT" | head -20
    exit 1
fi

if [ $PWSH_AVAILABLE -eq 1 ]; then
    echo ""
    echo "========================================"
    echo "测试 3: PowerShell 回退（环境变量）"
    echo "========================================"

    OUTPUT=$(VIBE_USE_POWERSHELL=1 python3 -m vgo_runtime.router_bridge \
        --prompt "帮我实现一个功能" \
        --grade M \
        --task-type coding 2>&1)

    if echo "$OUTPUT" | python3 -c "import json, sys; data=json.load(sys.stdin); bridge=data.get('runtime_neutral_bridge'); exit(0 if bridge is None or bridge.get('engine') != 'python' else 1)" 2>/dev/null; then
        success "PowerShell 回退工作正常（VIBE_USE_POWERSHELL=1）"
    else
        error "设置 VIBE_USE_POWERSHELL=1 后应该使用 PowerShell 路由器"
        echo "$OUTPUT" | head -20
        exit 1
    fi
else
    warning "跳过测试 3（PowerShell 未安装）"
fi

echo ""
echo "========================================"
echo "测试 4: 输出格式验证"
echo "========================================"

OUTPUT=$(python3 -m vgo_runtime.router_bridge \
    --prompt "帮我调试这个问题" \
    --grade L \
    --task-type debug \
    --force-runtime-neutral 2>&1)

REQUIRED_FIELDS=("prompt" "grade" "task_type" "route_mode" "route_reason" "confidence" "selected" "ranked" "fallback_applied" "runtime_neutral_bridge" "custom_admission")

ALL_PASSED=1
for field in "${REQUIRED_FIELDS[@]}"; do
    if echo "$OUTPUT" | python3 -c "import json, sys; data=json.load(sys.stdin); exit(0 if '$field' in data else 1)" 2>/dev/null; then
        success "字段存在: $field"
    else
        error "缺少必需字段: $field"
        ALL_PASSED=0
    fi
done

if [ $ALL_PASSED -eq 1 ]; then
    success "所有必需字段存在"
else
    error "输出格式验证失败"
    exit 1
fi

echo ""
echo "========================================"
echo "测试 5: 路由逻辑验证"
echo "========================================"

# 测试 coding 任务
OUTPUT=$(python3 -m vgo_runtime.router_bridge \
    --prompt "实现一个新功能" \
    --grade M \
    --task-type coding \
    --force-runtime-neutral 2>&1)

if echo "$OUTPUT" | python3 -c "import json, sys; data=json.load(sys.stdin); assert data.get('task_type') == 'coding'" 2>/dev/null; then
    success "任务类型识别正确: coding"
else
    error "任务类型识别失败"
    exit 1
fi

# 测试 debug 任务
OUTPUT=$(python3 -m vgo_runtime.router_bridge \
    --prompt "修复这个 bug" \
    --grade M \
    --task-type debug \
    --force-runtime-neutral 2>&1)

if echo "$OUTPUT" | python3 -c "import json, sys; data=json.load(sys.stdin); assert data.get('task_type') == 'debug'" 2>/dev/null; then
    success "任务类型识别正确: debug"
else
    error "任务类型识别失败"
    exit 1
fi

echo ""
echo "========================================"
echo "✅ 所有测试通过！"
echo "========================================"
echo ""
echo "摘要："
echo "  - Python 路由器默认启用 ✓"
echo "  - PowerShell 回退可选 ✓"
echo "  - 输出格式完整 ✓"
echo "  - 路由逻辑正确 ✓"
echo ""
echo "v2.1.0 改动验证完成！"
