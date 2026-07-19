# Vibe Skill 全面优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 全面优化 vibe-skill 项目，消除 macOS 上的 PowerShell 依赖，统一配置管理，增强测试覆盖，完善文档和 CI/CD，提升项目质量和可维护性。

**Architecture:** 采用渐进式重构策略，优先修复关键路径问题（PowerShell 路由器依赖、配置分离），再增强质量保障机制（测试、CI/CD），最后完善生态建设（文档、依赖管理）。每个任务独立可验证，支持增量发布。

**Tech Stack:** 
- 核心运行时：Python 3.13+
- 路由器：Python（替代 PowerShell 1910 行）
- 配置管理：JSON Schema + 统一配置加载器
- 测试框架：pytest
- CI/CD：GitHub Actions
- 文档：Markdown + MkDocs

---

## 审查发现总结

### 🔴 高优先级问题（P0）

1. **PowerShell 路由器依赖未完全消除**
   - 现状：`router_bridge.py` 仍优先调用 `resolve-pack-route.ps1`（1910 行 PowerShell）
   - 影响：macOS 用户必须安装 pwsh，违背"macOS 优先"目标
   - 证据：`router_bridge.py:75` - `shell = None if args.force_runtime_neutral else resolve_powershell_host()`

2. **配置分离导致不一致**
   - 现状：仓库内配置（`config/*.json`）与 Codex 全局配置（`~/.codex/config/custom-skills.json`）分离
   - 影响：修改仓库配置不影响实际路由行为，用户困惑
   - 证据：
     - 仓库 `skill-routing-rules.json`: 128KB (最后修改 Jun 7)
     - Codex `custom-skills.json`: 138KB (最后修改 Jul 19)

### 🟡 中优先级问题（P1）

3. **测试覆盖不足**
   - 现状：只有 3 个测试文件，无 pytest 配置，无 CI
   - 影响：路由一致性修复无法自动回归验证
   - 证据：找到测试文件但无测试框架配置

4. **文档碎片化**
   - 现状：79 个 governance 文档，缺少统一索引和入门指南
   - 影响：新用户难以快速上手，维护者难以找到相关文档

### 🟢 低优先级问题（P2）

5. **缺少依赖管理**
   - 现状：无 `requirements.txt` 或 `pyproject.toml`
   - 影响：用户不知道需要安装哪些依赖

6. **缺少 GitHub Actions**
   - 现状：无 `.github/workflows/`
   - 影响：无法自动验证 PR，质量保障依赖人工

---

## 优化任务分解

### 阶段 1：消除 PowerShell 路由器依赖（P0，预计 4 小时）

#### 目标
将 `resolve-pack-route.ps1`（1910 行）的核心逻辑迁移到 Python，使 macOS 用户无需安装 pwsh。

#### 策略
- 保留 PowerShell 路由器作为 Windows 兼容回退路径
- Python 路由器成为默认，仅在 `--force-legacy-powershell` 时回退
- 复用现有 `router.py` 和 `router_contract_*.py` 模块

---

## Task 1: 分析 PowerShell 路由器逻辑并提取核心算法

**Files:**
- Read: `scripts/router/resolve-pack-route.ps1`
- Create: `docs/analysis/powershell-router-logic-map.md`

- [ ] **Step 1: 提取 PowerShell 路由器的核心函数列表**

```bash
cd ~/.cc-switch/skills/vibe
grep -n "^function " scripts/router/resolve-pack-route.ps1 > /tmp/ps-functions.txt
cat /tmp/ps-functions.txt
```

预期：找到 20-30 个函数定义

- [ ] **Step 2: 识别主流程入口**

```bash
grep -n "param\|Main\|Entry" scripts/router/resolve-pack-route.ps1 | head -20
```

预期：找到参数定义和主入口函数

- [ ] **Step 3: 映射到现有 Python 模块**

创建映射文档：

```markdown
# PowerShell → Python 路由器逻辑映射

## 核心流程
1. 参数解析 → `router_bridge.py:parse_args()`
2. 技能加载 → `router_contract_authority.py`
3. 关键词匹配 → `router_contract_selection.py`
4. 优先级排序 → `router_contract_selection.py`
5. 结果序列化 → `router_contract_presentation.py`

## 待迁移逻辑
- [ ] Custom admission 检查
- [ ] Degradation 降级逻辑
- [ ] Route snapshot 生成
```

- [ ] **Step 4: 保存分析文档**

```bash
# 文档已在 Step 3 中创建
cat docs/analysis/powershell-router-logic-map.md
```

预期：清晰的迁移路线图

- [ ] **Step 5: Commit 分析结果**

```bash
git add docs/analysis/powershell-router-logic-map.md
git commit -m "docs: 添加 PowerShell 路由器逻辑映射分析"
```

---

## Task 2: 增强 Python 路由器以替代 PowerShell

**Files:**
- Modify: `packages/runtime-core/src/vgo_runtime/router_bridge.py:75-85`
- Modify: `packages/runtime-core/src/vgo_runtime/router_contract_runtime.py`
- Test: `packages/runtime-core/src/vgo_runtime/test_router_bridge.py`

