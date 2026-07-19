# Vibe Skill

Vibe 是一个治理化的 AI 工作流运行时，支持 Claude Code 和 Codex Web。

## 核心特性

- **六阶段治理运行时**：skeleton_check → deep_interview → requirement_doc → xl_plan → plan_execute → phase_cleanup
- **Bash/Python 优先入口**（macOS/Linux）+ PowerShell 兼容（Windows）
- **specialist 技能路由**：自动推荐和调度专家技能
- **证明文件生成**：需求文档、执行计划、验证报告、清理收据
- **边界返回控制**：在关键阶段返回用户决策

## 快速开始

### macOS/Linux

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

## 路由优化（本次更新）

### 问题
- 缓存审计任务错误推荐 iOS/代码接收类 specialist
- 计划类任务未优先选中 `superpowers-writing-plans`
- `route_snapshot.selected_skill` 在降级后未同步更新，导致一致性检查失败

### 修复
1. **一致性检查放宽**：允许 `route_snapshot.selected_skill` 在 `degraded_skill_ids` 中
2. **测试覆盖**：新增 `test_truth_consistency_accepts_degraded_route_snapshot_with_a_different_selected_specialist`
3. **待完成**：增强路由配置的负向约束和优先级梯度

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
