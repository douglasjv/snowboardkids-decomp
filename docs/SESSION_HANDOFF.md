# Session handoff

## Authoritative integration path

- Branch: `local-integration`, based on `origin/main` from
  `https://github.com/cdlewis/snowboardkids-decomp`.
- Target: Snowboard Kids North America revision 0 (`NSKE`, SHA-1
  `1583bacc9046a360df8ea4d536942155247e154c`).
- SK2 comparison corpus: ignored checkout at
  `reference/snowboardkids2-decomp`, bootstrap commit
  `b279eba02cd5d62230ba0ae69cb75be0e397fbfd`.

## Start here

```sh
git status --short --branch
.venv/bin/python tools/canonical_matching_gate.py
```

Read `AGENTS.md`, `docs/PROJECT_STATUS.md`, and
`docs/SK2_COMPARISON_LEDGER.md` before selecting a packet. Keep this checkout
as the only authoritative writer and give any worker a bounded, non-overlapping
read-only or function-level assignment.

## Current frontier

Use the fresh canonical report and `tools/list_decomp_candidates.py`; do not
select from this prose if it is stale. Prefer a small function with a strong SK2
source correspondence or a clearly identified libultra/libmus family.

`D_800E0DB8` has been converted from an extracted assembly string to exact C
source. `updateRaceCourseProgressMeter` remains parked at a focused 99.551%;
read its ignored `nonmatchings/updateRaceCourseProgressMeter/NEAR_MISS.md`
before revisiting it.

Additional parked candidates:

- `initShopMenuSparkles`: 99.655%, one global-load register difference.
- `compressRaceRecordReplayData`: 99.203%, `t3`/`t5` register swap.
- `getRaceCourseSurfaceHeight`: 99.821%, stack-frame size only.

Each has an ignored `NEAR_MISS.md` in its matching workspace.
