from pathlib import Path


LEDGER = Path("docs/one-tap-logging-quality-ledger.md")


def test_one_tap_quality_ledger_has_at_least_100_verified_entries() -> None:
    text = LEDGER.read_text(encoding="utf-8")
    entries = [line for line in text.splitlines() if line.startswith("- [x] Q")]

    assert len(entries) >= 100


def test_one_tap_quality_ledger_entries_are_evidence_backed() -> None:
    text = LEDGER.read_text(encoding="utf-8")
    entries = [line for line in text.splitlines() if line.startswith("- [x] Q")]

    assert entries
    for entry in entries:
        assert " | Evidence: " in entry
        assert " | Fix: " in entry
        assert " | Verification: " in entry
        assert "TODO" not in entry
        assert "[ ]" not in entry
