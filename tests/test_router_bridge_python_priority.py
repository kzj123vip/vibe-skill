#!/usr/bin/env python3
"""
测试路由器桥接优先级：Python 优先，PowerShell 回退
"""
import json
import subprocess
import sys
from pathlib import Path

# 添加包路径
repo_root = Path(__file__).parent.parent
sys.path.insert(0, str(repo_root / 'packages' / 'runtime-core' / 'src'))

from vgo_runtime.router_bridge import resolve_powershell_host, main as router_bridge_main


def test_python_router_priority_when_available():
    """测试：Python 路由器可用时应该优先使用"""
    # 即使 PowerShell 可用，也应该优先使用 Python
    result = subprocess.run(
        [
            sys.executable,
            str(repo_root / 'packages' / 'runtime-core' / 'src' / 'vgo_runtime' / 'router_bridge.py'),
            '--prompt', '帮我实现一个功能',
            '--grade', 'M',
            '--task-type', 'coding',
        ],
        capture_output=True,
        text=True,
        cwd=repo_root,
    )

    assert result.returncode == 0, f"路由器执行失败: {result.stderr}"

    output = json.loads(result.stdout)

    # 验证使用了 Python 路由器
    bridge_info = output.get('runtime_neutral_bridge', {})
    assert bridge_info.get('engine') == 'python', \
        f"应该使用 Python 引擎，实际使用: {bridge_info.get('engine')}"
    assert bridge_info.get('host') == 'runtime_neutral', \
        f"应该标记为 runtime_neutral，实际: {bridge_info.get('host')}"

    print("✅ 测试通过：Python 路由器优先使用")


def test_powershell_fallback_when_forced():
    """测试：当强制使用 PowerShell 时，应该回退到 PowerShell"""
    pwsh = resolve_powershell_host()
    if not pwsh:
        print("⚠️  跳过测试：PowerShell 未安装")
        return

    # 不使用 --force-runtime-neutral，让它选择 PowerShell
    result = subprocess.run(
        [
            sys.executable,
            str(repo_root / 'packages' / 'runtime-core' / 'src' / 'vgo_runtime' / 'router_bridge.py'),
            '--prompt', '帮我实现一个功能',
            '--grade', 'M',
            '--task-type', 'coding',
        ],
        capture_output=True,
        text=True,
        cwd=repo_root,
        env={'VIBE_PREFER_POWERSHELL': '1'},  # 环境变量控制
    )

    assert result.returncode == 0, f"路由器执行失败: {result.stderr}"

    output = json.loads(result.stdout)

    # 如果 PowerShell 可用且设置了环境变量，应该使用 PowerShell
    # 但这个测试在新架构下会失败，因为我们要改为 Python 优先
    print("⚠️  当前架构：需要修改 router_bridge.py 以支持 Python 优先")


def test_python_router_output_format():
    """测试：Python 路由器输出格式完整性"""
    result = subprocess.run(
        [
            sys.executable,
            str(repo_root / 'packages' / 'runtime-core' / 'src' / 'vgo_runtime' / 'router_bridge.py'),
            '--prompt', '帮我调试这个问题',
            '--grade', 'L',
            '--task-type', 'debug',
            '--force-runtime-neutral',
        ],
        capture_output=True,
        text=True,
        cwd=repo_root,
    )

    assert result.returncode == 0, f"路由器执行失败: {result.stderr}"

    output = json.loads(result.stdout)

    # 验证关键字段存在
    required_fields = [
        'prompt', 'grade', 'task_type', 'route_mode', 'route_reason',
        'confidence', 'selected', 'ranked', 'fallback_applied',
        'runtime_neutral_bridge', 'custom_admission'
    ]

    for field in required_fields:
        assert field in output, f"缺少必需字段: {field}"

    print("✅ 测试通过：Python 路由器输出格式完整")


if __name__ == '__main__':
    print("\n=== 测试路由器桥接优先级 ===\n")

    # 测试 1：Python 优先（当前会失败，因为还是 PowerShell 优先）
    try:
        test_python_router_priority_when_available()
    except AssertionError as e:
        print(f"❌ 测试失败（预期）: {e}")
        print("   原因：当前 router_bridge.py 仍优先使用 PowerShell\n")

    # 测试 2：PowerShell 回退
    test_powershell_fallback_when_forced()
    print()

    # 测试 3：输出格式（使用 --force-runtime-neutral 强制 Python）
    test_python_router_output_format()

    print("\n=== 测试完成 ===\n")
    print("下一步：修改 router_bridge.py，实现 Python 优先策略")
