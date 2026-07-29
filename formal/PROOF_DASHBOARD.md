# CVA5 Formal Proof Dashboard

Date: 2026-07-20

## Scope

This dashboard summarizes the current JasperGold proof package in `formal/`.
The default evidence is unit-level AXI master proof work plus staged full-core
reachability. No core RTL patches are required for this milestone package.

Before expanding full-core decode, LSU, or data-side AXI proof, review
`formal/note/TRUSTED_ASSUMPTIONS_LIMITATIONS.md`. That note is the current
trusted-assumptions and known-limitations audit for this proof package.

## Jasper-Native Review Framework

Launch the canonical unit-level review project with:

```sh
make formal-axi-master-proof-framework GUI=1 ENGINE_MODE=auto
```

The project is the primary interactive proof-status view. It elaborates three
independent read-only, write-only, and combined harness instances, then copies
only the matching assumptions and obligations into named Jasper tasks. The
Task Tree is organized by context and role:

- `*__00_ASSUMPTIONS`: active environment contract for that context.
- `*__10_REACHABILITY`: covers only; no cover is a proof dependency.
- `*__20_*_SAFETY`: channel or cross-mode safety.
- `*__30_*_LIFECYCLE`: response and completion lifecycle.
- `*__40_CHECKER`: reusable checker obligations.
- `*__80_DEBUG_ONLY`: historical/debug properties excluded from closure.
- `REVIEW__9*`: disabled manifest markers for unimplemented, unrun,
  inconclusive, disabled, and proof-boundary-inapplicable work.

The Proof Structure pane has independent roots for each context. Its
assume-guarantee nodes prove white-box helper lemmas under the original
environment before using them to discharge local and checker-level
guarantees. Combined lifecycle branches use structural partitioning only.
Annotations identify final assertions, helper lemmas, covers, assumptions,
and review-only markers. Strict external AXI control fields remain visible as
pending post-`axi_adapter` work, not as direct `axi_master` proofs.

After the Proof Structure roots complete, the framework runs Jasper Coverage
App measurement for branch and statement cover items in the three direct
`axi_master` DUT instances. The displayed Checker Coverage metric is **COI
coverage**: a structural union of logic that can influence the proven
assertions. It is not Proof Core or mutation coverage and must not be reported
as either. The GUI merges the proven implementation tasks selected by the
framework, while preserving separate hierarchy rows for `u_read`, `u_write`,
and `u_combined`. Use **Add New App -> Coverage App** for detailed cover-item
analysis; the FPV Design Hierarchy columns use the same collected database.

FPV proof results do not populate Checker Coverage by themselves. The
framework initializes Coverage before elaboration, measures each proven
implementation task after proof completion, and then configures the Coverage
GUI to merge those tasks. The merge is optimistic at the cover-item level: an
item is checked when it is in the COI of at least one selected proven
assertion. Measurements are issued one task at a time because the Jasper
`2026.03p001` multi-task command returned before all selected task metrics had
been finalized during validation. Assertions may reside in a wrapper or
checker; only branch/statement items in `u_read.u_dut`, `u_write.u_dut`, and
`u_combined.u_dut` are scored.

Use `FRAMEWORK_RUN_PROOFS=0` for a setup-only GUI. Focused targets below remain
the regression and single-property debug interface.

Framework validation on Jasper `2026.03p001`:

| Mode | Result | Run directory |
| --- | --- | --- |
| Setup only | Elaborated; named tasks and Proof Structure populated; read/write/combined roots contain 7/6/11 assumptions | `formal/runs/axi_master_proof_framework/20260719_200521` |
| Full proof + COI | 125/125 selected assertions proven; 50/50 explicit covers covered; 21 checker task measurements completed; no CEX, undetermined property, or unreachable cover; `auto`, 0.569 GB peak | `formal/runs/axi_master_proof_framework/20260719_202904` |

Latest branch/statement COI Checker Coverage:

| DUT instance | Checked items | Coverage | COI-undetectable items | Current-scope interpretation |
| --- | ---: | ---: | ---: | --- |
| `u_read.u_dut` | 53/63 | 84.13% | 10 | Write-path and AMO/RMW assignments are outside the read-only assertion cones. |
| `u_write.u_dut` | 51/63 | 80.95% | 12 | Read-path, invalid-SC/AMO, and detailed B-response data assignments are outside the write-only assertion cones. |
| `u_combined.u_dut` | 58/63 | 92.06% | 5 | Remaining items are AMO/RMW assignments; AMO semantics are not part of current combined closure. |

