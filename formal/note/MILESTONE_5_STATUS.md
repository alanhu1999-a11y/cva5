# Milestone 5 Status: Combined AXI Master Unit Harness

Milestone 5 starts a combined unit-level `axi_master` proof. The goal is to
allow legal LSU read and legal LSU write requests in one harness, then prove
cross-mode safety before any full-core proof is attempted.

## Scope

In scope:

- Unit-level `axi_master` only.
- Legal non-AMO LSU read and write requests.
- Cross-mode safety between AR/R and AW/W/B flows.
- Combined read and write lifecycle covers.
- Shared `axi4_basic_props` checker under the combined harness.

Out of scope:

- Full-core proof.
- Wishbone proof.
- AMO proof.
- Default strict full-field write checks for `AWSIZE`, `AWCACHE`, and `WLAST`.

The existing read-only and write-only closure targets remain unchanged and
should continue to be used as focused debug targets.

## New Files

| File | Purpose |
|---|---|
| `formal/models/axi_master_combined_formal_wrapper.sv` | Combined read/write unit harness and cover wrapper. |
| `formal/scripts/tcl/_axi_master_combined_common.tcl` | Shared Jasper setup for combined targets. |
| `formal/scripts/tcl/axi_master_combined_smoke.tcl` | Combined read/write reachability covers. |
| `formal/scripts/tcl/axi_master_combined_cross_safety.tcl` | Local combined cross-mode safety assertions. |
| `formal/scripts/tcl/axi_master_combined_checker.tcl` | Shared checker assertions/covers under combined harness. |
| `formal/scripts/tcl/axi_master_combined_property.tcl` | Single-property debug target. |

## Proof Structure

```text
combined axi_master unit harness
├── smoke covers
│   ├── cover_combined_read_request
│   ├── cover_combined_write_request
│   ├── cover_combined_read_lifecycle
│   ├── cover_combined_write_lifecycle
│   ├── cover_read_then_write
│   └── cover_write_then_read
├── local DUT lemmas
│   ├── legal read/write request enters the expected FSM path
│   ├── accepted request starts only from READY
│   ├── read/write pending trackers do not overlap
│   └── busy states keep ls_if.ready low until the legal response
├── local protocol properties
│   ├── no simultaneous read/write AXI valid or handshake
│   ├── read completion follows R response, not B response
│   ├── write completion follows B response, not R response
│   └── R/B responses clear only their matching pending state
└── checker-level properties
    ├── read AR hold/stability and outstanding counter properties
    └── write AW/W hold/stability and outstanding counter properties
```

## Assumption Classes

| Class | Combined Harness Assumption |
|---|---|
| Reset/warmup | `formal_active` gates post-reset checks; no LSU request or AXI response during warmup. |
| LSU protocol | `ls_new_request` is a one-cycle pulse, issued only when `ls_if.ready` is high. |
| LSU command legality | A legal request is either read or write: `ls_if.re ^ ls_if.we`. Simultaneous read/write command is unsupported environment behavior. |
| AXI slave environment | No early `RVALID` before a pending read; no early `BVALID` before both AW and W are pending. |
| AXI response shape | Read responses are single-beat (`RLAST=1`) in this unit harness. |
| Cover-only progress | The cover wrapper bounds AR/AW/W backpressure so smoke traces are reachable. Safety targets do not assume eventual ready/response. |
| Review/proof control | `INCLUDE_UNDRIVEN_FIELDS=1` remains opt-in for strict write fields pending Lesley/design-owner approval. |

## Replay Commands

Run from `formal/` after sourcing the Jasper environment:

```sh
make formal-axi-master-combined-smoke GUI=0 ENGINE_MODE=auto
make formal-axi-master-combined-cross-safety GUI=0 ENGINE_MODE=auto
make formal-axi-master-combined-checker GUI=0 ENGINE_MODE=auto
```

Aggregate closure:

```sh
make formal-axi-master-combined-closure GUI=0 ENGINE_MODE=auto
```

Single GUI/session view for local cross-safety plus checker properties:

```sh
make formal-axi-master-combined-all-safety GUI=1 ENGINE_MODE=auto
```

Single-property debug:

```sh
make formal-axi-master-combined-property \
  PROPERTY=dut_no_simultaneous_read_write_handshake \
  GUI=0 ENGINE_MODE=auto
```

## Run Metadata

Clean closure was rerun from commit `50ce3a8`; each `command.txt` records
`git_dirty=0`. See `formal/note/MILESTONE_5_CLOSURE.md` for the short review
summary.

| Target | Expected Property Set | Result | Engine Mode / Engines Seen | Run Directory | Peak Memory | Git Commit |
|---|---|---|---|---|---:|---|
| `formal-axi-master-combined-smoke` | 6 covers | 6 covered | `auto` / `Hp` | `formal/runs/axi_master_combined_smoke/20260704_182511` | 0.546 GB | `50ce3a8`, clean |
| `formal-axi-master-combined-cross-safety` | 27 assertions | 27 proven | `auto` / `N`, `Mpcustom2`, `Hp` | `formal/runs/axi_master_combined_cross_safety/20260704_182528` | 0.547 GB | `50ce3a8`, clean |
| `formal-axi-master-combined-checker` | 21 assertions, 7 covers | 21 proven, 7 covered | `auto` / `Mpcustom2`, `Hp`, `AM` | `formal/runs/axi_master_combined_checker/20260704_182627` | 0.549 GB | `50ce3a8`, clean |

Covered combined harness properties:

| Property | Result |
|---|---|
| `cover_combined_read_request` | covered in 2 cycles |
| `cover_combined_write_request` | covered in 2 cycles |
| `cover_combined_read_lifecycle` | covered in 5 cycles |
| `cover_combined_write_lifecycle` | covered in 6 cycles |
| `cover_read_then_write` | covered in 9 cycles |
| `cover_write_then_read` | covered in 9 cycles |

## Strict AXI Field Status

Default combined checker closure keeps the same strict-field policy as the
write-only proof. `AWSIZE`, `AWCACHE`, and `WLAST` remain excluded from default
closure because the current RTL does not drive them.

Opt-in review mode is still available:

```sh
make formal-axi-master-combined-checker \
  GUI=0 ENGINE_MODE=auto INCLUDE_UNDRIVEN_FIELDS=1
```

Do not report this opt-in mode as final closure until the RTL owner approves
and implements the missing field assignments.

## Current Status

Implementation status: complete for the combined unit-level harness.

Proof status: combined smoke, cross-safety, and checker targets are clean under
the default strict-field policy. Do not move to full-core proof until Lesley or
the RTL owner reviews the combined unit-level closure and the remaining
`AWSIZE`/`AWCACHE`/`WLAST` strict-field question.
