# 配置差异分析与合并策略

生成时间：2026-07-19  
分析范围：Vibe Skill 仓库配置 vs Codex 用户配置

## 1. 配置架构概览

### 仓库配置（源头）

**位置**：`~/.cc-switch/skills/vibe/config/`

**清单管理**：`config/runtime-config-manifest.json`（90 个配置文件）

**角色分组**：
1. **运行时治理文件**（24 个）：核心运行时策略
2. **路由与发现策略文件**（25 个）：specialist 路由、能力发现
3. **内存策略文件**（9 个）：工作区内存、检索预算
4. **overlay 与 specialist 策略文件**（14 个）：代码质量、框架互操作
5. **分发与锁定文件**（4 个）：版本锁定、上游依赖
6. **OpenCode 预览文件**（7 个）：OpenCode 集成
7. **其他配置文件**（7 个）：待分类

**总计**：90 个配置文件

### Codex 配置（本地）

**位置**：`~/.codex/config/custom-skills.json`

**管理方式**：单一 JSON 文件，包含所有自定义技能的路径映射

**当前状态**：
- 文件大小：138 KB（138,271 字节）
- 备份存在：`custom-skills.json.bak-20260719-115011`（137,866 字节）
- Vibe 技能：**未在此文件中直接定义**

**结论**：Codex 通过**符号链接或包管理器**加载 Vibe，而非在 `custom-skills.json` 中定义路径。

## 2. 配置同步机制分析

### 当前实际机制

根据检查结果，Vibe 的配置管理采用**仓库为源头**的模式：

1. **所有配置存储在仓库**：`~/.cc-switch/skills/vibe/config/`
2. **运行时直接读取仓库配置**：通过 `--repo-root` 参数传递
3. **无配置复制到 Codex**：Codex 只需知道仓库路径

**证据**：
```bash
# SKILL.md 中的调用方式
$PYTHON_BIN -m vgo_cli.main canonical-entry \
  --repo-root "$REPO_ROOT" \              # 直接指向仓库
  --artifact-root "$WORKSPACE_ROOT" \
  --host-id "<host_id>" \
  --entry-id "vibe" \
  --prompt "<extracted keyword intent text>"
```

### 优势

✅ **单一源头**：仓库是配置的唯一权威源  
✅ **版本控制**：配置变更自动纳入 Git 版本管理  
✅ **无同步问题**：运行时直接读取仓库，无需同步机制  
✅ **升级友好**：`git pull` 即可更新所有配置

### 潜在风险

⚠️ **用户本地修改**：如果用户直接修改 `~/.cc-switch/skills/vibe/config/` 中的文件，`git pull` 会冲突  
⚠️ **配置覆盖**：无法在用户级覆盖某些配置（例如调整路由阈值）

## 3. 配置差异检测

### 检测目标

1. **仓库本地修改**：用户是否修改了 `~/.cc-switch/skills/vibe/config/` 中的文件？
2. **未跟踪文件**：是否存在新增的配置文件？
3. **Codex 全局配置**：`~/.codex/config/` 中是否有影响 Vibe 行为的设置？

### 检测方法

#### 方法 1：Git 状态检查

```bash
cd ~/.cc-switch/skills/vibe
git status config/
```

**预期输出（无本地修改）**：
```
On branch main
nothing to commit, working tree clean
```

**异常输出（有本地修改）**：
```
modified:   config/router-thresholds.json
Untracked files:
  config/local-overrides.json
```

#### 方法 2：配置文件完整性校验

```bash
cd ~/.cc-switch/skills/vibe
find config/ -name "*.json" | while read file; do
  git diff --quiet "$file" || echo "MODIFIED: $file"
done
```

#### 方法 3：Codex 全局配置检查

```bash
# 检查是否有 Vibe 相关的全局设置
grep -r "vibe\|VGO\|specialist-router" ~/.codex/config/ 2>/dev/null || echo "无 Vibe 全局配置"
```

## 4. 合并策略设计

### 策略 A：仓库为唯一源头（推荐，当前实现）

**原则**：所有配置都在仓库中管理，禁止用户本地修改。