- [ ] **Step 1: 编写失败测试 - 默认使用 Python 路由器**

```python
# test_router_bridge.py
def test_default_router_is_python_not_powershell():
    """默认应使用 Python 路由器，不依赖 pwsh"""
    args = parse_args(['--prompt', 'test', '--grade', 'M', '--task-type', 'planning'])
    # Mock resolve_powershell_host 返回路径
    with patch('vgo_runtime.router_bridge.resolve_powershell_host', return_value='/usr/bin/pwsh'):
        with patch('vgo_runtime.router_bridge.route_prompt') as mock_route:
            main(['--prompt', 'test'])
            # 应调用 Python 路由器而非 PowerShell
            mock_route.assert_called_once()
```

- [ ] **Step 2: 运行测试验证失败**

```bash
cd ~/.cc-switch/skills/vibe
python -m pytest packages/runtime-core/src/vgo_runtime/test_router_bridge.py::test_default_router_is_python_not_powershell -v
```

预期：FAIL - 当前逻辑优先使用 PowerShell

- [ ] **Step 3: 修改 router_bridge.py 逻辑**

```python
# router_bridge.py:75-85 修改为
def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    
    # 默认使用 Python 路由器
    use_python_router = True
    
    # 仅在显式要求时使用 PowerShell（Windows 兼容回退）
    if hasattr(args, 'force_legacy_powershell') and args.force_legacy_powershell:
        shell = resolve_powershell_host()
        if shell:
            payload = invoke_canonical_router(args, shell)
            use_python_router = False
    
    if use_python_router:
        payload = route_prompt(
            prompt=args.prompt,
            grade=args.grade,
            task_type=args.task_type,
            requested_skill=args.requested_skill,
            entry_intent_id=args.entry_intent_id,
            requested_grade_floor=args.requested_grade_floor,
            host_id=args.host_id,
            target_root=Path(args.target_root) if args.target_root else None,
        )
    
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0
```

- [ ] **Step 4: 运行测试验证通过**

```bash
python -m pytest packages/runtime-core/src/vgo_runtime/test_router_bridge.py::test_default_router_is_python_not_powershell -v
```

预期：PASS

- [ ] **Step 5: Commit 修改**

```bash
git add packages/runtime-core/src/vgo_runtime/router_bridge.py packages/runtime-core/src/vgo_runtime/test_router_bridge.py
git commit -m "feat: 默认使用 Python 路由器，PowerShell 仅作兼容回退"
```

---

## Task 3: 更新入口脚本和文档

**Files:**
- Modify: `check.sh:86-95`
- Modify: `README.md`
- Modify: `docs/one-shot-setup.md`

- [ ] **Step 1: 修改 check.sh 优先使用 Python**

```bash
# check.sh:86-95 修改为
run_vibe_router() {
  # 优先使用 Python 路由器
  if command -v python3 &>/dev/null; then
    python3 "${REPO_ROOT}/scripts/router/invoke-pack-route.py" "$@"
  elif command -v pwsh &>/dev/null || command -v powershell &>/dev/null; then
    echo "警告: Python3 不可用，回退到 PowerShell 路由器" >&2
    handoff_to_windows_powershell_frontend
  else
    echo "错误: 需要 Python3 或 PowerShell 来运行路由器" >&2
    return 1
  fi
}
```

- [ ] **Step 2: 验证 check.sh 语法**

```bash
bash -n check.sh
```

预期：无语法错误

- [ ] **Step 3: 更新 README.md**

```markdown
## 系统要求

- **必需**：Python 3.10+
- **可选**：PowerShell 7+ (pwsh) - 仅 Windows 兼容回退需要
- **操作系统**：macOS, Linux, Windows

## macOS 快速开始

```bash
# 无需安装 PowerShell，直接使用 Python
cd ~/.cc-switch/skills/vibe
python3 scripts/router/invoke-pack-route.py --prompt "帮我制定计划" --grade M --task-type planning
```
```

- [ ] **Step 4: 更新 one-shot-setup.md**

移除 "macOS 需要 pwsh" 的说明，改为：

```markdown
## 运行时要求

- macOS / Linux: Python 3.10+ (自带)
- Windows: Python 3.10+ 或 PowerShell 7+
```

- [ ] **Step 5: Commit 文档更新**

```bash
git add check.sh README.md docs/one-shot-setup.md
git commit -m "docs: 更新系统要求，macOS 不再需要 PowerShell"
```

---

### 阶段 2：统一配置管理（P0，预计 3 小时）

#### 目标
将 Codex 全局配置（`~/.codex/config/custom-skills.json`）的关键配置合并到仓库内，建立单一配置源。

#### 策略
- 仓库配置为权威来源
- 安装时自动同步到 Codex 配置目录
- 提供配置校验和同步工具

---

## Task 4: 分析配置差异并制定合并策略

**Files:**
- Read: `config/skill-routing-rules.json`
- Read: `~/.codex/config/custom-skills.json`
- Create: `docs/analysis/config-diff-report.md`

- [ ] **Step 1: 导出两个配置的技能列表**

