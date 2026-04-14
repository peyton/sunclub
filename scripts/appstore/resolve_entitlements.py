from __future__ import annotations

import argparse
import plistlib
import re
import sys
from pathlib import Path
from typing import Any


PLACEHOLDER_RE = re.compile(r"\$\(([^)]+)\)")


def _parse_replacements(values: list[str]) -> dict[str, str]:
    replacements: dict[str, str] = {}
    for value in values:
        if "=" not in value:
            raise ValueError(f"Invalid replacement '{value}'. Expected KEY=VALUE.")
        key, replacement = value.split("=", 1)
        if not key:
            raise ValueError("Replacement keys must not be empty.")
        replacements[key] = replacement
    return replacements


def _resolve_value(value: Any, replacements: dict[str, str], missing: set[str]) -> Any:
    if isinstance(value, str):

        def replace(match: re.Match[str]) -> str:
            key = match.group(1)
            if key not in replacements:
                missing.add(key)
                return match.group(0)
            return replacements[key]

        return PLACEHOLDER_RE.sub(replace, value)

    if isinstance(value, list):
        return [_resolve_value(item, replacements, missing) for item in value]

    if isinstance(value, dict):
        return {
            key: _resolve_value(item, replacements, missing)
            for key, item in value.items()
        }

    return value


def resolve_entitlements(
    source_path: Path,
    output_path: Path,
    replacements: dict[str, str],
) -> None:
    with source_path.open("rb") as source_file:
        entitlements = plistlib.load(source_file)

    missing: set[str] = set()
    resolved = _resolve_value(entitlements, replacements, missing)
    if missing:
        missing_names = ", ".join(sorted(missing))
        raise ValueError(f"Unresolved entitlement placeholder(s): {missing_names}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("wb") as output_file:
        plistlib.dump(resolved, output_file, sort_keys=False)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Resolve Xcode-style placeholders in an entitlements plist.",
    )
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--set",
        dest="replacements",
        action="append",
        default=[],
        metavar="KEY=VALUE",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        resolve_entitlements(
            source_path=args.source,
            output_path=args.output,
            replacements=_parse_replacements(args.replacements),
        )
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