The undetectable assignments are listed by the run at `axi_master.sv` lines
77-78, 85-90, 103-105, 110, 113-114, 125-126, and 128 as applicable to each
instance. They are coverage gaps, not failed properties. COI is a structural,
optimistic metric; it does not show which statements were necessary to an
individual proof. Proof Core or mutation coverage would require separate,
higher-effort measurement and is not claimed here.

In Jasper `2026.03p001`, selecting a checker mode in the GUI does not generate
its data. COI uses `check_cov -init/-measure -type coi`; normal Proof Core uses
`-type proof`; high-precision Proof Core uses
`-type proof_core_high_precision`; and mutation uses `-type mutation`. The
active display mode is selected with `check_cov -configure -checker_mode ...`.
The framework intentionally initializes and measures only COI.

## Jasper-Native Full-Core Load-to-AXI Framework

Launch the canonical full-core review project with:

```sh
make formal-cva5-axi-proof-framework GUI=1 TIME_LIMIT=5m ENGINE_MODE=auto
```

This project contains one `cva5_formal_wrapper`, one CVA5 core, and that
core's embedded peripheral `axi_master`. It does not instantiate separate
cores for proof cases. Named tasks expose the following areas in Jasper:

- `CORE__00_ENV_*`: reset/startup and AXI-secondary assumptions.
- `CORE__00_DESIGN_INTENT_DISABLED_UNIT`: generated-off custom-unit tieoff.
- `RESET_AND_STARTUP_*` and `INSTRUCTION_FETCH_*`: covers and fetch helpers.
- `DECODE_REACHABILITY` and `ISSUE_REACHABILITY`: anchored LW covers.
- `LSU_TO_AXI_MASTER_*`: normal-load request, acceptance, and address mapping.
- `AXI_READ_REQUEST_*`: embedded AR reachability, local helpers, and final AR safety.
- `AXI_READ_RESPONSE_*`: pending-state helpers, environment legality, quick guarantees, and deep LSU/data guarantees.
- `END_TO_END_LOAD_REACHABILITY`: anchored LW-to-AR/R/completion covers.
- `CORE__85_*` and `CORE__9*`: historical, unimplemented, unrun,
  inconclusive, review-only, and boundary-inapplicable obligations.

The Proof Structure root is `CVA5_CORE_AXI_FRAMEWORK`. Covers are partitioned
into reachability branches and are never proof dependencies. LSU bridge, AXI
request, and AXI response safety branches use helper/guarantee nodes. The
response branch deliberately separates `AXI_READ_RESPONSE_QUICK_GUARANTEES`
from `AXI_READ_RESPONSE_DEEP_GUARANTEES`. Assumptions and disabled review
markers remain named Task Tree tasks because they are context/manifest data,
not proof dependencies to be fabricated as guarantees.

Default execution proves the independently selected safety tasks and collects
branch/statement COI coverage. Broad full-core covers are left visible but
unrun; use focused `formal-cva5-reachability-stage` targets for normal cover
regression. Deep LSU completion ordering and returned-data properties are also
visible but opt-in because a diagnostic run reached the host low-memory limit.

Latest framework results on Jasper `2026.03p001`:

| Mode | Result | Peak memory | Run directory |
| --- | --- | ---: | --- |
| Setup only | Elaborated one core; named tasks, focused LW and safety stage tasks, and Proof Structure populated | 1.138 GB | `formal/runs/cva5_axi_proof_framework/20260720_173905` |
| Default safety + COI baseline | Historical 26/26 selected assertions proven; no CEX or undetermined assertion; predates the generated-off custom-unit tieoff, so current focused reruns below are authoritative for the requested embedded obligations | 5.923 GB | `formal/runs/cva5_axi_proof_framework/20260719_212302` |
| Anchored LW lifecycle | Covered through LSU-side completion at depth 84; witness VCD exported | 2.268 GB | `formal/runs/cva5_axi_proof_framework/20260720_164725` |

The 26 proven assertions comprise 4 fetch wiring helpers, 3 LSU-to-master
address/FSM properties, 7 embedded/checker AR request properties, 7 response
tracking helpers, 1 AXI-secondary model legality check, and 4 quick
pending/outstanding response guarantees. The checker properties in this run
observe the embedded full-core instance. Separate unit-level results are only
reference evidence and are not imported into this proof.

Latest full-core branch/statement COI Checker Coverage:

| Scoped hierarchy | Checked items | Coverage | Interpretation |
| --- | ---: | ---: | --- |
| `u_fullcore.u_cva5_core.load_store_unit_block` | 119/153 | 77.78% | Load-store-block logic in the selected safety assertion cones. |
| `...load_store_unit_block.gen_ls_pbus.gen_axi.axi_bus` | 55/63 | 87.30% | Embedded direct `axi_master` logic in those cones. |

These are structural COI metrics, not Proof Core or mutation coverage. Their
denominators differ from whole-core coverage, and neither percentage is a
substitute for assertion proof or reachability closure.

Current proof boundary is intentionally limited. Full-core fetch/decode/LSU
progress is cover evidence; the anchored LW end-to-end cover is now hit.
Architectural register writeback, detailed load width/sign semantics,
misalignment/exceptions, AXI error responses, stores, and AMOs remain open.
Strict `ARSIZE/ARCACHE/AWSIZE/AWCACHE/WLAST` closure remains assigned to the
post-`axi_adapter` external boundary, not the direct embedded-master boundary.

### Anchored LW reachability ladder

The focused ladder reuses this same wrapper, named tasks, assumptions, and
Proof Structure:

```sh
make formal-cva5-axi-load-list-stages
make formal-cva5-axi-load-stage STAGE=<stage> GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto
make formal-cva5-axi-load-reachability GUI=1 TIME_LIMIT=5m ENGINE_MODE=auto
make formal-cva5-axi-safety-list-stages
make formal-cva5-axi-safety-stage STAGE=<stage> GUI=0 TIME_LIMIT=2m ENGINE_MODE=auto
```

The FBM program anchor is `LW x2, 0(x1)` (`32'h0000a103`) at PC
`0x80000004`. The preceding `LUI x1, 0x60000` is `32'h600000b7` at
`0x80000000`; the expected load address is `0x60000000`. Formal-only helper
trackers capture the CVA5 instruction ID at LW-PC fetch allocation, then
observe exact return, valid fetch completion, decode, issue, legal non-AMO LSU
command, embedded-master acceptance, AR/R lifecycle, and LSU completion. The
trackers only observe DUT state and add no assumptions.
The depth-69 LW-PC allocation precedes the FBM's 80-cycle response warmup;
the tracker captures that real request ID early, while all downstream stages
still require the exact post-startup LW response.

Latest focused results:

| Stage/property | Status | Bound | Engine/time | Peak memory | Run directory |
| --- | --- | ---: | --- | ---: | --- |
| `cover_core_reset_release` | Covered | 1 | `auto`, 1.11 s | 1.148 GB | `formal/runs/cva5_axi_proof_framework/20260720_001925` |
| `cover_core_startup_complete` | Covered | 81 | `auto`, 110.78 s | unavailable; process interrupted after result | `formal/runs/cva5_axi_proof_framework/20260720_002644` |
| `cover_lw_instruction_request` | Covered | 82 | `auto`, 53.63 s | 10.343 GB | `formal/runs/cva5_axi_proof_framework/20260720_003513` |
| `cover_lw_instruction_returned` | Covered | 71 | `Ht`, 14.65 s | 2.268 GB | `formal/runs/cva5_axi_proof_framework/20260720_164725` |
| `cover_debug_lw_fetch_request_allocated` | Covered | 69 | `Ht`, 23.15 s | 2.552 GB | `formal/runs/cva5_axi_proof_framework/20260720_010241` |
| `cover_lw_fetch_complete` | Covered | 76 | `Ht`, 3.85 s | 2.268 GB | full-lifecycle run |
| `cover_lw_decode_valid` | Covered | 77 | `Ht`, 3.97 s | not retained | `formal/runs/cva5_axi_proof_framework/20260720_132013` |
| `cover_lw_issue_accept` | Covered | 78 | `Ht`, preprocessing | 2.206 GB | `formal/runs/cva5_axi_proof_framework/20260720_151723` |
| `cover_lsu_load_request_accepted` | Covered | 79 | `Ht`, 4.03 s | 2.268 GB | full-lifecycle run |
| `cover_axi_master_enters_requesting_read` | Covered | 80 | `Ht`, 3.98 s | 2.268 GB | full-lifecycle run |
| `cover_axi_arvalid_from_lw` / `cover_axi_ar_handshake_from_lw` | Covered | 80 | `Ht`, preprocessing | 2.268 GB | full-lifecycle run |
| `cover_axi_r_response_for_lw` | Covered | 83 | `Ht`, 4.16 s | 2.268 GB | full-lifecycle run |
| `cover_lsu_load_completion_from_lw` / full lifecycle | Covered | 84 | `Ht`, 4.17 s / preprocessing | 2.268 GB | full-lifecycle run |