```bash
cd ~/.cc-switch/skills/vibe
# 仓库配置
jq -r '.skills[].skill_id' config/skill-routing-rules.json | sort > /tmp/repo-skills.txt
# Codex 配置
jq -r '.skills[].skill_id' ~/.codex/config/custom-skills.json | sort > /tmp/codex-skills.txt
```

- [ ] **Step 2: 对比差异**

```bash
echo "=== 仅在仓库中 ==="
comm -23 /tmp/repo-skills.txt /tmp/codex-skills.txt
echo "=== 仅在 Codex 中 ==="
comm -13 /tmp/repo-skills.txt /tmp/codex-skills.txt
echo "=== 共同存在 ==="
comm -12 /tmp/repo-skills.txt /tmp/codex-skills.txt | wc -l
```

- [ ] **Step 3: 识别优先级差异**

```bash
# 检查 superpowers-writing-plans 的优先级
echo "仓库配置优先级:"
jq '.skills[] | select(.skill_id == "superpowers-writing-plans") | .priority' config/skill-routing-rules.json
echo "Codex 配置优先级:"
jq '.skills[] | select(.skill_id == "superpowers-writing-plans") | .priority' ~/.codex/config/custom-skills.json
```

- [ ] **Step 4: 创建差异报告**

```markdown
# 配置差异分析报告

## 技能数量
- 仓库配置：X 个技能
- Codex 配置：Y 个技能
- 共同：Z 个

## 关键差异
1. superpowers-writing-plans: 仓库 89 vs Codex 92 ✓ (Codex 更新)
2. superpowers-brainstorming: 仓库 89 vs Codex 90 ✓ (Codex 更新)

## 合并策略
- 以 Codex 配置为准（包含最新优化）
- 回写到仓库 `config/skill-routing-rules.json`
- 建立同步机制
```

- [ ] **Step 5: Commit 分析报告**

```bash
git add docs/analysis/config-diff-report.md
git commit -m "docs: 添加配置差异分析报告"
```

---

## Task 5: 同步 Codex 配置到仓库

**Files:**
- Modify: `config/skill-routing-rules.json`
- Create: `scripts/sync-config.py`

- [ ] **Step 1: 备份当前仓库配置**

```bash
cd ~/.cc-switch/skills/vibe
cp config/skill-routing-rules.json config/skill-routing-rules.json.bak-$(date +%Y%m%d)
```

- [ ] **Step 2: 合并配置（保留 Codex 的最新优化）**

```bash
# 复制 Codex 配置作为基础
cp ~/.codex/config/custom-skills.json config/skill-routing-rules.json
```

- [ ] **Step 3: 验证 JSON 格式**

```bash
jq empty config/skill-routing-rules.json && echo "✓ JSON 格式有效"
```

预期：JSON 格式有效

- [ ] **Step 4: 创建配置同步脚本**

```python
#!/usr/bin/env python3
"""同步仓库配置到 Codex 配置目录"""
import json
import shutil
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
REPO_CONFIG = REPO_ROOT / 'config' / 'skill-routing-rules.json'
CODEX_CONFIG = Path.home() / '.codex' / 'config' / 'custom-skills.json'

def sync_config():
    if not REPO_CONFIG.exists():
        print(f"错误: 仓库配置不存在 {REPO_CONFIG}")
        return 1
    
    # 备份 Codex 配置
    if CODEX_CONFIG.exists():
        backup = CODEX_CONFIG.with_suffix('.json.bak')
        shutil.copy(CODEX_CONFIG, backup)
        print(f"✓ 已备份 Codex 配置到 {backup}")
    
    # 同步
    CODEX_CONFIG.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(REPO_CONFIG, CODEX_CONFIG)
    print(f"✓ 已同步 {REPO_CONFIG} → {CODEX_CONFIG}")
    
    # 验证
    with open(CODEX_CONFIG) as f:
        data = json.load(f)
        print(f"✓ 配置有效，包含 {len(data.get('skills', []))} 个技能")
    
    return 0

if __name__ == '__main__':
    exit(sync_config())
```

- [ ] **Step 5: 测试同步脚本**

```bash
python3 scripts/sync-config.py
```

预期：成功同步并验证

- [ ] **Step 6: Commit 配置更新**

```bash
git add config/skill-routing-rules.json scripts/sync-config.py
git commit -m "feat: 同步最新路由配置，新增配置同步脚本"
```

---

## Task 6: 在 README 中说明配置管理方式

**Files:**
- Modify: `README.md`
- Create: `docs/configuration-guide.md`

- [ ] **Step 1: 在 README 添加配置说明**

```markdown
## 配置管理

路由配置统一存储在 `config/skill-routing-rules.json`，这是唯一权威配置源。

### 修改配置后同步

```bash
# 1. 修改仓库配置
vim config/skill-routing-rules.json

# 2. 同步到 Codex（使配置生效）
python3 scripts/sync-config.py

# 3. 提交到 Git
git add config/skill-routing-rules.json
git commit -m "config: 更新路由配置"
git push origin main
```

### 配置文件说明

- `config/skill-routing-rules.json` - 技能路由配置（权威来源）
- `~/.codex/config/custom-skills.json` - Codex 运行时配置（自动同步）
```

- [ ] **Step 2: 创建详细配置指南**

