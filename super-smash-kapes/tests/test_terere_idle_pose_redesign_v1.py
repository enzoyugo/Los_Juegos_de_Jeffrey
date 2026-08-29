'''Tereré Idle Pose Redesign V1. Static canonical poses only. Jaguareté frozen.'''

from pathlib import Path
import hashlib
import json


PROJECT_ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = (
    "game_ready_v4",
    "game_ready_v3",
    "semantic_solver_v2",
    "solver_v1",
    "actorcore_benchmark",
    "native_skin_audit",
)
V4 = {
    "terere": "D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE",
    "jaguarete": "460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C",
}
CLEAN_RIG = {
    "terere": "2e5fa018e55852052e3f595b8b6cf2756ed136d755cfe22b198c50136ef768ed",
    "jaguarete": "cafa9f55dafcc2229c6f48ca17635a1febb4b26f1f53baae3dd3591b30549742",
}
POSES = ("POSE_A", "POSE_B", "POSE_C")


def _read(rel):
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _json(rel):
    return json.loads(_read(rel))


def _sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def test_three_static_pose_outputs_exist_and_differ():
    hashes = set()
    baseline = PROJECT_ROOT / "assets/fighters/processed/idle_benchmark_v1/terere/terere_idle_semantic_clean_v1.glb"
    hashes.add(_sha256(baseline))
    for suffix in ("a", "b", "c"):
        glb = PROJECT_ROOT / "assets/fighters/processed/idle_pose_redesign_v1/terere" / (
            "terere_idle_pose_redesign_v1_%s.glb" % suffix
        )
        assert glb.is_file(), glb
        digest = _sha256(glb)
        assert digest not in hashes
        hashes.add(digest)


def test_same_clean_rig_authority():
    base = _json("docs/generated/SEMANTIC_IDLE_POLISH_V1_BASELINE.json")
    for fighter, digest in CLEAN_RIG.items():
        glb = PROJECT_ROOT / "assets/fighters/processed/clean_rig_v1" / fighter / (
            "%s_clean_rig_v1.glb" % fighter
        )
        assert _sha256(glb) == digest
        assert _sha256(base["files"]["%s_clean_rig_glb" % fighter]["path"]) == digest


def test_no_animation_required():
    run = _json("docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_RUN.json")
    metrics = _json("docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_METRICS.json")
    assert metrics["animation_baked"] is False
    baker = _read("tools/blender/terere_idle_pose_redesign_v1.py")
    assert "Idle.fbx" not in baker
    assert "canonical_pose" in baker
    lab = _read("scripts/debug/terere_idle_pose_redesign_v1_lab.gd")
    assert "STATIC" in lab
    assert "player.play(idle)" not in lab
    assert run["wired_into_battle"] is False


def test_101_bones_zero_extreme_verts_stable_limbs():
    run = _json("docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_RUN.json")
    assert run["auto_selected_candidate"] is None
    for pose in POSES:
        row = run["poses"][pose]
        metrics = _json("docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_%s_METRICS.json" % pose[-1])
        rt = _json("docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_%s_ROUNDTRIP.json" % pose[-1])
        assert row["roundtrip_bones"] == 101
        assert rt["bone_count"] == 101
        assert metrics["max_extreme_verts"] == 0
        assert metrics["max_limb_length_rel_error"] == 0.0
        assert metrics["pose_classification"] == "STANDING_IDLE"
        assert metrics["technical_pass"] is True
        assert metrics["legacy_axis_hack"] is False
        assert metrics["copies_raw_mixamo_quaternion"] is False
        assert metrics["runtime_retarget"] is False
        assert metrics["animation"] is False


def test_correct_terere_textures_and_no_legacy_axis():
    for pose in ("A", "B", "C"):
        metrics = _json("docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_%s_METRICS.json" % pose)
        textures = metrics["texture_authority"]
        assert textures
        blob = json.dumps(textures).lower()
        assert "terere" in blob
        assert "model_pbr_diffuse" in blob or "diffuse" in blob
        assert metrics["legacy_axis_hack"] is False
    baker = _read("tools/blender/terere_idle_pose_redesign_v1.py")
    assert "legacy_axis" in baker


def test_authored_poses_are_not_micro_sweeps():
    metrics = _json("docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_METRICS.json")
    ops = {pose: metrics["poses"][pose]["standing_ops"] for pose in POSES}
    base = _json("docs/generated/TERERE_IDLE_SEMANTIC_CLEAN_V1_METRICS.json")["standing_ops"]
    for pose in POSES:
        ua_l = ops[pose]["CC_Base_L_Upperarm"]
        ua_base = base["CC_Base_L_Upperarm"]
        assert abs(ua_l["secondary"]) >= 10.0
        assert abs(ua_l["primary"] - ua_base["primary"]) >= 4.0 or abs(ua_l["secondary"] - ua_base.get("secondary", 0.0)) >= 10.0
    pairs = [("POSE_A", "POSE_B"), ("POSE_B", "POSE_C"), ("POSE_A", "POSE_C")]
    for left, right in pairs:
        l_ops = ops[left]
        r_ops = ops[right]
        delta = abs(l_ops["CC_Base_L_Upperarm"]["primary"] - r_ops["CC_Base_L_Upperarm"]["primary"])
        delta += abs(l_ops["CC_Base_L_Upperarm"]["secondary"] - r_ops["CC_Base_L_Upperarm"]["secondary"])
        delta += abs(l_ops["CC_Base_L_Forearm"]["primary"] - r_ops["CC_Base_L_Forearm"]["primary"])
        assert delta >= 6.0, (left, right, delta)


