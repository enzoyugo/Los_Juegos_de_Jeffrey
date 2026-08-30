from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_canonical_visual_proof_uses_a_scene_entrypoint() -> None:
    scene = (ROOT / "scenes/debug/JeffreyVisualProofV2Capture.tscn").read_text(encoding="utf-8")
    assert "JeffreyVisualProofV2Capture" in scene
    assert "JeffreyDeepPolishV1Capture.tscn" not in scene
    assert "script = ExtResource" in scene


def test_visual_proof_runner_is_project_context_only() -> None:
    runner = (ROOT / "scripts/debug/jeffrey_deep_polish_v1_capture.gd").read_text(encoding="utf-8")
    assert "canonical production-context proof runner" in runner.lower()
    assert "jeffrey_visual_proof_v2" in runner
    assert "JEFFREY_CAPTURE_SUCCESS" in runner
    assert "JEFFREY_CAPTURE_FAILURE" in runner


def test_visual_proof_outputs_are_1920x1080() -> None:
    runner = (ROOT / "scripts/debug/jeffrey_deep_polish_v1_capture.gd").read_text(encoding="utf-8")
    assert "DisplayServer.window_set_size(Vector2i(1920, 1080))" in runner
    assert "get_viewport().get_texture().get_image()" in runner