```markdown
# 配置管理指南

## 配置架构

```
仓库配置（权威来源）
config/skill-routing-rules.json
    ↓ (sync-config.py)
运行时配置
~/.codex/config/custom-skills.json
    ↓
Vibe 路由器读取
```

## 配置字段说明

### 技能优先级

- 90-100: 最高优先级（计划、需求澄清类）
- 80-89: 高优先级（开发、测试类）
- 70-79: 中优先级（文档、工具类）
- 60-69: 低优先级（通用助手）

### 关键词配置

示例：
```json
{
  "skill_id": "superpowers-writing-plans",
  "priority": 92,
  "keywords": ["制定计划", "写计划", "implementation plan"]
}
```
```

- [ ] **Step 3: 更新 routing-configuration.md**

在文档末尾添加配置同步说明

- [ ] **Step 4: Commit 文档**

```bash
git add README.md docs/configuration-guide.md docs/routing-configuration.md
git commit -m "docs: 完善配置管理文档"
```

---

### 阶段 3：增强测试覆盖（P1，预计 4 小时）

#### 目标
建立完整的测试框架，覆盖路由器核心逻辑和一致性检查。

---

## Task 7: 配置 pytest 测试框架

**Files:**
- Create: `pytest.ini`
- Create: `requirements-dev.txt`
- Modify: `packages/runtime-core/src/vgo_runtime/test_router_bridge.py`

- [ ] **Step 1: 创建 pytest 配置**

```ini
# pytest.ini
[pytest]
testpaths = packages/runtime-core/src/vgo_runtime
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = 
    -v
    --tb=short
    --strict-markers
    --disable-warnings
markers =
    unit: 单元测试
    integration: 集成测试
    slow: 耗时测试
```

- [ ] **Step 2: 创建开发依赖文件**

```txt
# requirements-dev.txt
pytest>=7.4.0
pytest-cov>=4.1.0
pytest-mock>=3.11.0
```

- [ ] **Step 3: 安装测试依赖**

```bash
pip3 install -r requirements-dev.txt
```

- [ ] **Step 4: 运行现有测试验证框架**

```bash
cd ~/.cc-switch/skills/vibe
pytest
```

预期：发现并运行现有的 3 个测试文件

- [ ] **Step 5: Commit 测试框架配置**

```bash
git add pytest.ini requirements-dev.txt
git commit -m "test: 配置 pytest 测试框架"
```

---

## Task 8: 编写路由器核心逻辑测试

**Files:**
- Create: `packages/runtime-core/src/vgo_runtime/test_router_contract_selection.py`

- [ ] **Step 1: 编写技能选择测试**

```python
# test_router_contract_selection.py
import pytest
from vgo_runtime.router_contract_selection import select_best_skill

@pytest.mark.unit
def test_select_skill_by_priority():
    """高优先级技能应优先选择"""
    skills = [
        {'skill_id': 'skill-a', 'priority': 80, 'keywords': ['test']},
        {'skill_id': 'skill-b', 'priority': 90, 'keywords': ['test']},
    ]
    prompt = "帮我 test"
    result = select_best_skill(prompt, skills)
    assert result['skill_id'] == 'skill-b'

@pytest.mark.unit
def test_select_skill_by_keyword_match():
    """关键词匹配度影响选择"""
    skills = [
        {'skill_id': 'skill-a', 'priority': 85, 'keywords': ['计划']},
        {'skill_id': 'skill-b', 'priority': 85, 'keywords': ['制定计划', '实施计划']},
    ]
    prompt = "帮我制定一个实施计划"
    result = select_best_skill(prompt, skills)
    assert result['skill_id'] == 'skill-b'

@pytest.mark.unit
def test_degraded_skill_not_selected():
    """降级的技能不应被选择"""
    skills = [
        {'skill_id': 'skill-a', 'priority': 90, 'custom_admission_status': 'valid'},
        {'skill_id': 'skill-b', 'priority': 85, 'custom_admission_status': 'custom_manifest_invalid'},
    ]
    prompt = "test"
    result = select_best_skill(prompt, skills)
    assert result['skill_id'] == 'skill-a'
```

- [ ] **Step 2: 运行测试验证失败**

```bash
pytest packages/runtime-core/src/vgo_runtime/test_router_contract_selection.py -v
```

预期：部分测试失败（函数签名可能需要调整）

- [ ] **Step 3: 调整测试以匹配实际 API**

根据实际 `router_contract_selection.py` 的函数签名调整测试代码

- [ ] **Step 4: 运行测试验证通过**

```bash
pytest packages/runtime-core/src/vgo_runtime/test_router_contract_selection.py -v
```

预期：所有测试通过

- [ ] **Step 5: Commit 路由器测试**

```bash
git add packages/runtime-core/src/vgo_runtime/test_router_contract_selection.py
git commit -m "test: 添加路由器核心选择逻辑测试"
```

---

## Task 9: 添加配置加载和验证测试

**Files:**
- Create: `packages/runtime-core/src/vgo_runtime/test_config_loading.py`

- [ ] **Step 1: 编写配置加载测试**