`auto` remains the public default. Its broad full-core portfolio exceeded
practical host memory, so the closed lifecycle witness used `Ht`, the useful
engine identified during earlier auto runs. No proof assumption or SVA
semantics changed. The earlier fetch attr/data timeout remains historical
debug evidence; the corrected anchored trace now closes that boundary.

The full-lifecycle VCD is
`formal/runs/cva5_axi_proof_framework/20260720_164725/full_lifecycle.vcd`.
The generated-off CUSTOM-unit signals require a documented design-intent
quiescence assumption at this configuration boundary; no assumption forces
decode, issue, LSU request, ARVALID, READY, R response timing, or completion.

Focused embedded safety reruns are independently proven at infinite bound:

| Property | Engine / time | Peak memory | Run directory |
| --- | --- | ---: | --- |
| Load accept enters REQUESTING_READ | `auto`/AM, 0.93 s | 1.591 GB | `formal/runs/cva5_axi_proof_framework/20260720_172517` |
| REQUESTING_READ drives ARVALID | `auto`/AM, 0.91 s | 1.585 GB | `formal/runs/cva5_axi_proof_framework/20260720_172703` |
| ARVALID held under backpressure | `auto`/AM, 0.78 s | 1.596 GB | `formal/runs/cva5_axi_proof_framework/20260720_172838` |
| AR address/control stable under backpressure | `auto`/Hp, 17.05 s | 6.384 GB | `formal/runs/cva5_axi_proof_framework/20260720_173013` |

## Target Summary

| Area | Primary target | Scope | Current status |
| --- | --- | --- | --- |
| Read-only AXI master | `formal-axi-master-read-closure` | Unit `axi_master`, read path only | Closed for AR, R lifecycle, and checker properties |
| Write-only AXI master | `formal-axi-master-write-closure` | Unit `axi_master`, write path only | Closed for AW/W/B lifecycle and checker properties |
| Combined AXI master | `formal-axi-master-combined-closure` | Unit `axi_master`, read/write interaction | Closed for smoke, cross-safety, and checker properties |
| Full-core load | `formal-cva5-axi-load-stage` | One core, anchored LW staged reachability | Covered through embedded AR/R and LSU-side completion; architectural writeback remains pending |

## Common Commands

```sh
make formal-filelist
make formal-elab GUI=0 ENGINE_MODE=auto

make formal-axi-master-read-closure GUI=0 ENGINE_MODE=auto
make formal-axi-master-write-closure GUI=0 ENGINE_MODE=auto
make formal-axi-master-combined-closure GUI=0 ENGINE_MODE=auto

make formal-cva5-reachability-stage STAGE=<stage> GUI=0 TIME_LIMIT=2m ENGINE_MODE=auto
make formal-cva5-axi-load-list-stages
make formal-cva5-axi-load-stage STAGE=<stage> GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto
make formal-cva5-axi-safety-list-stages
make formal-cva5-axi-safety-stage STAGE=<stage> GUI=0 TIME_LIMIT=2m ENGINE_MODE=auto
make formal-cva5-reachability GUI=0 TIME_LIMIT=2m ENGINE_MODE=auto
make formal-cva5-reachability-write GUI=0 TIME_LIMIT=2m ENGINE_MODE=auto
make formal-cva5-reachability-read-backpressure GUI=0 TIME_LIMIT=2m ENGINE_MODE=auto
make formal-cva5-reachability-write-backpressure GUI=0 TIME_LIMIT=2m ENGINE_MODE=auto
```

Single-property examples:

```sh
make formal-axi-master-read-property PROPERTY=master_arvalid_held_until_ready GUI=0 ENGINE_MODE=auto
make formal-axi-master-write-property PROPERTY=master_awvalid_held_until_ready GUI=0 ENGINE_MODE=auto
make formal-axi-master-combined-property PROPERTY=dut_no_simultaneous_read_write_valid GUI=0 ENGINE_MODE=auto
```

## Assumption Classes

| Class | Meaning | Examples |
| --- | --- | --- |
| Reset and warmup | Keeps proof checking inactive until reset/startup is meaningful | `formal_active`, quiet startup sequencing |
| LSU request protocol | Models legal local load/store-side behavior | Request when `ls_if.ready`; read-only or write-only mode in focused harnesses |
| AXI slave environment | Models legal responses from the abstract slave | No early `RVALID` before accepted AR; no early `BVALID` before accepted AW/W |
| Cover timing control | Reachability-only READY timing scenarios | READY already high, same-cycle READY/VALID, waits of 1/2/3/16/19 cycles |
| Proof-control/debug | Optional convergence aids or debug modes | Independently proven cut lemmas; review-only undriven-field checks |

