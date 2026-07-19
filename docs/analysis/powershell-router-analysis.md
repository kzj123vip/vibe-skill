# PowerShell 路由器逻辑分析

**创建时间**: 2026-07-19  
**目的**: 为迁移到 Python 路由器提供参考

## 核心架构

### 1. 输入参数（19 个）
```powershell
param(
    [string]$Prompt,              # 必需：用户提示
    [string]$Grade,               # 可选：M/L/XL，为空时自动推断
    [string]$TaskType,            # 可选：任务类型，为空时自动推断
    [string]$RequestedSkill,      # 可选：用户显式请求的技能
    [string]$HostId,              # 主机标识符
    [string]$TargetRoot,          # 目标根目录
    [string]$HostDecisionJson,    # 主机决策 JSON
    [switch]$Probe,               # 探测模式
    [string]$ProbeLabel,          # 探测标签
    [string]$ProbeOutputDir,      # 探测输出目录
    [switch]$ProbeIncludePrompt,  # 探测包含提示
    [int]$ProbePromptMaxChars,    # 探测提示最大字符数
    [switch]$Unattended           # 无人值守模式
)
```

### 2. 模块加载（24 个模块）
脚本加载 24 个路由器模块，按编号顺序：
- `00-core-utils.ps1` - 核心工具函数
- `01-openai-responses.ps1` - OpenAI 响应处理
- `10-observability.ps1` - 可观测性
- `11-route-probe.ps1` - 路由探测
- `19-custom-admission.ps1` - 自定义准入
- `20-routing-rules.ps1` - 路由规则
- `21-capability-interview.ps1` - 能力面试
- `22-intent-contract.ps1` - 意图契约
- `30-openspec.ps1` - 开放规范
- `31-gsd-overlay.ps1` - GSD 覆盖
- `41-candidate-selection.ps1` - 候选选择
- `42-ai-rerank-overlay.ps1` - AI 重排序覆盖
- `46-confirm-ui.ps1` - 确认 UI
- 等等...

### 3. 核心函数（7 个）

#### 3.1 `Resolve-RouterGradeValue`
- **目的**: 解析路由器等级值
- **逻辑**:
  1. 如果 `$InputGrade` 为空，调用 `Get-VibeInternalGrade` 自动推断
  2. 否则标准化为大写并验证是否为 M/L/XL
  3. 返回标准化的等级值

#### 3.2 `Resolve-RouterTaskTypeValue`
- **目的**: 解析任务类型值
- **逻辑**:
  1. 如果 `$InputTaskType` 为空，调用 `Get-VibeInferredTaskType` 自动推断
  2. 否则标准化为小写并验证
  3. 返回标准化的任务类型

#### 3.3 `Get-PreferredHostSelection`
- **目的**: 获取主机偏好选择
- **输入**: 
  - `$HostId` - 主机标识
  - `$PackRows` - 包行数组
  - `$AllCandidates` - 所有候选
- **逻辑**: 基于主机偏好过滤和排序候选项

#### 3.4 `ConvertTo-PublicRouteCustomMetadata`
- **目的**: 转换为公共路由自定义元数据
- **逻辑**: 过滤和格式化内部元数据为公共可见格式

#### 3.5 `ConvertTo-PublicAdmittedCandidates`
- **目的**: 转换为公共已接纳候选列表
- **逻辑**: 
  1. 过滤可用的候选项
  2. 提取 pack_id, skill, authority_tier, host_capable
  3. 返回规范化的候选列表

#### 3.6 `ConvertTo-PublicRoutePackRow`
- **目的**: 转换为公共路由包行
- **逻辑**: 从内部包行数据结构提取公共字段

#### 3.7 `Get-AuthorityRouteDecision`（核心决策函数）
- **目的**: 权威路由决策
- **输入**:
  - `$Ranked` - 排序后的候选数组
  - `$TaskType` - 任务类型
  - `$RequestedCanonical` - 显式请求的技能
  - `$AuthorityPolicy` - 权威策略对象
- **逻辑**:
  1. **空候选处理**: 如果无候选，返回空决策
  2. **显式请求优先**: 如果用户显式请求技能，直接选择
  3. **权威资格检查**: 如果顶部候选有权威资格（`authority_eligible=true`），直接选择
  4. **降级处理**:
     - 检查任务类型的全局安全降级（`global_safe_fallback_by_task`）
     - 或使用顶部候选的 `fallback_owner_pack_id` / `fallback_owner_skill`
  5. **Broad Owner 兜底**: 如果没有降级目标，选择第一个 `authority_tier=broad_owner` 的候选
  6. 返回决策对象，包含：
     - `selected_pack_id` - 选中的包 ID
     - `selected_skill` - 选中的技能
     - `selected_row` - 选中的行对象
     - `fallback_applied` - 是否应用了降级
     - `fallback_target_pack_id` / `fallback_target_skill` - 降级目标
     - `pre_fallback_top_pack_id` / `pre_fallback_top_skill` - 降级前的顶部候选
     - `rejected_specialist_reasons` - 拒绝专家的原因列表

