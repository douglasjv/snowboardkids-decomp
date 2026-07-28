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
| `D_800E0DB8` integer format string | `src/menu/course_select/course_select_ui.c` | `gIntegerFormatString` in `src/story/shop_ui.c`; `sIntegerFormat` in `src/race/race_effects.c` | Exact literal correspondence | Full SK1 SHA-1 gate | SK2 confirms that the shared `"%d"` object is source data; SK1 retains its address-derived symbol until naming evidence is stronger. |
| `D_800D40B0` 16-entry TLUT | `src/menu/renderer/menu_render_utils.c` | No one-to-one symbol located | SK1-specific palette data | Full SK1 SHA-1 gate; 32 bytes moved from extracted assembly to C | The data is one transparent/black entry followed by fifteen identical entries and is consumed by `gDPLoadTLUT_pal16`; do not infer an SK2 address or name. |
| `__osContinitialized` | `src/ultra/io/controller.c` | SK2 ultralib/controller subsystem | Shared libultra family | Full SK1 SHA-1 gate; 16-byte aligned object source-owned | SK1's object is a zero-initialized `s32` plus section alignment. The SK2 checkout confirms the library boundary, while SK1's own ROM proves layout and value. |
| `__osMotorinitialized` | `src/ultra/io/motor.c` | Exact definition in `lib/ultralib/src/io/motor.c` | Exact libultra source correspondence | Full SK1 SHA-1 gate; 16 bytes source-owned | Both define four zero-initialized `u32` controller slots. SK2 supplies source lineage; SK1's target proves acceptance and placement. |
| `__MusIntGetNewNote` | `src/libmus/player.c` | Vendor `lib/libmus/src/player.c`; recovered `src/race/player.c` | Strong library lineage with version divergence | SK1 focused candidate at 99.962%; not accepted | The duration path differs by one temporary-register allocation. Direct drum-table indexing is supported by the vendor source, but exact SK1 proof is still required. |
| `validateControllerPakSave` | `src/menu/main_menu/controller_main_menu_flow.c` | Save validation in `src/system/controller_io.c` | Same subsystem, divergent save format | SK1 focused candidate at 99.306%; not accepted | SK1 uses 0x78F8-byte controller-pak slots and preserves two prefix pointer walks; SK2's EEPROM/controller-pak validation cannot be transferred. |
| `updateRaceCourseProgressMeter` | `src/race/ui/race_hud.c` | `updatePlayerRaceProgressIndicator` in `src/race/race_effects.c` | Same UI family, divergent algorithm | SK1 focused candidate at 99.551%; not accepted | SK1 directly scales four players' course progress. SK2 smooths rank-ordered indicator elements from remaining lap progress. |
| `getRaceCourseSurfaceHeight` | `src/race/motion/race_motion.c` | `getTrackHeightAtPosition` in `src/graphics/displaylist.c` | Strong algorithmic correspondence, divergent layouts | SK1 focused candidate at 99.821%; not accepted | Both traverse candidate faces, apply directed-edge tests, and interpolate plane height. SK1 uses different face metadata and 17-bit fixed-point coordinates. |
| `compressRaceRecordReplayData` | `src/menu/main_menu/main_menu_scene_model.c` | No corresponding source located | SK1-only finding so far | SK1 focused candidate at 99.203%; not accepted | The SK1 LZ-style replay compressor has a register-only near miss; do not conflate it with SK2 asset decompression helpers. |

Add one row for every accepted SK2-assisted packet, including negative or
divergent findings when they are reusable.