The explicit backpressure timing scenarios are covers only. They are not safety
assumptions and do not constrain the default safety proofs. They sample the
requested READY/VALID timing points and do not prove all possible wait lengths.

Important caveat: the unit-level proofs are the current AXI correctness
evidence. Full-core results below are reachability evidence only until decode,
LSU request, and data-side AXI handshakes are reached in staged order.

## Latest Unit Runs

| Target | Result | Engine | Time limit | Peak memory | Run directory |
| --- | --- | --- | --- | --- | --- |
| `formal-axi-master-read-smoke` | 11/11 covers covered, including AR wait 1/2/3/16/19 | `auto` | 5 min | 0.545 GB | `formal/runs/axi_master_read_smoke/20260705_182135` |
| `formal-axi-master-read-lifecycle-safety` | 11/11 assertions proven | `auto` | 5 min | 0.544 GB | `formal/runs/axi_master_read_lifecycle_safety/20260703_162606` |
| `formal-axi-master-read-checker` | 5/5 assertions proven, 3/3 covers covered | `auto` | 5 min | 0.543 GB | `formal/runs/axi_master_read_checker/20260703_163029` |
| `formal-axi-master-write-smoke` | 19/19 covers covered, including AW/W waits 1/2/3/16/19 | `auto` | 5 min | 0.548 GB | `formal/runs/axi_master_write_smoke/20260705_182209` |
| `formal-axi-master-write-lifecycle-safety` | 24/24 assertions proven | `auto` | 5 min | 0.542 GB | `formal/runs/axi_master_write_lifecycle_safety/20260703_184653` |
| `formal-axi-master-write-checker` | 14/14 assertions proven, 4/4 covers covered | `auto` | 5 min | 0.547 GB | `formal/runs/axi_master_write_checker/20260703_184752` |
| `formal-axi-master-combined-smoke` | 6/6 covers covered | `auto` | 5 min | 0.544 GB | `formal/runs/axi_master_combined_smoke/20260705_182029` |
| `formal-axi-master-combined-cross-safety` | 27/27 assertions proven | `auto` | 5 min | 0.547 GB | `formal/runs/axi_master_combined_cross_safety/20260704_182528` |
| `formal-axi-master-combined-checker` | 21/21 assertions proven, 7/7 covers covered | `auto` | 5 min | 0.549 GB | `formal/runs/axi_master_combined_checker/20260704_182627` |

## Full-Core Staged Reachability

Latest full-core elaboration:

| Target | Result | Engine | Peak memory | Run directory |
| --- | --- | --- | --- | --- |
| `formal-elab` | Passed | `auto` | 0.764 GB | `formal/runs/formal_elab/20260705_182831` |

Use one focused cover per run:

```sh
make formal-cva5-reachability-stage STAGE=<stage> GUI=0 TIME_LIMIT=2m ENGINE_MODE=auto
```

Available stages:

| Stage | Property |
| --- | --- |
| `reset` | `cover_reset_released` |
| `startup` | `cover_startup_complete` |
| `mem_request` | `cover_any_mem_request` |
| `instruction_mem_request` | `cover_instruction_mem_request` |
| `instruction_mem_ack` | `cover_instruction_mem_ack` |
| `instruction_mem_rvalid` | `cover_instruction_mem_rvalid` |
| `instruction_mem_read` | `cover_instruction_mem_lifecycle` |
| `instruction_fetch` | `cover_instruction_fetch` |
| `axi_arvalid` | `cover_axi_arvalid` |
| `axi_ar` | `cover_axi_ar_accepted` |
| `axi_r` | `cover_axi_r_accepted` |
| `axi_read` | `cover_axi_read_lifecycle` |
| `axi_aw` | `cover_axi_aw_accepted` |
| `axi_w` | `cover_axi_w_accepted` |
| `axi_b` | `cover_axi_b_accepted` |
| `axi_write` | `cover_axi_write_lifecycle` |

Optional full-core backpressure timing stages:

