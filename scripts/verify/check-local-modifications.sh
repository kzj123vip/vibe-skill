#!/usr/bin/env bash
# 升级前检查脚本：检测配置文件本地修改，避免升级冲突

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "========================================"
echo "Vibe 升级前配置检查"
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

cd "$REPO_ROOT"

echo "检查 1: Git 仓库状态"
echo "----------------------------------------"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "不是 Git 仓库，无法检查配置状态"
    exit 1
fi
success "Git 仓库正常"

echo ""
echo "检查 2: 配置文件本地修改"
echo "----------------------------------------"

MODIFIED=$(git status --porcelain config/ | grep "^ M" || true)
UNTRACKED=$(git status --porcelain config/ | grep "^??" || true)
DELETED=$(git status --porcelain config/ | grep "^ D" || true)

HAS_CHANGES=0

if [ -n "$MODIFIED" ]; then
    warning "检测到已修改的配置文件："
    echo "$MODIFIED" | while read line; do
        echo "  - ${line:3}"
    done
    HAS_CHANGES=1
    echo ""
fi

if [ -n "$UNTRACKED" ]; then
    warning "检测到未跟踪的配置文件："
    echo "$UNTRACKED" | while read line; do
        echo "  - ${line:3}"
    done
    HAS_CHANGES=1
    echo ""
fi

if [ -n "$DELETED" ]; then
    warning "检测到已删除的配置文件："
    echo "$DELETED" | while read line; do
        echo "  - ${line:3}"
    done
    HAS_CHANGES=1
    echo ""
fi

if [ $HAS_CHANGES -eq 0 ]; then
    success "配置文件无本地修改，可以安全升级"
else
    echo "========================================"
    error "升级前请处理配置文件变更"
    echo "========================================"
    echo ""
    echo "建议操作："
    echo ""
    echo "方案 1: 暂存本地修改（推荐）"
    echo "  git stash push -m 'backup config before upgrade' config/"
    echo "  git pull"
    echo "  git stash pop  # 升级后恢复本地修改（可能需要手动合并）"
    echo ""
    echo "方案 2: 放弃本地修改"
    echo "  git restore config/  # 恢复所有修改"
    echo "  git clean -fd config/  # 删除未跟踪文件"
    echo "  git pull"
    echo ""
    echo "方案 3: 提交本地修改（如果是有价值的改进）"
    echo "  git add config/"
    echo "  git commit -m 'feat: 配置优化'"
    echo "  git pull --rebase"
    echo ""
    exit 1
fi

echo ""
echo "检查 3: 远程更新检查"
echo "----------------------------------------"

git fetch origin > /dev/null 2>&1 || true

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null || echo "")

if [ -z "$REMOTE" ]; then
    warning "无法获取远程分支信息（可能离线）"
elif [ "$LOCAL" = "$REMOTE" ]; then
    success "已是最新版本"
else
    BEHIND=$(git rev-list HEAD..origin/main --count 2>/dev/null || git rev-list HEAD..origin/master --count 2>/dev/null || echo "0")
    if [ "$BEHIND" -gt 0 ]; then
        warning "远程有 $BEHIND 个新提交可更新"
        echo ""
        echo "执行以下命令更新："
        echo "  git pull"
    fi
fi

echo ""
echo "检查 4: 配置完整性验证"
echo "----------------------------------------"

MANIFEST="config/runtime-config-manifest.json"

if [ ! -f "$MANIFEST" ]; then
    error "配置清单文件缺失: $MANIFEST"
    exit 1
fi
success "配置清单文件存在"

# 检查清单中列出的关键配置文件
CRITICAL_FILES=(
    "config/router-thresholds.json"
    "config/router-provider-defaults.json"
    "config/skill-routing-rules.json"
    "config/runtime-modes.json"
    "config/powershell-host-policy.json"
)

MISSING_COUNT=0
for file in "${CRITICAL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        error "关键配置文件缺失: $file"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done

if [ $MISSING_COUNT -eq 0 ]; then
    success "所有关键配置文件完整"
else
    error "缺失 $MISSING_COUNT 个关键配置文件"
    exit 1
fi

echo ""
echo "========================================"
if [ $HAS_CHANGES -eq 0 ]; then
    echo -e "${GREEN}✅ 升级前检查通过！${NC}"
    echo "========================================"
    echo ""
    echo "执行以下命令更新 Vibe："
    echo "  git pull"
    echo "  ./check.sh  # 验证安装"
else
    echo -e "${RED}⚠️  升级前检查未通过${NC}"
    echo "========================================"
    echo ""
    echo "请先处理配置文件变更（见上方建议）"
fi
echo ""
