#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

from .powershell_bridge import run_powershell_json_command
from .router_contract_runtime import route_prompt
from .router_contract_support import resolve_repo_root


def resolve_powershell_host() -> str | None:
    candidates = [
        shutil.which('pwsh'),
        shutil.which('pwsh.exe'),
        shutil.which('powershell'),
        shutil.which('powershell.exe'),
    ]
    for candidate in candidates:
        if candidate and Path(candidate).exists():
            return str(Path(candidate))
    return None


def invoke_canonical_router(args: argparse.Namespace, shell: str) -> dict:
    repo_root = resolve_repo_root(Path(__file__))
    script_path = repo_root / 'scripts' / 'router' / 'resolve-pack-route.ps1'
    command = [
        shell,
        '-NoLogo',
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        str(script_path),
        '-Prompt',
        args.prompt,
        '-Grade',
        args.grade,
        '-TaskType',
        args.task_type,
    ]
    if args.requested_skill:
        command.extend(['-RequestedSkill', args.requested_skill])
    if args.entry_intent_id:
        command.extend(['-EntryIntentId', args.entry_intent_id])
    if args.requested_grade_floor:
        command.extend(['-RequestedGradeFloor', args.requested_grade_floor])
    if args.host_id:
        command.extend(['-HostId', args.host_id])
    if args.target_root:
        command.extend(['-TargetRoot', args.target_root])
    return run_powershell_json_command(command, cwd=repo_root, bridge_label="canonical router bridge")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Host-neutral VCO router entrypoint.')
    parser.add_argument('--prompt', required=True)
    parser.add_argument('--grade', default='M', choices=['M', 'L', 'XL'])
    parser.add_argument('--task-type', default='planning', choices=['planning', 'coding', 'review', 'debug', 'research'])
    parser.add_argument('--requested-skill')
    parser.add_argument('--entry-intent-id')
    parser.add_argument('--requested-grade-floor', choices=['L', 'XL'])
    parser.add_argument('--host-id')
    parser.add_argument('--target-root')
    parser.add_argument('--force-runtime-neutral', action='store_true')
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])

    # 新策略：Python 优先，PowerShell 仅作兼容回退
    # 触发 PowerShell 回退的条件：
    # 1. 设置环境变量 VIBE_USE_POWERSHELL=1（显式要求）
    # 2. 或 --force-powershell 命令行参数（待实现）
    use_powershell = (
        not args.force_runtime_neutral
        and os.environ.get('VIBE_USE_POWERSHELL', '').strip() in ('1', 'true', 'True', 'TRUE')
    )

    shell = resolve_powershell_host() if use_powershell else None

    if shell:
        # PowerShell 回退路径（仅当显式请求时）
        payload = invoke_canonical_router(args, shell)
    else:
        # 默认路径：使用 Python 路由器（macOS/Linux 友好）
        payload = route_prompt(
            prompt=args.prompt,
            grade=args.grade,
            task_type=args.task_type,
            requested_skill=args.requested_skill,
            entry_intent_id=args.entry_intent_id,
            requested_grade_floor=args.requested_grade_floor,
            target_root=args.target_root,
            host_id=args.host_id,
            repo_root=resolve_repo_root(Path(__file__)),
        )

    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write('\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
