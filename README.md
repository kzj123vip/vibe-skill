# Vibe Skill

Vibe 是一个治理化的 AI 工作流运行时，支持 Claude Code 和 Codex Web。

## 核心特性

- **六阶段治理运行时**：skeleton_check → deep_interview → requirement_doc → xl_plan → plan_execute → phase_cleanup
- **specialist 推荐路由器 Python 优先**（v2.1+）：`router_bridge.py`（负责推荐专家技能）默认走 Python，无需 PowerShell；通过 `VIBE_USE_POWERSHELL=1` 可选回退到 PowerShell
- **六阶段治理主运行时仍需 PowerShell**：`canonical_entry.py` 调用的 `invoke-vibe-runtime.ps1` 及其模块目前仍依赖 `pwsh`（macOS 需先安装 PowerShell 7）。完整迁移到 Python 尚未完成
- **specialist 技能路由**：自动推荐和调度专家技能
- **证明文件生成**：需求文档、执行计划、验证报告、清理收据
- **边界返回控制**：在关键阶段返回用户决策

## 快速开始

### macOS/Linux

> **前置依赖**：六阶段治理运行时需要 PowerShell 7 (`pwsh`)。macOS 可用 `brew install --cask powershell` 安装。
> 未安装 `pwsh` 时，`/vibe` 六阶段主流程会直接报错 `PowerShell executable not found`（specialist 推荐路由器不受影响，可独立以 Python 运行）。

```bash
git clone https://github.com/kzj123vip/vibe-skill.git
cd vibe-skill
./install.sh
./check.sh
```

### Windows

```powershell
git clone https://github.com/kzj123vip/vibe-skill.git
cd vibe-skill
.\install.ps1
.\check.ps1
```

## 路由器架构（v2.1+）

> **重要范围说明**：本节的"Python 优先"**仅适用于 specialist 推荐路由器**（`router_bridge.py`，负责推荐专家技能）。
> **六阶段治理主运行时**（`canonical_entry.py` → `invoke-vibe-runtime.ps1`，即你运行 `/vibe` 时的实际流程）**仍然强依赖 PowerShell 7 (`pwsh`)**。
> macOS/Linux 用户运行完整治理流程时**必须安装 `pwsh`**，否则主入口会报 `PowerShell executable not found`。
> 完整移除 PowerShell 依赖需要迁移全部 `.ps1` 运行时模块，属于尚未完成的大型工作。

### Python 优先策略（仅 specialist 推荐路由器）（仅限 specialist 推荐路由器）

> **范围说明**：本节仅针对 `router_bridge.py`——负责"推荐哪个专家技能"的辅助路由器。六阶段治理主运行时（`canonical_entry.py` → `invoke-vibe-runtime.ps1`）仍依赖 PowerShell，见下方"已知限制"。

从 v2.1.0 开始，specialist 推荐路由器默认使用 **Python**，该辅助功能不再需要 PowerShell：

```bash
# 默认：specialist 推荐路由器使用 Python（无需 PowerShell）
python3 -m vgo_runtime.router_bridge \
  --prompt "你的任务描述" \
  --grade M \
  --task-type coding
```

### PowerShell 兼容回退

如果需要使用 PowerShell 路由器（例如 Windows 环境或特定兼容性需求），可通过环境变量启用：

```bash
# 显式启用 PowerShell 路由器
VIBE_USE_POWERSHELL=1 python3 -m vgo_runtime.router_bridge \
  --prompt "你的任务描述" \
  --grade M \
  --task-type coding
```

### 路由器对比

| 特性 | Python 路由器 | PowerShell 路由器 |
|------|--------------|------------------|
| **默认状态** | ✅ 默认启用 | ⚠️ 需环境变量 |
| **依赖** | Python 3.10+ | PowerShell 7+ |
| **平台支持** | macOS/Linux/Windows | Windows/macOS/Linux |
| **性能** | 快速启动 | 略慢（进程启动） |
| **维护状态** | 🟢 活跃维护 | 🟡 兼容维护 |

### 路由优化（本次更新）

#### v2.1.0 改进
- ✅ **specialist 推荐路由器 Python 优先**：`router_bridge.py` 默认走 Python，该辅助模块不再需要 PowerShell
- ✅ **环境变量控制**：`VIBE_USE_POWERSHELL=1` 可对该路由器可选启用 PowerShell
- ✅ **向后兼容**：PowerShell 路由器保留为兼容回退
- ⚠️ **未完成**：六阶段治理主运行时仍依赖 `pwsh`，macOS/Linux 完整流程仍需安装 PowerShell 7

