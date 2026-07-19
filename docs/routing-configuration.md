# Vibe 路由配置指南

## 概述

Vibe 使用多层路由机制自动选择最合适的 specialist 技能处理任务。路由配置位于 Codex 全局配置文件中，由 PowerShell 路由器和 Python 运行时共同协作。

## 配置文件位置

- **Codex 全局配置**：`~/.codex/config/custom-skills.json`
- **Claude Code 配置**：软链接到 `~/.codex/config/custom-skills.json`（共享配置）
- **Vibe 路由器**：`scripts/router/resolve-pack-route.ps1`（PowerShell）

## 优先级体系

路由器根据以下因素选择技能：

1. **优先级（priority）**：数值越高越优先（0-100）
2. **关键词匹配（keywords）**：任务描述与关键词的匹配度
3. **意图标签（intent_tags）**：`planning`、`coding`、`debug`、`review`、`research`
4. **触发模式（trigger_mode）**：`auto`（自动）或 `explicit`（显式调用）

## Superpower 技能优先级（2026-07-19 更新）

| 技能 | 优先级 | Intent Tags | 触发场景 |
|------|--------|-------------|----------|
| **superpowers-writing-plans** | **92** | planning | 制定计划、执行计划、架构设计 |
| **superpowers-brainstorming** | **90** | planning | 需求澄清、探索意图、设计前调研 |
| superpowers-systematic-debugging | 89 | debug | 定位根因、调试失败 |
| superpowers-test-driven-development | 89 | coding, debug | TDD、功能实现 |
| superpowers-verification-before-completion | 89 | review | 完成前验证 |

### 关键词增强

#### superpowers-writing-plans (priority: 92)
**新增中文关键词**：
- 制定计划、写计划、执行计划、实施计划
- 设计方案、技术方案、方案设计

**新增英文关键词**：
- planning、write plan、implementation plan、architecture plan

#### superpowers-brainstorming (priority: 90)
**新增中文关键词**：
- 澄清需求、探索需求、理解需求
- 需求分析、设计前调研

**新增英文关键词**：
- clarify requirements、explore intent、understand requirements

## 路由决策流程

```
用户任务
    ↓
关键词提取
    ↓
意图分类（planning/coding/debug/review/research）
    ↓
候选技能池（匹配 intent_tags）
    ↓
优先级排序 + 关键词权重计算
    ↓
选中最高分技能
    ↓
降级检查（custom_admission_status）
    ↓
最终执行技能
```

## 常见问题排查

### 问题1：计划任务未路由到 superpowers-writing-plans

**症状**：说"制定计划"时路由到了其他技能

**排查步骤**：
1. 检查优先级：`grep -A 5 '"superpowers-writing-plans"' ~/.codex/config/custom-skills.json`
2. 确认 priority 是否为 92
3. 检查关键词是否包含"制定计划"

**修复**：重新运行本文档底部的配置脚本

### 问题2：缓存审计任务推荐了 iOS 或无关技能

**根因**：关键词过宽（如"修复"、"清理"、"验证"）同时命中多个泛化技能

**解决方案**：
1. 增加负向约束（在路由器中排除 iOS/Swift/移动端技能）
2. 为缓存相关任务增加正向锚点关键词

**状态**：待实现（需要修改 `scripts/router/resolve-pack-route.ps1`）

### 问题3：route_snapshot 与 skill_routing.selected 不一致

**根因**：技能降级后 route_snapshot 未同步更新

**修复状态**：✅ 已修复（放宽一致性检查，允许降级场景）

**测试覆盖**：
- `test_truth_consistency_accepts_degraded_route_snapshot_with_a_different_selected_specialist`

## 修改配置的两种方式

### 方式1：手动编辑（推荐用于精细调整）

```bash
# 备份原始配置
cp ~/.codex/config/custom-skills.json ~/.codex/config/custom-skills.json.bak

# 编辑配置
code ~/.codex/config/custom-skills.json  # 或使用 vim/nano

# 找到对应技能，修改 priority 和 keywords
```

### 方式2：自动化脚本（推荐用于批量修改）

```bash
python3 << 'PYTHON'
import json

config_path = '/Users/kzj/.codex/config/custom-skills.json'

with open(config_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

# 修改优先级
for skill in data['skills']:
    if skill['id'] == 'superpowers-writing-plans':
        skill['priority'] = 92
    elif skill['id'] == 'superpowers-brainstorming':
        skill['priority'] = 90

with open(config_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("✓ 配置已更新")
PYTHON
```

## 验证配置生效

### 方法1：直接检查配置文件

```bash
grep -A 5 '"superpowers-writing-plans"' ~/.codex/config/custom-skills.json
grep -A 5 '"superpowers-brainstorming"' ~/.codex/config/custom-skills.json
```

### 方法2：实际测试路由

在 Codex Web 或 Claude Code 中测试：

**测试1：计划任务**
```
帮我制定一个实施计划
```
**预期结果**：路由到 `superpowers-writing-plans`

**测试2：需求澄清**
```
先帮我澄清一下需求
```
**预期结果**：路由到 `superpowers-brainstorming`

**测试3：调试任务**
```
帮我调试这个测试失败的问题
```
**预期结果**：路由到 `superpowers-systematic-debugging`

## 恢复原始配置

如果修改后出现问题，可以恢复备份：

```bash
# 查看备份文件
ls -lt ~/.codex/config/custom-skills.json.bak-*

# 恢复最新备份
cp ~/.codex/config/custom-skills.json.bak-YYYYMMDD-HHMMSS ~/.codex/config/custom-skills.json
```

## 更新历史

### 2026-07-19
- ✅ 提升 `superpowers-writing-plans` 优先级：89 → 92
- ✅ 提升 `superpowers-brainstorming` 优先级：89 → 90
- ✅ 增强中英文关键词覆盖
- ✅ 修复 route_snapshot 降级后一致性检查问题

### 待完成
- ⏳ 增加缓存审计任务的正向锚点关键词
- ⏳ 增加 iOS/Swift/移动端技能的负向约束
- ⏳ 将 PowerShell 路由器迁移为 Python 模块（macOS 优先）

## 参考资料

- [Vibe SKILL.md](../SKILL.md)：技能入口说明
- [custom-skills.json 生成逻辑](../apps/vgo-cli/src/vgo_cli/install_support.py)
- [路由器实现](../scripts/router/resolve-pack-route.ps1)
