# Snowboard Kids 2 comparison ledger

Reference checkout: `reference/snowboardkids2-decomp`

Reference commit at bootstrap:
`b279eba02cd5d62230ba0ae69cb75be0e397fbfd`.

This ledger records evidence, not assumed equivalence. An SK2 implementation
may guide names, types, subsystem boundaries, and candidate source, but an SK1
entry is accepted only when SK1's own focused comparison and canonical ROM gate
pass.

| SK1 symbol or subsystem | SK1 location | SK2 reference | Relationship | SK1 proof | Notes |
| --- | --- | --- | --- | --- | --- |
| Build/compiler | `Makefile`, `snowboardkids.yaml` | SK2 `Makefile`, `snowboardkids2.yaml` | Divergent | Exact SK1 SHA-1 gate | SK1 uses IDO 5.3, F3DEX, and libultra 2.0I; SK2 uses KMC GCC 2.7.2, F3DEX2, and a different link layout. |
| ROM layout | `snowboardkids.yaml` | `snowboardkids2.yaml` | Divergent | Splat extraction plus exact SK1 SHA-1 | Never transfer SK2 addresses, segment sizes, or library ordering without SK1 evidence. |
| Matching workflow | `tools/`, `decomp.yaml` | SK2 `tools/`, `decomp.yaml` | Structural correspondence | Canonical gate and focused asm/data diff | Both use Splat, asm-differ, mapfile-parser, data differ, and tiny function packets. |
| Race, menu, audio, graphics subsystems | `src/` | SK2 `src/` | Candidate family correspondence | Pending symbol-by-symbol mapping | Use normalized assembly and call-graph evidence before claiming a function correspondence. |

Add one row for every accepted SK2-assisted packet, including negative or
divergent findings when they are reusable.