```python
# test_config_loading.py
import pytest
import json
from pathlib import Path

@pytest.mark.unit
def test_skill_routing_rules_is_valid_json():
    """skill-routing-rules.json 必须是有效 JSON"""
    config_path = Path(__file__).parents[5] / 'config' / 'skill-routing-rules.json'
    with open(config_path) as f:
        data = json.load(f)
    assert 'skills' in data
    assert isinstance(data['skills'], list)

@pytest.mark.unit
def test_all_skills_have_required_fields():
    """所有技能必须包含必需字段"""
    config_path = Path(__file__).parents[5] / 'config' / 'skill-routing-rules.json'
    with open(config_path) as f:
        data = json.load(f)
    
    required_fields = ['skill_id', 'priority']
    for skill in data['skills']:
        for field in required_fields:
            assert field in skill, f"技能 {skill.get('skill_id', 'unknown')} 缺少字段 {field}"

@pytest.mark.unit
def test_priority_in_valid_range():
    """优先级必须在 0-100 范围内"""
    config_path = Path(__file__).parents[5] / 'config' / 'skill-routing-rules.json'
    with open(config_path) as f:
        data = json.load(f)
    
    for skill in data['skills']:
        priority = skill.get('priority', 0)
        assert 0 <= priority <= 100, f"技能 {skill['skill_id']} 优先级 {priority} 超出范围"
```

- [ ] **Step 2: 运行配置验证测试**

```bash
pytest packages/runtime-core/src/vgo_runtime/test_config_loading.py -v
```

预期：所有测试通过

- [ ] **Step 3: Commit 配置测试**

```bash
git add packages/runtime-core/src/vgo_runtime/test_config_loading.py
git commit -m "test: 添加配置加载和验证测试"
```

---

### 阶段 4：建立 CI/CD 自动化（P1，预计 2 小时）

---

## Task 10: 创建 GitHub Actions CI 工作流

**Files:**
- Create: `.github/workflows/test.yml`
- Create: `.github/workflows/lint.yml`

- [ ] **Step 1: 创建测试工作流**

```yaml
# .github/workflows/test.yml
name: Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        python-version: ['3.10', '3.11', '3.12']
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v5
      with:
        python-version: ${{ matrix.python-version }}
    
    - name: Install dependencies
      run: |
        pip install -r requirements-dev.txt
    
    - name: Run tests
      run: |
        pytest --cov=packages/runtime-core/src/vgo_runtime --cov-report=term-missing
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      if: matrix.os == 'ubuntu-latest' && matrix.python-version == '3.11'
```

- [ ] **Step 2: 创建 Lint 工作流**

```yaml
# .github/workflows/lint.yml
name: Lint

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  lint:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: '3.11'
    
    - name: Install dependencies
      run: |
        pip install ruff mypy
    
    - name: Validate JSON configs
      run: |
        for file in config/*.json; do
          echo "Validating $file"
          python -m json.tool "$file" > /dev/null
        done
    
    - name: Check Python formatting
      run: |
        ruff check packages/runtime-core/src
```

- [ ] **Step 3: 创建 workflows 目录**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 4: 验证 YAML 语法**

```bash
# 使用 Python yaml 模块验证
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test.yml'))"
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/lint.yml'))"
```

预期：无语法错误

- [ ] **Step 5: Commit CI 配置**

```bash
git add .github/workflows/
git commit -m "ci: 添加 GitHub Actions 测试和 Lint 工作流"
```

---

## Task 11: 添加徽章和 CI 状态到 README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 在 README 顶部添加徽章**

```markdown
# Vibe Skill - 治理化代码编排运行时

[![Test](https://github.com/kzj123vip/vibe-skill/actions/workflows/test.yml/badge.svg)](https://github.com/kzj123vip/vibe-skill/actions/workflows/test.yml)
[![Lint](https://github.com/kzj123vip/vibe-skill/actions/workflows/lint.yml/badge.svg)](https://github.com/kzj123vip/vibe-skill/actions/workflows/lint.yml)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

Vibe 是一个治理化的代码编排运行时...
```

- [ ] **Step 2: Commit README 更新**

```bash
git add README.md
git commit -m "docs: 添加 CI 状态徽章"
```

- [ ] **Step 3: 推送到 GitHub 触发首次 CI 运行**

```bash
git push origin main
```

- [ ] **Step 4: 验证 GitHub Actions 运行**

访问 `https://github.com/kzj123vip/vibe-skill/actions` 确认工作流运行

预期：测试和 Lint 工作流成功运行

---

### 阶段 5：完善文档和依赖管理（P2，预计 2 小时）

---

## Task 12: 整理文档结构并创建索引

**Files:**
- Create: `docs/INDEX.md`
- Modify: `README.md`

- [ ] **Step 1: 分析现有文档类别**

```bash
cd ~/.cc-switch/skills/vibe/docs
ls -1 *.md | wc -l
ls -1 *governance*.md | wc -l
```

- [ ] **Step 2: 创建文档索引**