#### 历史问题修复
- 缓存审计任务错误推荐 iOS/代码接收类 specialist
- 计划类任务未优先选中 `superpowers-writing-plans`
- `route_snapshot.selected_skill` 在降级后未同步更新，导致一致性检查失败

#### 已完成修复
1. **一致性检查放宽**：允许 `route_snapshot.selected_skill` 在 `degraded_skill_ids` 中
2. **测试覆盖**：新增 `test_truth_consistency_accepts_degraded_route_snapshot_with_a_different_selected_specialist`
3. **路由器优先级**：Python 优先，PowerShell 可选回退

## 运行时调用

```bash
~/.claude/.vibeskills/bin/vibe-entry \
  --repo-root /path/to/vibe-skill \
  --artifact-root /path/to/workspace \
  --host-id codex \
  --entry-id vibe \
  --prompt "你的任务描述"
```

## 项目结构

```
vibe-skill/
├── apps/vgo-cli/              # Python CLI 入口
├── packages/                  # 核心运行时包
│   ├── runtime-core/          # 治理引擎
│   ├── contracts/             # 数据契约
│   ├── verification-core/     # 验证逻辑
│   └── installer-core/        # 安装器
├── scripts/                   # 路由器和工具
├── config/                    # 路由配置
├── protocols/                 # 治理协议文档
├── SKILL.md                   # 技能入口说明
└── docs/                      # 设计文档
```

## 配置管理

### 配置位置

所有配置文件存储在仓库中：`config/`

运行时通过 `--repo-root` 参数直接读取仓库配置，无需复制到 Codex 全局配置。

### 配置架构

- **90 个配置文件**：按功能分组管理（路由策略、内存管理、specialist 规则等）
- **配置清单**：`config/runtime-config-manifest.json` 维护完整清单
- **仓库为源头**：Git 版本控制，升级友好

### 配置修改指南

⚠️ **不建议直接修改配置文件**，`git pull` 升级时会产生冲突。

如需自定义行为，使用以下方法：

#### 方法 1：环境变量（推荐）

```bash
# 启用 PowerShell 路由器（Windows 兼容）
export VIBE_USE_POWERSHELL=1

# 其他可配置项（后续版本支持）
export VIBE_ROUTER_CONFIDENCE_THRESHOLD=0.8
export VIBE_MEMORY_RETRIEVAL_BUDGET=5000
```

#### 方法 2：workspace 配置（项目级）

在项目根目录创建 `.vibeskills/config/overrides.json`：

```json
{
  "router_thresholds": {
    "confidence_threshold": 0.8
  },
  "memory": {
    "retrieval_budget_tokens": 5000
  }
}
```

**优先级**：环境变量 > workspace 配置 > 仓库默认配置

### 配置升级

升级前检查本地修改：

```bash
./scripts/verify/check-local-modifications.sh
```

如果检测到本地修改，可选以下方案：

**方案 1：暂存本地修改（推荐）**
```bash
git stash push -m 'backup config before upgrade' config/
git pull
git stash pop  # 升级后恢复（可能需要手动合并）
```

**方案 2：放弃本地修改**
```bash
git restore config/
git clean -fd config/
git pull
```

**方案 3：提交本地修改（如果是有价值的改进）**
```bash
git add config/
git commit -m 'feat: 配置优化'
git pull --rebase
```

### 配置文件分组

详见 `config/runtime-config-manifest.json`，主要分组：

- **运行时治理文件**（24 个）：核心运行时策略
- **路由与发现策略**（25 个）：specialist 路由、能力发现
- **内存策略文件**（9 个）：工作区内存、检索预算
- **overlay 与 specialist 策略**（14 个）：代码质量、框架互操作
- **分发与锁定文件**（4 个）：版本锁定、上游依赖
- **OpenCode 预览**（7 个）：OpenCode 集成
- **其他配置**（7 个）：待分类

### 关键配置文件

- `config/router-thresholds.json`：路由置信度阈值
- `config/router-provider-defaults.json`：路由器提供者默认值
- `config/skill-routing-rules.json`：specialist 路由规则
- `config/powershell-host-policy.json`：PowerShell 策略
- `config/runtime-modes.json`：运行时模式定义

## 技术栈

- **Python 3.10+**：核心运行时
- **Bash**：macOS/Linux 入口和工具
- **PowerShell**：Windows 兼容路径
- **pytest**：测试框架

## 贡献

欢迎提交 Issue 和 Pull Request。

## 协议

MIT License

## 相关链接

- [Claude Code](https://claude.ai/code)
- [Codex Web](https://codex.anthropic.com)
