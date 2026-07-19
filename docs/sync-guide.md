# 本地 Vibe 技能与远程仓库同步指南

## 当前配置状态 ✅

**本地目录**：`/Users/kzj/.cc-switch/skills/vibe`  
**远程仓库**：`https://github.com/kzj123vip/vibe-skill`  
**当前分支**：`main`  
**同步状态**：已对齐到 commit `0ab2070`

## 工作流程

### 1. 当远程仓库有更新时（拉取）

```bash
cd ~/.cc-switch/skills/vibe
git pull origin main
```

**效果**：远程的路由配置优化、bug 修复、新功能会自动同步到本地技能目录

### 2. 当本地有修改时（推送）

```bash
cd ~/.cc-switch/skills/vibe

# 查看修改
git status

# 添加修改的文件
git add <文件路径>

# 提交
git commit -m "描述你的修改"

# 推送到远程
git push origin main
```

**效果**：本地的改进会上传到 GitHub，其他设备或用户可以获取

### 3. 检查同步状态

```bash
cd ~/.cc-switch/skills/vibe

# 查看本地与远程的差异
git status

# 查看提交历史
git log --oneline -5

# 查看远程配置
git remote -v
```

## 自动同步脚本（可选）

如果希望每次使用 Vibe 前自动检查更新，可以创建别名：

```bash
# 添加到 ~/.zshrc 或 ~/.bashrc
alias vibe-update='cd ~/.cc-switch/skills/vibe && git pull origin main --quiet && cd -'
```

使用方法：
```bash
vibe-update  # 每次使用前运行一次
```

## 常见场景

### 场景1：远程有新的路由优化，想同步到本地

```bash
cd ~/.cc-switch/skills/vibe
git pull origin main
```

### 场景2：本地修改了配置，想分享到 GitHub

```bash
cd ~/.cc-switch/skills/vibe
git add config/
git commit -m "优化路由配置"
git push origin main
```

### 场景3：在另一台 Mac 上使用同样的配置

```bash
# 在新机器上
cd ~/.cc-switch/skills/
rm -rf vibe  # 如果已存在旧版本
git clone https://github.com/kzj123vip/vibe-skill.git vibe
```

### 场景4：查看远程是否有更新（不实际拉取）

```bash
cd ~/.cc-switch/skills/vibe
git fetch origin
git log HEAD..origin/main --oneline
```

## 注意事项

### ⚠️ 运行产物不会同步

以下目录已通过 `.gitignore` 排除，不会上传到 GitHub：
- `outputs/`（运行证据）
- `.vibeskills/`（运行时缓存）
- `.tmp/`（临时文件）
- `.pytest_cache/`（测试缓存）
- `bundled/`（私有技能包）

### ⚠️ 配置文件同步

**会同步**：
- `config/` 目录下的所有 JSON 配置
- `SKILL.md`（技能入口）
- `docs/`（文档）
- `packages/`、`apps/`、`scripts/`（源码）

**不会同步**：
- `~/.codex/config/custom-skills.json`（这是 Codex 全局配置，不在 Vibe 目录内）

### ⚠️ 修改冲突处理

如果本地和远程都有修改导致冲突：

```bash
cd ~/.cc-switch/skills/vibe
git pull origin main
# 如果提示冲突，手动编辑冲突文件
# 编辑完成后
git add <冲突文件>
git commit -m "解决合并冲突"
git push origin main
```

## 验证配置

```bash
cd ~/.cc-switch/skills/vibe

# 应该看到
git remote -v
# origin  https://github.com/kzj123vip/vibe-skill.git (fetch)
# origin  https://github.com/kzj123vip/vibe-skill.git (push)

git branch -vv
# * main 0ab2070 优化路由策略：提升计划类技能优先级

git status
# On branch main
# nothing to commit, working tree clean
```

## 相关文档

- [路由配置指南](./docs/routing-configuration.md)
- [GitHub 仓库](https://github.com/kzj123vip/vibe-skill)
- [Vibe 技能入口](./SKILL.md)