```markdown
# Vibe 文档索引

## 快速开始
- [README](../README.md) - 项目概述和快速开始
- [快速开始指南](quick-start.md) - 详细安装和使用指南
- [问题排查](troubleshooting.md) - 常见问题和解决方案

## 核心概念
- [架构设计](architecture.md) - 系统架构和设计理念
- [路由配置](routing-configuration.md) - 路由策略和优先级
- [配置管理指南](configuration-guide.md) - 配置文件说明

## 治理文档（Governance）
共 79 个治理文档，按主题分类：

### 运行时治理
- [内存运行时 v3](memory-runtime-v3-governance.md)
- [版本打包](version-packaging-governance.md)
- [门禁可靠性](gate-reliability-governance.md)

### 路由和选择
- [自适应路由评估](adaptive-routing-eval-governance.md)
- [连接器准入](connector-admission-governance.md)

### 质量保障
- [候选质量看板](candidate-quality-board-governance.md)
- [文档失败分类](document-failure-taxonomy-governance.md)

完整列表请查看 [docs/](.) 目录。

## 开发指南
- [贡献指南](../CONTRIBUTING.md) - 如何贡献代码
- [测试指南](testing-guide.md) - 如何编写和运行测试
- [发布流程](release-process.md) - 版本发布流程

## 实施计划
- [优化计划 2026-07-19](superpowers/plans/2026-07-19-vibe-skill-optimization.md)
```

- [ ] **Step 3: 在 README 添加文档链接**

```markdown
## 📚 文档

- [完整文档索引](docs/INDEX.md)
- [快速开始](docs/quick-start.md)
- [架构设计](docs/architecture.md)
- [路由配置](docs/routing-configuration.md)
- [问题排查](docs/troubleshooting.md)
```

- [ ] **Step 4: Commit 文档索引**

```bash
git add docs/INDEX.md README.md
git commit -m "docs: 添加文档索引和导航"
```

---

## Task 13: 创建依赖管理文件

**Files:**
- Create: `requirements.txt`
- Create: `pyproject.toml`

- [ ] **Step 1: 分析 Python 包的实际依赖**

```bash
cd ~/.cc-switch/skills/vibe
# 检查导入语句
grep -rh "^import \|^from " packages/runtime-core/src/vgo_runtime/*.py | \
  grep -v "^from vgo_runtime" | \
  grep -v "^from \." | \
  sort -u | head -20
```

- [ ] **Step 2: 创建运行时依赖文件**

```txt
# requirements.txt
# Vibe 运行时依赖

# 标准库之外的必需依赖（根据实际情况调整）
# 注：大部分功能使用标准库，外部依赖极少
```

- [ ] **Step 3: 创建 pyproject.toml**

```toml
# pyproject.toml
[build-system]
requires = ["setuptools>=65.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "vibe-skill"
version = "2.0.0"
description = "治理化代码编排运行时 - Vibe Code Orchestrator"
readme = "README.md"
requires-python = ">=3.10"
license = {text = "MIT"}
authors = [
    {name = "kzj123vip"}
]
keywords = ["vibe", "code-orchestration", "ai-workflow", "claude-code"]
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
    "pytest-mock>=3.11.0",
    "ruff>=0.1.0",
    "mypy>=1.5.0",
]

[project.urls]
Homepage = "https://github.com/kzj123vip/vibe-skill"
Repository = "https://github.com/kzj123vip/vibe-skill"
Documentation = "https://github.com/kzj123vip/vibe-skill/tree/main/docs"
Issues = "https://github.com/kzj123vip/vibe-skill/issues"

[tool.pytest.ini_options]
testpaths = ["packages/runtime-core/src/vgo_runtime"]
python_files = "test_*.py"
python_classes = "Test*"
python_functions = "test_*"
addopts = ["-v", "--tb=short", "--strict-markers"]

[tool.ruff]
line-length = 120
target-version = "py310"

[tool.mypy]
python_version = "3.10"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = false
```

- [ ] **Step 4: 验证 pyproject.toml 格式**

```bash
python3 -c "import tomllib; tomllib.loads(open('pyproject.toml').read())" 2>/dev/null || \
python3 -c "import tomli; tomli.loads(open('pyproject.toml').read())"
```

预期：格式有效

- [ ] **Step 5: Commit 依赖管理文件**

```bash
git add requirements.txt requirements-dev.txt pyproject.toml
git commit -m "build: 添加依赖管理和项目配置文件"
```

---

## Task 14: 创建 CONTRIBUTING.md 贡献指南

**Files:**
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: 创建贡献指南**

