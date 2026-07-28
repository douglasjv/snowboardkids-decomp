# Project status

## Acceptance contract

The checksum build proves that the repository can reconstruct the retail ROM,
including currently extracted assembly and assets. It does not by itself prove
that the game is fully decompiled.

`tools/canonical_matching_gate.py` is the authoritative gate. It reports:

- exact target-ROM reproduction;
- exact matched code, data, and functions from mapfile-parser;
- conservative source-backed C code and data;
- handwritten assembly, extracted assembly, `GLOBAL_ASM`, extracted assets,
  and otherwise unsourced remaining bytes.

Run:

```sh
./tools/setup_local_toolchain.sh
.venv/bin/python tools/canonical_matching_gate.py
```

At final completion, also run:

```sh
.venv/bin/python tools/canonical_matching_gate.py --require-complete
```

## Baseline

The initial local baseline reproduces the North American revision 0 target ROM
with SHA-1 `1583bacc9046a360df8ea4d536942155247e154c`.

The machine-readable live counts are written to
`build/canonical-gate/report.json`; refresh them rather than copying stale
numbers into this document.

## Packet rules

Work on one function or one small natural family at a time. Record an SK2
comparison when useful, prove the SK1 object locally, run the full canonical
gate, update durable notes in the same change, then commit. A close focused
score, `NON_MATCHING` C body, extracted assembly, or ROM-equivalent blob is
diagnostic progress and is not source-backed completion.
