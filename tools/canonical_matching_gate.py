#!/usr/bin/env python3
"""Canonical Snowboard Kids matching and source-coverage gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
TARGET_ROM = ROOT / "snowboardkids.z64"
EXPECTED_SHA1 = "1583bacc9046a360df8ea4d536942155247e154c"
PROGRESS_REPORT = ROOT / "report.json"
GATE_REPORT = ROOT / "build" / "canonical-gate" / "report.json"
ROM_SUFFIXES = {".z64", ".n64", ".v64"}


def run(command: list[str], *, env: dict[str, str] | None = None) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, cwd=ROOT, env=env, check=True)


def sha1(path: Path) -> str:
    digest = hashlib.sha1()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tracked_roms() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
    )
    return sorted(
        path.decode().strip()
        for path in result.stdout.split(b"\0")
        if path and Path(path.decode()).suffix.lower() in ROM_SUFFIXES
    )


def global_asm_count() -> int:
    pattern = re.compile(r"^\s*#pragma\s+(?:GLOBAL_ASM|INCLUDE_ASM)\b", re.MULTILINE)
    return sum(
        len(pattern.findall(path.read_text(errors="replace")))
        for path in (ROOT / "src").rglob("*.c")
    )


def unit_source(unit_name: str) -> str:
    if not unit_name.startswith("build/"):
        return "other"
    stem = ROOT / unit_name.removeprefix("build/")
    if stem.with_suffix(".c").is_file():
        return "c"
    if stem.with_suffix(".s").is_file():
        return "assembly"
    if unit_name.startswith("build/asm/"):
        return "extracted_assembly"
    if unit_name.startswith("build/assets/"):
        return "extracted_asset"
    return "generated_or_binary"


def progress_summary(report: dict[str, Any]) -> dict[str, Any]:
    measures = report["measures"]
    source_backed_functions = 0
    source_backed_code = 0
    assembly_functions = 0
    assembly_code = 0
    extracted_assembly_functions = 0
    extracted_assembly_code = 0
    source_backed_data = 0
    data_by_source: dict[str, int] = {}

    for unit in report.get("units", []):
        source = unit_source(unit.get("name", ""))
        for function in unit.get("functions", []):
            size = int(function.get("size", 0))
            exact = function.get("fuzzy_match_percent") == 100.0
            if source == "c" and exact:
                source_backed_functions += 1
                source_backed_code += size
            elif source == "assembly":
                assembly_functions += 1
                assembly_code += size
            elif source == "extracted_assembly":
                extracted_assembly_functions += 1
                extracted_assembly_code += size

        for section in unit.get("sections", []):
            if section.get("name") not in {".data", ".rodata", ".bss", ".sdata", ".sbss"}:
                continue
            size = int(section.get("size", 0))
            data_by_source[source] = data_by_source.get(source, 0) + size
            if source == "c" and section.get("fuzzy_match_percent") == 100.0:
                source_backed_data += size

    total_code = int(measures["total_code"])
    total_data = int(measures["total_data"])
    return {
        "exact_matched_functions": int(measures["matched_functions"]),
        "total_functions": int(measures["total_functions"]),
        "exact_matched_function_percent": measures["matched_functions_percent"],
        "exact_matched_code_bytes": int(measures["matched_code"]),
        "total_code_bytes": total_code,
        "exact_matched_code_percent": measures["matched_code_percent"],
        "source_backed_functions": source_backed_functions,
        "source_backed_code_bytes": source_backed_code,
        "unsourced_code_bytes": total_code - source_backed_code,
        "handwritten_assembly_functions": assembly_functions,
        "handwritten_assembly_code_bytes": assembly_code,
        "extracted_assembly_functions": extracted_assembly_functions,
        "extracted_assembly_code_bytes": extracted_assembly_code,
        "exact_matched_data_bytes": int(measures["matched_data"]),
        "total_data_bytes": total_data,
        "exact_matched_data_percent": measures["matched_data_percent"],
        "source_backed_data_bytes": source_backed_data,
        "unsourced_data_bytes": total_data - source_backed_data,
        "data_bytes_by_source_kind": dict(sorted(data_by_source.items())),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-complete",
        action="store_true",
        help="fail unless all code and data are reconstructed from source",
    )
    parser.add_argument(
        "--skip-build",
        action="store_true",
        help="reuse the current build and report (diagnostic only)",
    )
    args = parser.parse_args()

    if not TARGET_ROM.is_file():
        print(f"missing target ROM: {TARGET_ROM}", file=sys.stderr)
        return 2
    actual_sha1 = sha1(TARGET_ROM)
    if actual_sha1 != EXPECTED_SHA1:
        print(
            f"target ROM SHA-1 mismatch: expected {EXPECTED_SHA1}, got {actual_sha1}",
            file=sys.stderr,
        )
        return 2
    committed_roms = tracked_roms()
    if committed_roms:
        print(f"copyrighted ROM files are tracked: {committed_roms}", file=sys.stderr)
        return 2

    env = os.environ.copy()
    venv_bin = ROOT / ".venv" / "bin"
    report_python = Path(sys.executable)
    if venv_bin.is_dir():
        env["PATH"] = f"{venv_bin}:{env['PATH']}"
        report_python = venv_bin / "python"

    if not args.skip_build:
        run(["./tools/build-and-verify.sh"], env=env)
        run([str(report_python), "-m", "mapfile_parser", "objdiff_report"], env=env)
    elif not PROGRESS_REPORT.is_file():
        print("report.json is missing; run without --skip-build", file=sys.stderr)
        return 2

    built_rom = ROOT / "build" / "snowboardkids.z64"
    exact_rom = built_rom.is_file() and sha1(built_rom) == EXPECTED_SHA1
    progress = progress_summary(json.loads(PROGRESS_REPORT.read_text()))
    nonmatching_asm_files = len(list((ROOT / "asm" / "nonmatchings").rglob("*.s")))
    directives = global_asm_count()
    complete = (
        exact_rom
        and progress["unsourced_code_bytes"] == 0
        and progress["unsourced_data_bytes"] == 0
        and progress["handwritten_assembly_functions"] == 0
        and progress["extracted_assembly_functions"] == 0
        and directives == 0
        and nonmatching_asm_files == 0
    )
    result = {
        "schema_version": 1,
        "target": {
            "name": "Snowboard Kids (North America)",
            "game_code": "NSKE",
            "revision": 0,
            "sha1": EXPECTED_SHA1,
        },
        "exact_rom_match": exact_rom,
        "source_only_git": not committed_roms,
        "global_asm_directives": directives,
        "nonmatching_asm_files": nonmatching_asm_files,
        "progress": progress,
        "source_complete": complete,
    }
    GATE_REPORT.parent.mkdir(parents=True, exist_ok=True)
    GATE_REPORT.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

    print(json.dumps(result, indent=2, sort_keys=True))
    print(f"canonical report: {GATE_REPORT}")
    if not exact_rom:
        return 2
    if args.require_complete and not complete:
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