```markdown
# 贡献指南

感谢考虑为 Vibe Skill 做出贡献！

## 开发环境设置

1. Fork 并克隆仓库

```bash
git clone https://github.com/YOUR_USERNAME/vibe-skill.git
cd vibe-skill
```

2. 安装开发依赖

```bash
pip install -e ".[dev]"
# 或
pip install -r requirements-dev.txt
```

3. 运行测试验证环境

```bash
pytest
```

## 贡献流程

1. 创建功能分支

```bash
git checkout -b feature/your-feature-name
```

2. 进行修改并编写测试

3. 运行测试和 Lint

```bash
pytest
ruff check packages/runtime-core/src
```

4. 提交修改

```bash
git add .
git commit -m "feat: 简洁描述你的修改"
```

提交信息格式：
- `feat:` 新功能
- `fix:` 修复 bug
- `docs:` 文档更新
- `test:` 测试相关
- `refactor:` 代码重构
- `ci:` CI/CD 配置

5. 推送到你的 Fork

```bash
git push origin feature/your-feature-name
```

6. 创建 Pull Request

## 代码规范

- Python 代码遵循 PEP 8
- 行长度限制 120 字符
- 所有公共函数必须有文档字符串
- 新功能必须包含测试

## 测试规范

- 单元测试放在功能模块同目录，文件名 `test_*.py`
- 测试函数命名 `test_descriptive_name`
- 使用 pytest 标记：`@pytest.mark.unit` / `@pytest.mark.integration`

## 配置修改规范

修改路由配置时：

1. 修改 `config/skill-routing-rules.json`
2. 运行 `python3 scripts/sync-config.py` 同步到 Codex
3. 运行 `pytest` 确保配置有效
4. 在 PR 中说明修改理由

## 问题反馈

- 使用 GitHub Issues 报告 bug
- 提供详细的复现步骤和环境信息
- 检查是否已有类似 issue

## 许可

贡献的代码将采用 MIT 许可证。
```

- [ ] **Step 2: Commit 贡献指南**

```bash
git add CONTRIBUTING.md
git commit -m "docs: 添加贡献指南"
```

---

### 阶段 6：最终验证和发布（P0，预计 1 小时）

---

## Task 15: 端到端验证所有改进

**Files:**
- Create: `scripts/validate-all.sh`

- [ ] **Step 1: 创建完整验证脚本**

```bash
#!/bin/bash
# scripts/validate-all.sh
set -e

echo "=== Vibe Skill 完整验证 ==="
echo ""

echo "1. 验证 Python 路由器（不使用 PowerShell）"
python3 scripts/router/invoke-pack-route.py \
  --prompt "帮我制定一个实施计划" \
  --grade M \
  --task-type planning \
  --force-runtime-neutral
echo "✓ Python 路由器工作正常"
echo ""

echo "2. 验证配置文件有效性"
for file in config/*.json; do
  python3 -m json.tool "$file" > /dev/null
  echo "✓ $file"
done
echo ""

echo "3. 运行所有测试"
pytest --tb=short
echo "✓ 所有测试通过"
echo ""

echo "4. 验证配置同步"
python3 scripts/sync-config.py
echo "✓ 配置同步成功"
echo ""

echo "5. 检查文档链接"
if [ -f "docs/INDEX.md" ]; then
  echo "✓ 文档索引存在"
else
  echo "✗ 文档索引缺失"
  exit 1
fi
echo ""

echo "=== 所有验证通过 ==="
```

- [ ] **Step 2: 赋予执行权限**

```bash
chmod +x scripts/validate-all.sh
```

- [ ] **Step 3: 运行完整验证**

```bash
./scripts/validate-all.sh
```

预期：所有检查通过

- [ ] **Step 4: Commit 验证脚本**

```bash
git add scripts/validate-all.sh
git commit -m "test: 添加端到端验证脚本"
```

---

## Task 16: 发布优化版本

**Files:**
- Modify: `README.md`
- Create: `CHANGELOG.md`

- [ ] **Step 1: 创建 CHANGELOG**

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [2.1.0] - 2026-07-19

### Added
- 默认使用 Python 路由器，macOS 无需安装 PowerShell
- 统一配置管理，仓库配置为唯一权威来源
- 完整的 pytest 测试框架和测试套件
- GitHub Actions CI/CD 自动化测试和 Lint
- 完整的项目依赖管理 (requirements.txt, pyproject.toml)
- 文档索引和贡献指南
- 端到端验证脚本 `scripts/validate-all.sh`
- 配置同步工具 `scripts/sync-config.py`

### Changed
- 路由器优先级：superpowers-writing-plans 提升到 92
- 路由器优先级：superpowers-brainstorming 提升到 90
- PowerShell 路由器仅作为 Windows 兼容回退
- 改进路由一致性检查，支持降级场景

### Fixed
- 修复 route_snapshot.selected_skill 降级后不一致问题
- 统一 Claude Code 和 Codex Web 使用同一 Vibe 目录

### Documentation
- 新增配置管理指南
- 新增测试指南
- 完善 README 系统要求说明
- 新增 79 个治理文档的索引

## [2.0.0] - 2026-07-08

### Added
- 初始发布到 GitHub
- 治理化运行时核心功能
- 路由器和技能选择系统
- 六阶段状态机
```

- [ ] **Step 2: 更新 README 版本信息**

```markdown
# Vibe Skill - 治理化代码编排运行时

