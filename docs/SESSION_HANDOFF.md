# Session handoff

## Authoritative integration path

- Authoritative branch: `integration`, based on the protected `publish/main`.
- Upstream reference: `origin/main` from
  `https://github.com/cdlewis/snowboardkids-decomp` (read-only).
- Publication remote: `publish` at
  `https://github.com/douglasjv/snowboardkids-decomp`. Baseline PR #1 was
  squash-merged to its protected `main`.
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

Push integration packets to `publish`, open a PR against its `main`, and prefer
squash merges. The active `Protected main` ruleset requires one approval and a
code-owner review, blocks deletion and non-fast-forward pushes, and grants
`douglasjv` an owner bypass for self-authored PRs.

## Current frontier

Use the fresh canonical report and `tools/list_decomp_candidates.py`; do not
select from this prose if it is stale. Prefer a small function with a strong SK2
source correspondence or a clearly identified libultra/libmus family.

`D_800E0DB8`, the 32-byte `D_800D40B0` TLUT, and the aligned
`__osContinitialized` libultra object have been converted from extracted
assembly to exact C source. The four-entry `__osMotorinitialized` array is also
source-owned using exact SK2 ultralib lineage. Across the latest two milestones,
64 data bytes moved from extracted assembly to C; 32 bytes increased the
conservative source-backed counter because the controller and motor translation
units are wholly source-owned.

`updateRaceCourseProgressMeter` remains parked at a focused 99.551%; read its
ignored `nonmatchings/updateRaceCourseProgressMeter/NEAR_MISS.md` before
revisiting it.

Additional parked candidates:

- `initShopMenuSparkles`: 99.655%, one global-load register difference.
- `compressRaceRecordReplayData`: 99.203%, `t3`/`t5` register swap.
- `getRaceCourseSurfaceHeight`: 99.821%, stack-frame size only.
- `__MusIntGetNewNote`: 99.962%, one temporary register on the duration mask.
- `validateControllerPakSave`: 99.306%, one register across the slot-size
  multiply.

Each has an ignored `NEAR_MISS.md` in its matching workspace.