**实施**：
1. **文档说明**：在 README 中明确"配置文件不应直接修改"
2. **Git 忽略检查**：升级前检查是否有本地修改，提示用户备份
3. **用户级覆盖**：如需自定义，通过**环境变量**或 **workspace 级配置**实现

**优点**：
- ✅ 简单清晰，无同步复杂性
- ✅ 升级安全，无配置冲突
- ✅ 版本可控，易于回滚

**缺点**：
- ❌ 用户无法持久化自定义配置
- ❌ 多用户共享机器时可能冲突

**适用场景**：单用户开发环境（macOS/Linux 典型场景）

### 策略 B：三层配置合并（备选，复杂）

**原则**：支持**仓库默认配置 < 用户全局配置 < workspace 配置**的三层覆盖。

**实施**：
1. **仓库配置**：`~/.cc-switch/skills/vibe/config/*.json`（默认值）
2. **用户配置**：`~/.codex/config/vibe-overrides.json`（持久化自定义）
3. **workspace 配置**：`<workspace>/.vibeskills/config/*.json`（项目特定）

**合并规则**：
```python
final_config = merge(
    load_repo_config(),
    load_user_config(),  # 覆盖仓库配置
    load_workspace_config()  # 覆盖用户配置
)
```

**优点**：
- ✅ 用户可持久化自定义
- ✅ 项目级配置隔离
- ✅ 升级时仓库配置不影响用户设置

**缺点**：
- ❌ 复杂度高，需实现配置合并逻辑
- ❌ 调试困难（配置来源不明确）
- ❌ 性能损耗（每次运行都需合并）

**适用场景**：企业多用户环境，需要严格配置隔离

### 策略 C：混合策略（权衡方案）

**原则**：**大部分配置**走策略 A（仓库唯一源头），**少量高频自定义项**走策略 B（三层合并）。

**实施**：
1. **核心配置**（90 个文件）：仅从仓库加载，不允许覆盖
2. **用户可调参数**（5-10 个关键项）：支持环境变量覆盖
   - `VIBE_ROUTER_CONFIDENCE_THRESHOLD`
   - `VIBE_MEMORY_RETRIEVAL_BUDGET`
   - `VIBE_SPECIALIST_TIMEOUT_SECONDS`
   - `VIBE_USE_POWERSHELL`（已实现）
3. **workspace 配置**：允许项目级 `.vibeskills/config/overrides.json`

**环境变量优先级**：
```
环境变量 > workspace 配置 > 仓库默认配置
```

**优点**：
- ✅ 简单场景下无感（默认行为清晰）
- ✅ 高频需求可自定义（环境变量）
- ✅ 升级安全（核心配置不可覆盖）

**缺点**：
- ⚠️ 需明确定义"可覆盖"的边界
- ⚠️ 文档复杂度中等

**适用场景**：当前 Vibe 用户群体（个人开发者 + 少量企业用户）

## 5. 推荐方案与实施步骤

### 推荐：策略 A（仓库唯一源头）+ 环境变量扩展点

**理由**：
1. 当前实现已经是策略 A，无需重构
2. 用户群体主要是个人开发者，配置自定义需求不高
3. 通过环境变量提供少量扩展点，满足 80% 场景

### 实施步骤

#### 步骤 1：文档化当前配置管理方式

**文件**：`README.md` 新增章节

**内容**：
```markdown
## 配置管理

### 配置位置

所有配置文件存储在仓库中：`~/.cc-switch/skills/vibe/config/`

运行时通过 `--repo-root` 参数直接读取仓库配置，无需复制到 Codex 全局配置。

### 配置修改

⚠️ **不建议直接修改配置文件**，`git pull` 升级时会产生冲突。

如需自定义行为，使用以下方法：

#### 方法 1：环境变量（推荐）

```bash
export VIBE_USE_POWERSHELL=1  # 启用 PowerShell 路由器
export VIBE_ROUTER_CONFIDENCE_THRESHOLD=0.8  # 路由置信度阈值
```

#### 方法 2：workspace 配置

在项目根目录创建 `.vibeskills/config/overrides.json`：

```json
{
  "router_thresholds": {
    "confidence_threshold": 0.8
  }
}
```

### 配置升级

升级前检查本地修改：

```bash
cd ~/.cc-switch/skills/vibe
git status config/
```

如有未提交的修改，备份后执行：

```bash
git stash  # 备份本地修改
git pull   # 拉取最新配置
git stash pop  # 恢复本地修改（可能需要手动合并）
```
```