def test_lab_is_isolated_and_static():
    tscn = _read("scenes/debug/TerereIdlePoseRedesignV1Lab.tscn")
    gd = _read("scripts/debug/terere_idle_pose_redesign_v1_lab.gd")
    assert "TERERE_IDLE_POSE_REDESIGN_V1" in tscn
    assert "TERERÉ IDLE POSE REDESIGN" in gd or "TERERE IDLE POSE REDESIGN" in gd or "TERERÉ IDLE POSE REDESIGN" in tscn
    assert 'extends "res://scripts/debug/actorcore_animation_lab.gd"' not in gd
    assert 'extends "res://scripts/debug/production_animation_lab.gd"' not in gd
    assert 'extends "res://scripts/debug/semantic_solver_v2_lab.gd"' not in gd
    assert "actorcore_animation_lab" not in tscn
    assert "production_animation_lab" not in tscn
    assert "semantic_solver_v2_lab" not in tscn
    assert "fighter_catalog.gd" not in tscn
    assert "fighter_catalog.gd" not in gd
    assert "terere_game_ready_v4.glb" not in tscn
    assert "jaguarete_game_ready_v4.glb" not in tscn
    for token in FORBIDDEN:
        assert token not in tscn
    assert "idle_semantic_clean_v1.glb" in tscn
    assert "terere_idle_pose_redesign_v1_a.glb" in tscn
    assert "terere_idle_pose_redesign_v1_b.glb" in tscn
    assert "terere_idle_pose_redesign_v1_c.glb" in tscn
    assert "ModelSlot" in tscn
    assert "Camera3D" in tscn
    assert ".look_at(" not in gd
    assert "player.pause()" in gd
    assert "_restore_camera" in gd


def test_actorcore_lab_look_at_is_after_add_child():
    src = _read("scripts/debug/actorcore_animation_lab.gd")
    add_idx = src.find("add_child(cam)")
    look_idx = src.find("cam.look_at(")
    assert add_idx != -1 and look_idx != -1
    assert add_idx < look_idx



def test_contact_sheet_and_metrics_exist():
    sheet = PROJECT_ROOT / "docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_CONTACT_SHEET.png"
    assert sheet.is_file()
    assert sheet.stat().st_size > 10000
    metrics = _json("docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_METRICS.json")
    assert metrics["auto_selected_candidate"] is None
    for pose in POSES:
        sil = metrics["poses"][pose]["silhouette"]
        for key in (
            "shoulder_width",
            "L_hand_to_torso",
            "R_hand_to_torso",
            "L_hand_height",
            "R_hand_height",
            "L_elbow_flex",
            "R_elbow_flex",
            "L_upperarm_down_from_horizontal",
            "R_upperarm_down_from_horizontal",
            "spine_from_up_deg",
            "L_knee_flex",
            "R_knee_flex",
            "center_of_mass_xz",
        ):
            assert key in sil


def test_jaguarete_authority_unchanged():
    freeze = _json("docs/generated/JAGUARETE_IDLE_APPROVED_AUTHORITY.json")
    old = _json("docs/generated/JAGUARETE_SEMANTIC_IDLE_APPROVED_V1.json")
    glb = Path(freeze["glb"])
    assert glb.is_file()
    digest = _sha256(glb)
    assert digest == freeze["glb_sha256"]
    assert digest == old["glb_sha256"]
    assert freeze["status"] == "HUMAN_APPROVED_PENDING_PRODUCTION_INTEGRATION"
    assert freeze["animation_name"] == "idle"
    assert freeze["bone_count"] == 101
    assert freeze["do_not_rebake"] is True
    baker = _read("tools/blender/terere_idle_pose_redesign_v1.py")
    assert "do not touch Jaguareté" in baker.lower() or "does not touch Jaguareté" in baker.lower() or "Does not touch Jaguareté" in baker
    run = _json("docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_RUN.json")
    assert run["jaguarete_rebaked"] is False


def test_production_v4_and_catalog_untouched():
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert 'pipeline_id = "ACTORCORE_V4"' in catalog
    for fighter, digest in V4.items():
        glb = PROJECT_ROOT / "assets/fighters/processed" / fighter / ("%s_game_ready_v4.glb" % fighter)
        assert hashlib.sha256(glb.read_bytes()).hexdigest().upper() == digest