| Channel | Stages |
| --- | --- |
| AR | `axi_ar_ready_high`, `axi_ar_ready_same`, `axi_ar_wait_1`, `axi_ar_wait_2`, `axi_ar_wait_3`, `axi_ar_wait_16`, `axi_ar_wait_19` |
| AW | `axi_aw_ready_high`, `axi_aw_ready_same`, `axi_aw_wait_1`, `axi_aw_wait_2`, `axi_aw_wait_3`, `axi_aw_wait_16`, `axi_aw_wait_19` |
| W | `axi_w_ready_high`, `axi_w_ready_same`, `axi_w_wait_1`, `axi_w_wait_2`, `axi_w_wait_3`, `axi_w_wait_16`, `axi_w_wait_19` |

Latest full-core smoke results:

| Stage | Result | Bound / note | Engine | Time limit | Peak memory | Run directory |
| --- | --- | --- | --- | --- | --- | --- |
| `reset` | Covered | 1 cycle | `auto` | 2 min | 1.068 GB | `formal/runs/cva5_reachability_stage/20260705_182921` |
| `startup` | Covered | 81 cycles | `auto` | 2 min | 3.366 GB | `formal/runs/cva5_reachability_stage/20260704_203552` |
| `instruction_mem_ack` | Covered | 81 cycles | `auto` | 2 min | 10.173 GB | `formal/runs/cva5_reachability_stage/20260704_204248` |
| `instruction_fetch` | Covered | 81 cycles | `auto` | 2 min | 11.128 GB | `formal/runs/cva5_reachability_stage/20260704_204445` |
| `instruction_mem_read` | Covered | 82 cycles | `auto` | 2 min | 11.272 GB | `formal/runs/cva5_reachability_stage/20260704_205051` |
| `fbm_response_lui_reset_vec` | Covered | 82 cycles, expected FBM address/data response | `auto` | 2 min | 9.533 GB | `formal/runs/cva5_reachability_stage/20260706_133953` |
| `core_icache_rvalid_lui_reset_vec` | Covered | 82 cycles, response visible at core icache interface | `auto` | 2 min | 11.357 GB | `formal/runs/cva5_reachability_stage/20260706_134134` |
| `response_to_icache_port_lui` | Covered | 82 cycles, anchored FBM response reaches icache fetch port | `auto` | 2 min | 10.023 GB | `formal/runs/cva5_reachability_stage/20260706_134531` |
| `response_to_fetch_lui` | Covered | 82 cycles, anchored FBM response reaches wrapper `fetch_complete` | `auto` | 2 min | 8.095 GB | `formal/runs/cva5_reachability_stage/20260706_134714` |
| `axi_arvalid` | Time limit | No ARVALID trace found | `auto` | 2 min | 15.002 GB | `formal/runs/cva5_reachability_stage/20260704_205240` |
| `axi_ar` | Time limit | No AR handshake trace found | `auto` | 2 min | 13.894 GB | `formal/runs/cva5_reachability_stage/20260704_204654` |

Interpretation: the historical generic smoke rows above remain useful context,
but the newer anchored framework run supersedes their AR reachability limit.
The exact LW now reaches decode, issue, LSU acceptance, embedded AR/R, and
LSU-side completion. These are cover results, not architectural correctness
proofs.

## Current Design-Review Items

Do not patch or treat the following as proven unit-level `axi_master`
obligations until Mohammad/Lesley confirms the intended proof boundary:

- Read-channel control fields: `ARSIZE`, `ARCACHE`.
- Write-channel control fields: `AWSIZE`, `AWCACHE`, `WLAST`.
- Mohammad confirmed these fields are driven in `apu/busses/axi_adapter.sv`
  on the APU memory-adapter path. They are not driven by
  `core/memory_sub_units/axi_master.sv`, which is the current unit-level
  peripheral AXI proof boundary.
- Whether this configuration intentionally supports only one outstanding read
  and one outstanding write.
- Whether all AXI master outputs should be explicitly reset.

The review-only undriven-field checks remain opt-in through
`INCLUDE_UNDRIVEN_FIELDS=1`. The default unit-level closure does not rely on
these fields. A future adapter-level proof should check the final external AXI
fields driven by `axi_adapter.sv`.

## Current Next Steps

1. Review the generated-off CUSTOM-unit quiescence assumption with the design
   owner and decide whether configuration tieoffs belong in a higher wrapper.
2. Review the anchored 84-cycle witness and the four embedded safety proofs.
3. Keep architectural writeback, detailed load data semantics, exceptions,
   errors, stores, AMOs, and adapter-level fields as explicit future work.
4. Use unit-level closure and embedded-instance assertions as safety evidence;
   report the full-core LW ladder only as reachability evidence.
