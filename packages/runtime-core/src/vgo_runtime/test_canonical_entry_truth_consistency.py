import json
from pathlib import Path

from vgo_runtime.canonical_entry import (
    HostLaunchReceipt,
    _resolve_progressive_requested_stage_stop,
    assert_minimum_truth_consistency,
)
from vgo_runtime.governance import normalize_runtime_mode


REPO_ROOT = Path(__file__).resolve().parents[4]


def test_explicit_phase_cleanup_stop_runs_through_all_governed_stages():
    assert _resolve_progressive_requested_stage_stop(
        repo_root=REPO_ROOT,
        entry_id="vibe",
        requested_stage_stop="phase_cleanup",
        bounded_reentry=None,
    ) == "phase_cleanup"


def test_default_stage_stop_runs_through_phase_cleanup():
    assert _resolve_progressive_requested_stage_stop(
        repo_root=REPO_ROOT,
        entry_id="vibe",
        requested_stage_stop=None,
        bounded_reentry=None,
    ) == "phase_cleanup"

    assert normalize_runtime_mode("approved_continuous_governed") == "approved_continuous_governed"


def test_truth_consistency_accepts_degraded_route_snapshot_with_a_different_selected_specialist(tmp_path):
    runtime_packet = {
        "host_id": "codex",
        "mode": "approved_continuous_governed",
        "entry_intent_id": "vibe",
        "requested_stage_stop": "phase_cleanup",
        "canonical_router": {"host_id": "codex", "requested_skill": "vibe"},
        "route_snapshot": {"selected_skill": "github", "confirm_required": False},
        "skill_routing": {"selected": [{"skill_id": "skill-creator"}]},
        "specialist_decision": {
            "decision_state": "approved_dispatch",
            "resolution_mode": "approved_dispatch",
            "degraded_skill_ids": ["github"],
        },
        "divergence_shadow": {
            "runtime_selected_skill": "vibe",
            "router_selected_skill": "github",
        },
    }
    governance_capsule = {"runtime_selected_skill": "vibe"}
    stage_lineage = {"stages": [{"stage_name": "phase_cleanup"}]}
    packet_path = tmp_path / "runtime-input-packet.json"
    capsule_path = tmp_path / "governance-capsule.json"
    lineage_path = tmp_path / "stage-lineage.json"
    packet_path.write_text(json.dumps(runtime_packet), encoding="utf-8")
    capsule_path.write_text(json.dumps(governance_capsule), encoding="utf-8")
    lineage_path.write_text(json.dumps(stage_lineage), encoding="utf-8")

    receipt = HostLaunchReceipt(
        host_id="codex",
        entry_id="vibe",
        launch_mode="canonical-entry",
        launcher_path="launcher",
        requested_stage_stop="phase_cleanup",
        requested_grade_floor=None,
        runtime_entrypoint="runtime",
        run_id="run-test",
        created_at="2026-07-19T00:00:00Z",
        launch_status="launched",
    )

    assert_minimum_truth_consistency(
        receipt=receipt,
        requested_entry_id="vibe",
        runtime_packet_path=packet_path,
        governance_capsule_path=capsule_path,
        stage_lineage_path=lineage_path,
    )

    runtime_packet = {
        "host_id": "codex",
        "entry_intent_id": "vibe",
        "requested_stage_stop": "phase_cleanup",
        "canonical_router": {"host_id": "codex", "requested_skill": "vibe"},
        "route_snapshot": {"selected_skill": "unavailable-skill", "confirm_required": False},
        "skill_routing": {"selected": []},
        "specialist_decision": {
            "decision_state": "degraded",
            "resolution_mode": "degraded",
        },
        "divergence_shadow": {
            "runtime_selected_skill": "vibe",
            "router_selected_skill": "unavailable-skill",
        },
    }
    governance_capsule = {"runtime_selected_skill": "vibe"}
    stage_lineage = {"stages": [{"stage_name": "phase_cleanup"}]}
    packet_path = tmp_path / "runtime-input-packet.json"
    capsule_path = tmp_path / "governance-capsule.json"
    lineage_path = tmp_path / "stage-lineage.json"
    packet_path.write_text(json.dumps(runtime_packet), encoding="utf-8")
    capsule_path.write_text(json.dumps(governance_capsule), encoding="utf-8")
    lineage_path.write_text(json.dumps(stage_lineage), encoding="utf-8")

    receipt = HostLaunchReceipt(
        host_id="codex",
        entry_id="vibe",
        launch_mode="canonical-entry",
        launcher_path="launcher",
        requested_stage_stop="phase_cleanup",
        requested_grade_floor=None,
        runtime_entrypoint="runtime",
        run_id="run-test",
        created_at="2026-07-19T00:00:00Z",
        launch_status="launched",
    )

    assert_minimum_truth_consistency(
        receipt=receipt,
        requested_entry_id="vibe",
        runtime_packet_path=packet_path,
        governance_capsule_path=capsule_path,
        stage_lineage_path=lineage_path,
    )

    runtime_packet = {
        "host_id": "codex",
        "entry_intent_id": "vibe-do-it",
        "requested_stage_stop": "skeleton_check",
        "canonical_router": {"host_id": "codex", "requested_skill": None},
        "route_snapshot": {"selected_skill": None, "confirm_required": True},
        "skill_routing": {"selected": []},
        "specialist_decision": {
            "decision_state": "no_specialist_recommendations",
            "resolution_mode": "no_matching_specialist",
        },
        "divergence_shadow": {
            "runtime_selected_skill": "vibe",
            "router_selected_skill": None,
        },
    }
    governance_capsule = {"runtime_selected_skill": "vibe"}
    stage_lineage = {"stages": [{"stage_name": "skeleton_check"}]}
    packet_path = tmp_path / "runtime-input-packet.json"
    capsule_path = tmp_path / "governance-capsule.json"
    lineage_path = tmp_path / "stage-lineage.json"
    packet_path.write_text(json.dumps(runtime_packet), encoding="utf-8")
    capsule_path.write_text(json.dumps(governance_capsule), encoding="utf-8")
    lineage_path.write_text(json.dumps(stage_lineage), encoding="utf-8")

    receipt = HostLaunchReceipt(
        host_id="codex",
        entry_id="vibe",
        launch_mode="canonical-entry",
        launcher_path="launcher",
        requested_stage_stop="skeleton_check",
        requested_grade_floor=None,
        runtime_entrypoint="runtime",
        run_id="run-test",
        created_at="2026-07-12T00:00:00Z",
        launch_status="launched",
    )

    assert_minimum_truth_consistency(
        receipt=receipt,
        requested_entry_id="vibe-do-it",
        runtime_packet_path=packet_path,
        governance_capsule_path=capsule_path,
        stage_lineage_path=lineage_path,
    )