### 4. 主执行流程

脚本的主流程（从模块加载后开始）：

1. **参数解析与验证**
   - 解析 Grade（M/L/XL）
   - 解析 TaskType
   - 加载配置文件和策略

2. **路由规则匹配**
   - 调用各个覆盖模块（overlay）进行规则匹配
   - 例如：GSD、prompt、memory、data-scale、quality-debt 等

3. **候选排序与过滤**
   - 根据优先级、权威层级（authority_tier）、主机能力排序
   - 过滤不可用的候选

4. **权威决策**
   - 调用 `Get-AuthorityRouteDecision` 做最终决策
   - 应用降级逻辑（如果需要）

5. **确认 UI 构建**（如果需要）
   - 检查是否需要用户确认（`confirm_required`）
   - 构建确认选项和澄清问题

6. **可观测性记录**
   - 写入路由事件日志
   - 写入探测工件（如果启用探测模式）

7. **输出结果**
   - 构建结果对象（包含 selected_pack_id, selected_skill, route_mode 等）
   - 转换为 JSON 输出（深度 12）

### 5. 输出格式

脚本输出一个 JSON 对象，包含以下关键字段：
```json
{
  "selected_pack_id": "string",
  "selected_skill": "string",
  "route_mode": "direct|skill|confirm_required",
  "grade": "M|L|XL",
  "task_type": "string",
  "authority_decision": {
    "selected_pack_id": "string",
    "selected_skill": "string",
    "fallback_applied": false,
    "fallback_target_pack_id": null,
    "rejected_specialist_reasons": []
  },
  "admitted_candidates": [...],
  "confirm_ui": {...},
  "retrieval": {...},
  "dialectic": {...},
  "observability": {...},
  "probe_reference": {...}
}
```

## Python 路由器对应关系

### 现有 Python 路由器功能对比

查看 `scripts/router/python_router.py` 可知，Python 路由器已实现：

1. ✅ **参数解析**: 支持 `--prompt`, `--grade`, `--task-type`, `--requested-skill` 等
2. ✅ **配置加载**: 从 `custom-skills.json` 加载配置
3. ✅ **Grade 推断**: `infer_grade()` 函数
4. ✅ **TaskType 推断**: `infer_task_type()` 函数
5. ✅ **技能匹配**: 基于触发器（triggers）和上下文（context）匹配
6. ✅ **优先级排序**: 按 priority 和 authority_tier 排序
7. ✅ **JSON 输出**: 标准 JSON 格式输出

### 缺失功能（需要补充）

1. ❌ **降级逻辑**: PowerShell 的 `global_safe_fallback_by_task` 和 `fallback_owner_pack_id`
2. ❌ **Broad Owner 兜底**: 当专家不可用时降级到 broad_owner
3. ❌ **确认 UI 构建**: PowerShell 的 `confirm_ui` 对象构建
4. ❌ **可观测性记录**: PowerShell 的详细日志和探测工件
5. ❌ **主机偏好**: `Get-PreferredHostSelection` 的主机偏好过滤
6. ⚠️ **覆盖模块**: PowerShell 加载 24 个模块，Python 只实现了基础路由

## 建议的迁移策略

### 阶段 1：增强 Python 路由器核心逻辑（当前任务）
- 实现降级逻辑（fallback）
- 实现 Broad Owner 兜底
- 完善输出格式（与 PowerShell 一致）

### 阶段 2：迁移关键覆盖模块
- 优先迁移：custom-admission, routing-rules, candidate-selection
- 次要迁移：confirm-ui, observability
- 可选迁移：各种 overlay 模块（按需迁移）

### 阶段 3：测试与验证
- 编写对比测试（PowerShell vs Python）
- 验证相同输入产生相同输出
- 性能测试（Python 应该更快）

### 阶段 4：切换默认路由器
- 修改 `router_bridge.py` 优先使用 Python
- PowerShell 作为回退选项
- 更新文档

## 关键发现

1. **PowerShell 路由器非常复杂**: 1910 行代码 + 24 个模块，完全迁移成本高
2. **核心逻辑可提取**: 80% 的实际使用场景只需要核心决策逻辑
3. **Python 路由器已有坚实基础**: 主要差距在降级和确认 UI
4. **建议增量迁移**: 先补齐核心差距，再逐步迁移高级特性

## 下一步

Task 2 将基于此分析，增强 Python 路由器以实现：
1. 降级逻辑（fallback_owner_pack_id, global_safe_fallback_by_task）
2. Broad Owner 兜底
3. 输出格式对齐（authority_decision 对象）

---
**文档版本**: v1.0  
**最后更新**: 2026-07-19