[![Version](https://img.shields.io/badge/version-2.1.0-blue.svg)](./CHANGELOG.md)
[![Test](https://github.com/kzj123vip/vibe-skill/actions/workflows/test.yml/badge.svg)](https://github.com/kzj123vip/vibe-skill/actions/workflows/test.yml)
...

## 🎉 v2.1.0 新功能

- ✅ macOS 优先：默认使用 Python 路由器，无需安装 PowerShell
- ✅ 统一配置：仓库配置为唯一权威来源，自动同步
- ✅ 完整测试：pytest 框架 + GitHub Actions CI
- ✅ 完善文档：文档索引、贡献指南、配置管理指南

查看 [CHANGELOG.md](./CHANGELOG.md) 了解详细变更。
```

- [ ] **Step 3: Git 标签发布**

```bash
cd ~/.cc-switch/skills/vibe
git add CHANGELOG.md README.md
git commit -m "release: v2.1.0 - macOS 优先，统一配置，完整测试"
git tag -a v2.1.0 -m "v2.1.0 - macOS 优先，统一配置，完整测试"
```

- [ ] **Step 4: 推送到 GitHub**

```bash
git push origin main
git push origin v2.1.0
```

- [ ] **Step 5: 创建 GitHub Release**

```bash
gh release create v2.1.0 \
  --title "v2.1.0 - macOS 优先，统一配置，完整测试" \
  --notes-file CHANGELOG.md
```

预期：GitHub Release 创建成功

---

## 总结

### 完成的优化

#### 🔴 高优先级（P0）
- ✅ **消除 PowerShell 依赖**：Python 路由器成为默认，macOS 用户无需 pwsh
- ✅ **统一配置管理**：仓库配置为权威来源，自动同步到 Codex

#### 🟡 中优先级（P1）
- ✅ **增强测试覆盖**：pytest 框架 + 路由器核心测试 + 配置验证测试
- ✅ **CI/CD 自动化**：GitHub Actions 测试和 Lint 工作流

#### 🟢 低优先级（P2）
- ✅ **完善依赖管理**：requirements.txt + pyproject.toml
- ✅ **整理文档结构**：文档索引 + 贡献指南 + 配置管理指南

### 关键指标改进

| 指标 | 优化前 | 优化后 | 改进 |
|------|--------|--------|------|
| macOS 依赖 PowerShell | 是 | 否 | ✅ 移除 |
| 配置统一性 | 分离 | 统一 | ✅ 单一来源 |
| 测试覆盖 | 3 个文件 | 5+ 个文件 | ✅ +67% |
| CI/CD | 无 | GitHub Actions | ✅ 新增 |
| 依赖管理 | 无 | pyproject.toml | ✅ 新增 |
| 文档索引 | 无 | INDEX.md | ✅ 新增 |

### 技术债务清理

- ✅ PowerShell 路由器降级为兼容回退
- ✅ 配置分离问题已解决
- ✅ 测试基础设施建立
- ✅ 文档碎片化问题缓解

### 下一步建议（未来迭代）

#### 短期（1-2 周）
1. 增加集成测试覆盖完整路由流程
2. 添加性能基准测试
3. 完善 mypy 类型注解

#### 中期（1-2 月）
1. 完全移除 PowerShell 路由器（1910 行）
2. 实现配置热重载
3. 添加路由决策可视化工具

#### 长期（3-6 月）
1. 支持插件化技能注册
2. 建立技能市场和版本管理
3. 支持分布式路由（多机协同）

---

## 验收标准

### 功能验收

- [ ] macOS 用户无需安装 pwsh 即可使用路由器
- [ ] 修改仓库配置后，运行 `sync-config.py` 立即生效
- [ ] 所有 pytest 测试通过
- [ ] GitHub Actions CI 成功运行
- [ ] 端到端验证脚本 `validate-all.sh` 通过

### 质量验收

- [ ] 测试覆盖率 > 60%
- [ ] 所有 JSON 配置文件格式有效
- [ ] 文档链接无死链
- [ ] GitHub Release 发布成功

### 用户体验验收

- [ ] README 清晰说明 macOS 优先
- [ ] 配置修改流程文档化
- [ ] 贡献指南完整可操作
- [ ] 问题排查指南覆盖常见问题

---

## 风险和缓解措施

### 风险 1：Python 路由器与 PowerShell 行为不一致

**概率**：中  
**影响**：高  
**缓解**：
- 编写对比测试，验证两个路由器输出一致
- 保留 PowerShell 作为回退路径
- 在 CI 中同时测试两种模式

### 风险 2：配置同步破坏现有 Codex 配置

**概率**：低  
**影响**：中  
**缓解**：
- sync-config.py 自动备份 Codex 配置
- 提供配置回滚命令
- 在文档中明确说明同步行为

### 风险 3：测试覆盖不足导致回归

**概率**：中  
**影响**：中  
**缓解**：
- 增量增加测试覆盖
- CI 强制测试通过才能合并
- 定期 review 测试质量

---

## 执行时间估算

| 阶段 | 任务数 | 预计时间 | 依赖 |
|------|--------|----------|------|
| 阶段 1：消除 PowerShell 依赖 | 3 | 4h | 无 |
| 阶段 2：统一配置管理 | 3 | 3h | 无 |
| 阶段 3：增强测试覆盖 | 3 | 4h | 阶段 1 |
| 阶段 4：建立 CI/CD | 2 | 2h | 阶段 3 |
| 阶段 5：完善文档和依赖 | 3 | 2h | 无 |
| 阶段 6：最终验证和发布 | 2 | 1h | 所有阶段 |
| **总计** | **16** | **16h** | - |

按每天 4 小时计算，约需 **4 个工作日**完成。

---

计划完成！保存到 `docs/superpowers/plans/2026-07-19-vibe-skill-optimization.md`。
