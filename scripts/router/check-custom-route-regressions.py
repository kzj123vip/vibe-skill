#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
RUNTIME_SRC = REPO_ROOT / "packages" / "runtime-core" / "src"
if str(RUNTIME_SRC) not in sys.path:
    sys.path.insert(0, str(RUNTIME_SRC))

from vgo_runtime.router_contract_runtime import route_prompt


CASES = [
    {
        "name": "openai-docs",
        "prompt": "OpenAI API 最新模型怎么用，查官方文档",
        "task_type": "planning",
        "expected_skill": "openai-docs",
    },
    {
        "name": "image-cards",
        "prompt": "帮我做一组小红书图片卡片",
        "task_type": "planning",
        "expected_skill": "baoyu-image-cards",
    },
    {
        "name": "excel",
        "prompt": "创建一个带公式和格式的 Excel 预算表",
        "task_type": "planning",
        "expected_skill": "wps-xlsx",
    },
    {
        "name": "docx",
        "prompt": "生成一个 Word 文档 .docx 报告",
        "task_type": "planning",
        "expected_skill": "wps-docx",
    },
    {
        "name": "pdf",
        "prompt": "读取 PDF 里的表格并合并两个 PDF 文件",
        "task_type": "planning",
        "expected_skill": "wps-pdf",
    },
    {
        "name": "debug",
        "prompt": "debug runtime logs api failure stack trace 故障定位",
        "task_type": "debug",
        "expected_skill": "systematic-debugging",
    },
    {
        "name": "latex",
        "prompt": "帮我把 LaTeX 论文编译并准备 submission zip",
        "task_type": "planning",
        "expected_skill": "latex-submission-pipeline",
    },
]


def _selected(result: dict[str, Any]) -> dict[str, Any]:
    selected = result.get("selected")
    return selected if isinstance(selected, dict) else {}


def _custom_admission(result: dict[str, Any]) -> dict[str, Any]:
    admission = result.get("custom_admission")
    return admission if isinstance(admission, dict) else {}


def main() -> int:
    parser = argparse.ArgumentParser(description="Check Vibe custom route regressions.")
    parser.add_argument("--target-root", default=str(Path.home() / ".codex-cli"))
    parser.add_argument("--host-id", default="codex")
    parser.add_argument("--grade", default="M")
    parser.add_argument("--max-result-bytes", type=int, default=50000)
    args = parser.parse_args()

    rows: list[dict[str, Any]] = []
    failures: list[str] = []
    admission_health: dict[str, Any] | None = None

    for case in CASES:
        result = route_prompt(
            prompt=case["prompt"],
            grade=args.grade,
            task_type=case["task_type"],
            host_id=args.host_id,
            target_root=args.target_root,
        )
        selected = _selected(result)
        admission = _custom_admission(result)
        if admission_health is None:
            admitted_candidates = admission.get("admitted_candidates") or []
            admission_health = {
                "status": admission.get("status"),
                "invalid_entries": len(admission.get("invalid_entries") or []),
                "dependency_failures": len(admission.get("dependency_failures") or []),
                "admitted_candidate_count": admission.get("admitted_candidate_count"),
                "admitted_candidates_truncated": admission.get("admitted_candidates_truncated"),
                "listed_admitted_candidates": len(admitted_candidates),
            }

        result_bytes = len(json.dumps(result, ensure_ascii=False).encode("utf-8"))
        skill = selected.get("skill")
        ok = skill == case["expected_skill"] and result_bytes <= args.max_result_bytes
        if not ok:
            failures.append(str(case["name"]))

        rows.append(
            {
                "case": case["name"],
                "expected_skill": case["expected_skill"],
                "skill": skill,
                "pack_id": selected.get("pack_id"),
                "route_reason": result.get("route_reason"),
                "candidate_signal": selected.get("candidate_signal"),
                "result_bytes": result_bytes,
                "ok": ok,
            }
        )

    if admission_health is None:
        failures.append("custom_admission_missing")
    else:
        if admission_health["invalid_entries"] != 0:
            failures.append("custom_admission_invalid_entries")
        if admission_health["dependency_failures"] != 0:
            failures.append("custom_admission_dependency_failures")
        if admission_health["listed_admitted_candidates"] > 12:
            failures.append("custom_admission_public_rows_not_truncated")
        if admission_health["admitted_candidate_count"] and admission_health["admitted_candidate_count"] > 12:
            if not admission_health["admitted_candidates_truncated"]:
                failures.append("custom_admission_truncation_flag_missing")

    payload = {
        "ok": not failures,
        "failures": failures,
        "admission_health": admission_health,
        "cases": rows,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