#### 步骤 2：实现环境变量覆盖

**目标文件**：`packages/runtime-core/src/vgo_runtime/router.py`

**修改示例**：
```python
import os

# 加载路由阈值配置
def load_router_thresholds():
    # 从仓库配置加载默认值
    default_config = load_json("config/router-thresholds.json")
    
    # 环境变量覆盖
    env_threshold = os.environ.get('VIBE_ROUTER_CONFIDENCE_THRESHOLD')
    if env_threshold:
        default_config['confidence_threshold'] = float(env_threshold)
    
    return default_config
```

**覆盖范围**：仅限高频自定义项（5-10 个），其余配置保持只读。

#### 步骤 3：升级前检查脚本

**文件**：`scripts/verify/check-local-modifications.sh`

**内容**：
```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

echo "检查配置文件本地修改..."

MODIFIED=$(git status --porcelain config/ | grep "^ M" || true)

if [ -n "$MODIFIED" ]; then
    echo "⚠️  警告：检测到本地修改的配置文件："
    echo "$MODIFIED"
    echo ""
    echo "升级前请备份这些文件，或执行："
    echo "  git stash"
    echo "  git pull"
    echo "  git stash pop"
    exit 1
else
    echo "✅ 无本地修改，可以安全升级"
fi
```

#### 步骤 4：在 README 中说明配置管理方式

已在步骤 1 完成。

## 6. 验证计划

### 验证点 1：无本地修改场景

```bash
cd ~/.cc-switch/skills/vibe
git status config/
# 预期：working tree clean

git pull
# 预期：配置文件顺利更新
```

### 验证点 2：有本地修改场景

```bash
cd ~/.cc-switch/skills/vibe
echo '{"test": true}' >> config/router-thresholds.json
git status config/
# 预期：显示 modified: config/router-thresholds.json

./scripts/verify/check-local-modifications.sh
# 预期：警告本地修改，提示备份
```

### 验证点 3：环境变量覆盖

```bash
export VIBE_USE_POWERSHELL=1
python3 -m vgo_runtime.router_bridge --prompt "测试" --grade M --task-type coding
# 预期：使用 PowerShell 路由器

unset VIBE_USE_POWERSHELL
python3 -m vgo_runtime.router_bridge --prompt "测试" --grade M --task-type coding
# 预期：使用 Python 路由器
```

## 7. 风险与缓解

### 风险 1：用户直接修改配置文件

**概率**：中  
**影响**：升级冲突  
**缓解**：
- 在 README 中明确说明"不建议直接修改"
- 提供升级前检查脚本
- 文档化环境变量覆盖方法

### 风险 2：环境变量命名冲突

**概率**：低  
**影响**：意外行为  
**缓解**：
- 使用 `VIBE_` 前缀避免冲突
- 文档化所有支持的环境变量
- 运行时日志记录环境变量覆盖情况

### 风险 3：workspace 配置被误提交到 Git

**概率**：中  
**影响**：项目级配置泄露到版本控制  
**缓解**：
- 在 `.gitignore` 中添加 `.vibeskills/config/overrides.json`
- 文档中说明 workspace 配置的作用域

## 8. 结论

**推荐方案**：策略 A（仓库唯一源头）+ 少量环境变量扩展点

**优势**：
- 简单清晰，符合当前实现
- 升级友好，无配置冲突
- 满足 80% 用户需求

**实施优先级**：
1. **P0**（本次实施）：文档化配置管理方式（README）
2. **P1**（本次实施）：升级前检查脚本
3. **P2**（后续迭代）：环境变量覆盖关键配置项

## 附录：配置文件清单

见 `config/runtime-config-manifest.json`，共 90 个文件。

**核心配置文件（需重点关注）**：
- `config/router-thresholds.json`：路由置信度阈值
- `config/router-provider-defaults.json`：路由器提供者默认值
- `config/skill-routing-rules.json`：specialist 路由规则
- `config/powershell-host-policy.json`：PowerShell 策略
- `config/runtime-modes.json`：运行时模式定义
